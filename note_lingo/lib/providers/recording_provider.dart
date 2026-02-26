// lib/providers/recording_provider.dart
//
// Recording pipeline using YOUR LOCAL AI MODEL only.
// No OpenAI API keys needed.
//
// Pipeline:
//   1. Record audio (.m4a)
//   2. Upload to Firebase Storage (optional)
//   3. Transcribe with YOUR Wav2Vec2 model (Flask API)
//   4. Generate summary locally (no GPT needed)
//   5. Extract keywords locally
//   6. Create NoteModel → hand off to NotesProvider

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../services/storage_service.dart';
import '../services/local_ai_service.dart';

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
  // ── Internal ─────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final StorageService _storage = StorageService();
  final LocalAiService _localAi = LocalAiService();
  final Uuid _uuid = const Uuid();

  Timer? _timer;
  String? _audioPath;
  String? _pendingNoteId;

  // ── State ─────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  int _seconds = 0;
  String _liveTranscript = '';
  String _processingStatus = '';
  String? _error;
  NoteModel? _processedNote;
  double _uploadProgress = 0.0;

  // ── Getters ───────────────────────────────────────────────────
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

  // ═══════════════════════════════════════════════════════════════
  //  RECORDING CONTROLS
  // ═══════════════════════════════════════════════════════════════

  Future<void> startRecording() async {
    _error = null;
    _processedNote = null;
    _liveTranscript = '';
    _seconds = 0;
    _uploadProgress = 0.0;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _error = 'Microphone permission denied. Please allow in Settings.';
      notifyListeners();
      return;
    }

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

      // ── Step 1: Upload to Firebase Storage (optional) ────────
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
        debugPrint('Storage upload skipped: $e');
      }

      // ── Step 2: Transcribe with YOUR local model ──────────────
      _setStatus('Transcribing with your AI model…', PipelineStep.transcribing);

      final serverRunning = await _localAi.isReachable();
      if (!serverRunning) {
        throw Exception(
          'Local AI server is not running!\n\n'
          'Start it on your PC:\n'
          '  py -3.11 flask_api/app.py\n\n'
          'Then make sure your phone and PC\nare on the same WiFi network.',
        );
      }

      final result = await _localAi.transcribe(audioFile);
      final transcription = result.text;

      if (transcription.isEmpty) {
        throw Exception(
          'Could not transcribe audio.\n'
          'Please speak clearly and try again.\n'
          'Recording more training samples improves accuracy.',
        );
      }

      _liveTranscript = transcription;
      notifyListeners();

      // ── Step 3: Summary (local, no API) ───────────────────────
      _setStatus('Generating summary…', PipelineStep.summarizing);
      final summary = _generateLocalSummary(transcription);

      // ── Step 4: Keywords (local, no API) ──────────────────────
      _setStatus('Extracting keywords…', PipelineStep.keywords);
      final keywords = _extractLocalKeywords(transcription);

      // ── Step 5: Title (local, no API) ─────────────────────────
      _setStatus('Creating title…', PipelineStep.title);
      final title = _generateLocalTitle(transcription);

      // ── Step 6: Build NoteModel ────────────────────────────────
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

  // ═══════════════════════════════════════════════════════════════
  //  LOCAL HELPERS — runs on device, zero API calls
  // ═══════════════════════════════════════════════════════════════

  String _generateLocalSummary(String text) {
    if (text.isEmpty) return 'No content transcribed.';
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.length <= 2) return text;
    return '${sentences[0]}. ${sentences[1]}.';
  }

  List<String> _extractLocalKeywords(String text) {
    if (text.isEmpty) return [];
    const stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'from',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'this',
      'that',
      'it',
      'we',
      'you',
      'i',
      'he',
      'she',
      'they',
      'not',
      'so',
    };
    final wordCount = <String, int>{};
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length > 3 && !stopWords.contains(word)) {
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      }
    }
    final sorted = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  String _generateLocalTitle(String text) {
    if (text.isEmpty) return 'New Recording';
    final words = text.trim().split(RegExp(r'\s+'));
    final titleWords = words.take(6).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).toList();
    final title = titleWords.join(' ');
    return words.length > 6 ? '$title…' : title;
  }

  // ═══════════════════════════════════════════════════════════════
  //  MISC
  // ═══════════════════════════════════════════════════════════════

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
