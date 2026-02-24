// lib/providers/recording_provider.dart
//
// Full recording pipeline:
//   1. record package captures .m4a
//   2. Timer ticks every second
//   3. On stop → upload audio → transcribe → summarize → keywords → title
//   4. Create NoteModel → hand off to NotesProvider

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

enum PipelineStep {
  idle,
  uploading,
  transcribing,
  summarizing,
  keywords,
  title,
  done,
}

class RecordingProvider extends ChangeNotifier {
  // ── Internal ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AiService _ai = AiService();
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();

  Timer? _timer;
  String? _audioPath;
  String? _pendingNoteId;

  // ── State ────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  int _seconds = 0;
  String _liveTranscript = '';
  String _processingStatus = '';
  String? _error;
  NoteModel? _processedNote;
  double _uploadProgress = 0.0;

  // ── Getters ──────────────────────────────────────────────────
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isProcessing => _isProcessing;
  int get seconds => _seconds;
  String get liveTranscript => _liveTranscript;
  String get processingStatus => _processingStatus;
  String? get error => _error;
  NoteModel? get processedNote => _processedNote;
  double get uploadProgress => _uploadProgress;

  String get formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════════
  //  RECORDING CONTROLS
  // ════════════════════════════════════════════════════════════

  Future<void> startRecording() async {
    _error = null;
    _processedNote = null;
    _liveTranscript = '';
    _seconds = 0;
    _uploadProgress = 0.0;

    // Check microphone permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _error = 'Microphone permission denied. Please allow in Settings.';
      notifyListeners();
      return;
    }

    // Create temp file path
    final dir = await getTemporaryDirectory();
    _pendingNoteId = _uuid.v4();
    _audioPath = '${dir.path}/$_pendingNoteId.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _audioPath!,
    );

    _isRecording = true;
    _isPaused = false;
    _startTimer();
    notifyListeners();
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    await _recorder.pause();
    _timer?.cancel();
    _isPaused = true;
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    await _recorder.resume();
    _startTimer();
    _isPaused = false;
    notifyListeners();
  }

  Future<void> stopRecording({
    NoteCategory category = NoteCategory.lecture,
    String language = 'en',
  }) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _isRecording = false;
    _isPaused = false;
    _isProcessing = true;
    notifyListeners();

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        throw Exception('Recording failed — no audio captured.');
      }

      final audioFile = File(path);
      final fileSize = await audioFile.length();
      if (fileSize < 1000) {
        throw Exception(
          'Recording too short. Please record at least 2 seconds.',
        );
      }

      final noteId = _pendingNoteId ?? _uuid.v4();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final dur = _seconds;

      // ── Step 1: Upload audio ──────────────────────────────
      _setStatus('Uploading audio…', PipelineStep.uploading);
      String? audioUrl;
      try {
        audioUrl = await _storage.uploadAudio(
          audioFile,
          noteId: noteId,
          onProgress: (p) {
            _uploadProgress = p;
            notifyListeners();
          },
        );
      } catch (e) {
        // Non-fatal — continue without cloud storage URL
        debugPrint('Storage upload failed: $e');
      }

      // ── Step 2: Transcribe with Whisper ───────────────────
      _setStatus('Transcribing your speech…', PipelineStep.transcribing);
      final transcription = await _ai.transcribe(audioFile, language: language);
      _liveTranscript = transcription;
      notifyListeners();

      // ── Step 3: Summarize with GPT-4o ─────────────────────
      _setStatus('Summarizing with AI…', PipelineStep.summarizing);
      final summary = await _ai.summarize(transcription, language: language);

      // ── Step 4: Extract keywords ───────────────────────────
      _setStatus('Extracting keywords…', PipelineStep.keywords);
      final keywords = await _ai.extractKeywords(transcription);

      // ── Step 5: Generate title ─────────────────────────────
      _setStatus('Generating title…', PipelineStep.title);
      final title = await _ai.generateTitle(transcription);

      // ── Step 6: Build NoteModel ────────────────────────────
      final wordCount = transcription.trim().split(RegExp(r'\s+')).length;
      final now = DateTime.now();

      _processedNote = NoteModel(
        id: noteId,
        userId: uid,
        title: title,
        transcription: transcription,
        summary: summary,
        language: language,
        category: category,
        keywords: keywords,
        audioUrl: audioUrl,
        createdAt: now,
        updatedAt: now,
        wordCount: wordCount,
        duration: dur,
        isFavorite: false,
      );

      _setStatus('Done!', PipelineStep.done);

      // Clean up temp file
      try {
        await audioFile.delete();
      } catch (_) {}
    } catch (e) {
      _error = e.toString();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void cancelRecording() {
    _timer?.cancel();
    // ignore: body_might_complete_normally_catch_error
    _recorder.stop().catchError((_) {});
    _recorder.cancel().catchError((_) {});
    _isRecording = false;
    _isPaused = false;
    _isProcessing = false;
    _seconds = 0;
    _liveTranscript = '';
    _uploadProgress = 0.0;
    _error = null;
    _processedNote = null;
    _audioPath = null;
    _pendingNoteId = null;
    notifyListeners();
  }

  void clearProcessed() {
    _processedNote = null;
    _error = null;
    _liveTranscript = '';
    _seconds = 0;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Timer ────────────────────────────────────────────────────
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      notifyListeners();
    });
  }

  void _setStatus(String msg, PipelineStep step) {
    _processingStatus = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
