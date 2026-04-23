// lib/providers/recording_provider.dart
// Full pipeline: Record → Whisper transcribe → Custom BART summarise → Save
// NO OpenAI. NO API keys. 100% local.

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../services/local_ai_service.dart';

enum RecordingStatus { idle, recording, processing, done, error }

class RecordingProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────
  RecordingStatus _status = RecordingStatus.idle;
  String _statusMsg = '';
  String _transcript = '';
  String _summary = ''; // raw summary text
  SummaryResult? _summaryResult; // full structured result
  List<String> _keywords = [];
  String _noteTitle = '';
  NoteCategory _category = NoteCategory.other;
  String _language = 'en';
  bool _isFavorite = false;
  String? _errorMessage;
  NoteModel? _savedNote;
  int _durationSeconds = 0;
  bool _isPaused = false;
  double _uploadProgress = 0;
  Timer? _ticker;

  // ── Internal ──────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final LocalAiService _ai = LocalAiService();
  String? _audioPath;

  // ── Getters ───────────────────────────────────────────
  RecordingStatus get status => _status;
  String get statusMsg => _statusMsg;
  String get transcript => _transcript;
  String get liveTranscript => _transcript;
  String get summary => _summary;
  SummaryResult? get summaryResult => _summaryResult;
  List<String> get keywords => _keywords;
  String get noteTitle => _noteTitle;
  String get category => _category.name;
  NoteCategory get categoryEnum => _category;
  String get language => _language;
  bool get isFavorite => _isFavorite;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  NoteModel? get savedNote => _savedNote;
  NoteModel? get processedNote => _savedNote;
  bool get isRecording => _status == RecordingStatus.recording;
  bool get isProcessing => _status == RecordingStatus.processing;
  bool get isPaused => _isPaused;
  String get processingStatus => _statusMsg;
  double get uploadProgress => _uploadProgress;
  String get formattedTime {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Setters ───────────────────────────────────────────
  void setCategory(String c) {
    _category = NoteCategory.values.firstWhere(
      (e) => e.name == c,
      orElse: () => NoteCategory.other,
    );
    notifyListeners();
  }

  void setCategoryEnum(NoteCategory c) {
    _category = c;
    notifyListeners();
  }

  void setLanguage(String l) {
    _language = l;
    notifyListeners();
  }

  void toggleFavorite() {
    _isFavorite = !_isFavorite;
    notifyListeners();
  }

  // ── Start recording ───────────────────────────────────
  Future<void> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _setError(
          'Microphone permission denied. Please enable it in settings.',
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      _audioPath =
          '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _audioPath!,
      );

      _status = RecordingStatus.recording;
      _isPaused = false;
      _durationSeconds = 0;
      _statusMsg = 'Recording… tap stop when done';
      _clearResults();
      _startTicker();
      notifyListeners();
    } catch (e) {
      _setError('Failed to start recording: $e');
    }
  }

  // ── Stop recording → process ──────────────────────────
  Future<void> stopRecording({NoteCategory? category, String? language}) async {
    if (_status != RecordingStatus.recording && !_isPaused) return;

    try {
      if (category != null) _category = category;
      if (language != null) _language = language;

      _stopTicker();
      await _recorder.stop();
      _isPaused = false;
      _status = RecordingStatus.processing;
      _statusMsg = 'Checking AI server…';
      _uploadProgress = 0.15;
      notifyListeners();

      await _processAudio();
    } catch (e) {
      _setError('Failed to stop recording: $e');
    }
  }

  // ── Full AI pipeline ──────────────────────────────────
  Future<void> _processAudio() async {
    try {
      final audioFile = File(_audioPath!);
      if (!await audioFile.exists()) {
        _setError('Audio file not found. Please try again.');
        return;
      }

      // ── Step 1: Check server ──────────────────────────
      _statusMsg = 'Connecting to AI server…';
      _uploadProgress = 0.25;
      notifyListeners();

      final serverUp = await _ai.isServerAvailable();
      if (!serverUp) {
        _setError(
          'AI server not reachable.\n\n'
          'Start it on your PC:\n'
          '  py -3.11 flask_api/app.py\n\n'
          'Make sure phone and PC are on the same Wi-Fi.',
        );
        return;
      }

      // ── Step 2: Transcribe ───────────────
      _statusMsg = 'Transcribing......';
      _uploadProgress = 0.45;
      notifyListeners();

      final text = await _ai.transcribe(audioFile);

      if (text.isEmpty) {
        _setError('No speech detected. Please speak clearly and try again.');
        return;
      }
      _transcript = text;

      // ── Step 3: Summarise with custom BART ───────────
      _statusMsg = 'Summarising with custom AI model…';
      _uploadProgress = 0.7;
      notifyListeners();

      SummaryResult result;
      try {
        result = await _ai.summarise(
          text,
          category: _categoryForApi(_category),
        );
      } catch (_) {
        // Fallback: use simple local extraction
        result = _localFallbackSummary(text);
      }

      _summaryResult = result;
      _summary = result.toMarkdown();
      _keywords = result.keywords;
      _noteTitle = result.title.isNotEmpty ? result.title : _extractTitle(text);

      // ── Step 4: Save to Firestore ─────────────────────
      _statusMsg = 'Saving note…';
      _uploadProgress = 0.9;
      notifyListeners();

      await _saveNote(audioFile);

      _status = RecordingStatus.done;
      _statusMsg = 'Note saved successfully!';
      _uploadProgress = 1;
      notifyListeners();
    } catch (e) {
      _setError('Processing failed: $e');
    }
  }

  // ── Local fallback summary ────────────────────────────
  SummaryResult _localFallbackSummary(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 10)
        .toList();

    final overview = sentences.isNotEmpty ? sentences.first : text;
    final keyPoints = sentences.length > 1
        ? sentences.sublist(1, sentences.length.clamp(1, 4))
        : <String>[];
    final conclusion = sentences.length > 1 ? sentences.last : overview;
    final keywords = _simpleKeywords(text);

    final styles = {
      NoteCategory.lecture: ['📚 Lecture Notes', 'Key Concepts'],
      NoteCategory.meeting: ['🗓️ Meeting Minutes', 'Action Items'],
      NoteCategory.interview: ['🎙️ Interview Notes', 'Key Responses'],
      NoteCategory.personal: ['📝 Personal Note', 'Key Points'],
      NoteCategory.other: ['📄 Note Summary', 'Key Points'],
    };
    final style = styles[_category] ?? styles[NoteCategory.other]!;

    return SummaryResult(
      title: _extractTitle(text),
      categoryHeading: style[0],
      overview: overview,
      keyPoints: keyPoints,
      pointsLabel: style[1],
      keywords: keywords,
      conclusion: conclusion,
      rawSummary: sentences.take(3).join(' '),
      method: 'local-fallback',
    );
  }

  List<String> _simpleKeywords(String text) {
    const stop = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'was',
      'were',
      'be',
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
      'to',
      'of',
      'in',
      'on',
      'at',
      'by',
      'for',
      'with',
      'and',
      'but',
      'or',
      'this',
      'that',
      'i',
      'you',
      'it',
      'we',
      'they',
      'not',
      'just',
      'very',
      'also',
      'than',
      'too',
      'all',
      'each',
    };
    final freq = <String, int>{};
    for (final w in text.toLowerCase().split(RegExp(r'\W+'))) {
      if (w.length >= 4 && !stop.contains(w)) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  String _extractTitle(String text) {
    final words = text.split(' ').take(10).toList();
    final title = words.join(' ').replaceAll(RegExp(r'[^\w\s]'), '');
    return title.isNotEmpty ? title : 'New Note';
  }

  String _categoryForApi(NoteCategory category) {
    if (category == NoteCategory.other) return 'general';
    return category.name;
  }

  // ── Save note to Firestore ────────────────────────────
  Future<void> _saveNote(File audioFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to save recordings.');
    }

    // Try to upload audio (optional — skip if storage not set up)
    String audioUrl = '';
    try {
      // Uncomment if Firebase Storage is configured:
      // audioUrl = await StorageService().uploadAudio(audioFile, uid);
    } catch (_) {
      debugPrint('Audio upload skipped');
    }

    final note = NoteModel(
      id: '',
      userId: uid,
      title: _noteTitle,
      transcription: _transcript,
      summary: _summary,
      keywords: _keywords,
      category: _category,
      language: _language,
      audioUrl: audioUrl,
      isFavorite: _isFavorite,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      wordCount: _transcript.split(' ').length,
      duration: _durationSeconds,
    );

    final ref = await FirebaseFirestore.instance
        .collection('notes')
        .add(note.toFirestore());

    _savedNote = note.copyWith(id: ref.id);
  }

  Future<void> pauseRecording() async {
    if (!isRecording || _isPaused) return;
    try {
      await _recorder.pause();
      _isPaused = true;
      _stopTicker();
      notifyListeners();
    } catch (e) {
      _setError('Failed to pause recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!isRecording || !_isPaused) return;
    try {
      await _recorder.resume();
      _isPaused = false;
      _startTicker();
      notifyListeners();
    } catch (e) {
      _setError('Failed to resume recording: $e');
    }
  }

  Future<void> cancelRecording() async {
    try {
      _stopTicker();
      await _recorder.stop();
    } catch (_) {}
    if (_audioPath != null) {
      final f = File(_audioPath!);
      if (await f.exists()) {
        await f.delete();
      }
    }
    reset();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == RecordingStatus.error) {
      _status = RecordingStatus.idle;
      _statusMsg = '';
    }
    notifyListeners();
  }

  void clearProcessed() {
    _savedNote = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds += 1;
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ── Helpers ───────────────────────────────────────────
  void _setError(String msg) {
    _stopTicker();
    _status = RecordingStatus.error;
    _isPaused = false;
    _errorMessage = msg;
    _statusMsg = 'Error';
    notifyListeners();
  }

  void _clearResults() {
    _transcript = '';
    _summary = '';
    _summaryResult = null;
    _keywords = [];
    _noteTitle = '';
    _errorMessage = null;
    _savedNote = null;
    _uploadProgress = 0;
  }

  void reset() {
    _stopTicker();
    _status = RecordingStatus.idle;
    _isPaused = false;
    _durationSeconds = 0;
    _statusMsg = '';
    _clearResults();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTicker();
    _recorder.dispose();
    super.dispose();
  }
}
