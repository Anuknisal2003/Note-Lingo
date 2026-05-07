// lib/providers/recording_provider.dart
// Full pipeline: Record → Whisper transcribe → Custom BART summarise → Save
// With offline support, OpenAI fallback, and AI enhancements

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../services/local_ai_service.dart';
import '../services/enhanced_ai_service.dart';
import '../services/offline_queue_service.dart';
import '../services/smart_organization_service.dart';
import '../services/analytics_service.dart';

enum RecordingStatus { idle, recording, processing, done, error }

class RecordingProvider extends ChangeNotifier {
  RecordingProvider() {
    unawaited(syncOfflineQueue());
  }

  // ── State ─────────────────────────────────────────────
  RecordingStatus _status = RecordingStatus.idle;
  String _statusMsg = '';
  String _transcript = '';
  String _originalTranscript = '';
  String _englishTranscript = '';
  String _localizedTranscript = '';
  String _summary = ''; // raw summary text
  SummaryResult? _summaryResult; // full structured result
  List<String> _keywords = [];
  String _noteTitle = '';
  NoteCategory _category = NoteCategory.other;
  String _language = 'en';
  bool _isFavorite = false;
  String? _errorMessage;
  NoteModel? _savedNote;

  // New fields for enhancements
  AiEnhancement? _enhancement;
  List<SmartTag> _smartTags = [];
  int _offlineQueueCount = 0;
  int _durationSeconds = 0;
  bool _isPaused = false;
  double _uploadProgress = 0;
  Timer? _ticker;

  // ── Internal ──────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final LocalAiService _ai = LocalAiService();
  final EnhancedAiService _enhancedAi = EnhancedAiService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final SmartOrganizationService _smartOrg = SmartOrganizationService();
  final AnalyticsService _analytics = AnalyticsService();
  String? _audioPath;

  // ── Getters ───────────────────────────────────────────
  RecordingStatus get status => _status;
  String get statusMsg => _statusMsg;
  String get transcript => _transcript;
  String get originalTranscript => _originalTranscript;
  String get englishTranscript => _englishTranscript;
  String get localizedTranscript => _localizedTranscript;
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

  // New getters
  AiEnhancement? get enhancement => _enhancement;
  List<SmartTag> get smartTags => _smartTags;
  int get offlineQueueCount => _offlineQueueCount;

  // Activity logging: terminal-only
  /// Check offline queue count
  Future<void> updateOfflineQueueCount() async {
    _offlineQueueCount = await _offlineQueue.getQueueCount();
    notifyListeners();
  }

  void _addLog(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$stamp] $message';
    // Print to terminal for developer tracing (terminal-only)
    debugPrint(line);
  }

  /// Sync any queued offline recordings when the server is back.
  Future<void> syncOfflineQueue() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        return;
      }

      if (!await _ai.isServerAvailable()) {
        _addLog('AI server offline; sync skipped');
        return;
      }

      final pendingItems = await _offlineQueue.getPendingItems();
      if (pendingItems.isEmpty) {
        _addLog('No offline notes to sync');
        await updateOfflineQueueCount();
        return;
      }

      _addLog('Syncing ${pendingItems.length} offline note(s)');

      for (final item in pendingItems) {
        try {
          _status = RecordingStatus.processing;
          _statusMsg = 'Syncing offline note…';
          _uploadProgress = 0.5;
          notifyListeners();

          final audioFile = File(item.audioPath);
          if (!await audioFile.exists()) {
            _addLog('Skipped ${item.id}: audio file missing');
            await _offlineQueue.incrementRetry(item.id);
            continue;
          }

          _addLog('Transcribing offline note ${item.id}');
          final text = await _ai.transcribe(audioFile);
          if (text.isEmpty) {
            _addLog('Skipped ${item.id}: no transcript returned');
            await _offlineQueue.incrementRetry(item.id);
            continue;
          }

          _addLog('Summarising offline note ${item.id}');
          final summaryResult = await _ai.summarise(
            text,
            category: _categoryForApi(item.category),
          );

          _transcript = text;
          _summaryResult = summaryResult;
          _summary = summaryResult.toMarkdown();
          _keywords = summaryResult.keywords;
          _noteTitle = summaryResult.title.isNotEmpty
              ? summaryResult.title
              : _extractTitle(text);
          _category = item.category;
          _language = item.language;
          _isFavorite = item.isFavorite;
          _enhancement = await _enhancedAi.analyzeNote(text);
          _smartTags = await _smartOrg.autoTag(text);

          await _saveNoteToFirestore(audioFile);
          await _offlineQueue.removeFromQueue(item.id);
          _addLog('Offline note ${item.id} synced successfully');
        } catch (e) {
          await _offlineQueue.incrementRetry(item.id);
          _addLog('Offline note ${item.id} sync failed: $e');
          debugPrint('Offline sync failed for ${item.id}: $e');
        }
      }

      await updateOfflineQueueCount();
      _status = RecordingStatus.done;
      _statusMsg = 'Offline notes synced';
      _addLog('Offline sync complete');
      notifyListeners();
    } catch (e) {
      _addLog('Offline sync skipped: $e');
      debugPrint('Offline sync skipped: $e');
    }
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
      _addLog('Starting new recording');
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _setError(
          'Microphone permission denied. Please enable it in settings.',
        );
        return;
      }

      final persistentDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${persistentDir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      _audioPath =
          '${recordingsDir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      _addLog('Recording stopped; starting processing');
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
      _addLog('Checking AI server availability');
      notifyListeners();

      final serverUp = await _ai.isServerAvailable();
      if (!serverUp) {
        _addLog('AI server not reachable; saving offline');
        await _queueOfflineRecording(audioFile);
        _status = RecordingStatus.done;
        _statusMsg = 'Saved offline. It will sync when the AI server is back.';
        _uploadProgress = 1;
        notifyListeners();
        return;
      }

      // ── Step 2: Transcribe ───────────────
      _statusMsg = 'Transcribing......';
      _uploadProgress = 0.45;
      _addLog('Sending audio to Whisper endpoint');
      notifyListeners();

      final transcribeWatch = Stopwatch()..start();
      final fileSize = await audioFile.length();
      _addLog('Audio path: ${audioFile.path} (size: ${fileSize} bytes)');
      final text = await _ai.transcribe(audioFile);
      transcribeWatch.stop();
      _addLog(
        'Transcription complete in ${transcribeWatch.elapsedMilliseconds} ms',
      );

      if (text.isEmpty) {
        final size = await audioFile.length();
        _addLog('Transcription returned empty text (file size: ${size} bytes)');
        _setError(
          'No speech detected. Audio file size: ${size} bytes. Please speak louder, check microphone permissions, or try again.',
        );
        return;
      }
      // Keep original, then translate to English as canonical form
      _originalTranscript = text;
      _addLog('Translating transcript to English (if needed)');
      _englishTranscript = await _enhancedAi.translateToEnglish(text);
      _transcript = _englishTranscript;

      // ── Step 3: Summarise with custom BART ───────────
      _statusMsg = 'Summarising with custom AI model…';
      _uploadProgress = 0.7;
      _addLog('Sending transcript to BART summariser');
      notifyListeners();

      SummaryResult result;
      try {
        final summaryWatch = Stopwatch()..start();
        result = await _ai.summarise(
          _transcript,
          category: _categoryForApi(_category),
        );
        summaryWatch.stop();
        _addLog(
          'Summarisation complete in ${summaryWatch.elapsedMilliseconds} ms',
        );
      } catch (_) {
        // Fallback: use simple local extraction
        result = _localFallbackSummary(text);
        _addLog('Summariser fallback used');
      }

      _summaryResult = result;
      _summary = result.toMarkdown();
      // Localize transcript/summary to user's preferred language if requested
      if (_language != 'en') {
        try {
          _addLog('Translating transcript and summary to ${_language}');
          _localizedTranscript = await _enhancedAi.translate(
            _englishTranscript,
            _language,
          );
          _summary = await _enhancedAi.translate(_summary, _language);
        } catch (_) {
          _addLog('Translation to ${_language} failed; showing English');
          _localizedTranscript = _englishTranscript;
        }
      } else {
        _localizedTranscript = _englishTranscript;
      }
      _keywords = result.keywords;
      _noteTitle = result.title.isNotEmpty
          ? result.title
          : _extractTitle(_englishTranscript);

      // ── Step 4: Save to Firestore ─────────────────────
      _statusMsg = 'Saving note…';
      _uploadProgress = 0.9;
      _addLog('Saving note to Firestore');
      notifyListeners();

      await _saveNoteToFirestore(audioFile);

      _status = RecordingStatus.done;
      _statusMsg = 'Note saved successfully!';
      _uploadProgress = 1;
      _addLog('Note saved successfully');
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
  Future<void> _queueOfflineRecording(File audioFile) async {
    try {
      final item = OfflineQueueItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        audioPath: audioFile.path,
        transcript: null,
        summary: null,
        category: _category,
        language: _language,
        isFavorite: _isFavorite,
        createdAt: DateTime.now(),
      );

      await _offlineQueue.addToQueue(item);
      await updateOfflineQueueCount();
      _addLog('Recorded offline note queued for later sync');
    } catch (e) {
      _setError('Could not save offline recording: $e');
    }
  }

  Future<void> _saveNoteToFirestore(File audioFile) async {
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

    // Get AI enhancements
    _statusMsg = 'Analyzing content...';
    _uploadProgress = 0.75;
    _addLog('Running AI enhancements');
    notifyListeners();

    _enhancement = await _enhancedAi.analyzeNote(_transcript);
    _smartTags = await _smartOrg.autoTag(_transcript);

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
      tags: _smartTags.map((t) => t.name).toList(),
      sentiment: _enhancement?.sentiment,
      sentimentScore: _enhancement?.sentimentScore ?? 0.5,
      speakers: _enhancement?.speakers ?? [],
      qaItems:
          _enhancement?.qaItems
              .map((q) => {'question': q.question, 'answer': q.answer})
              .toList() ??
          [],
      entities: _enhancement?.entities ?? [],
    );

    _statusMsg = 'Saving note...';
    _uploadProgress = 0.9;
    notifyListeners();

    final ref = await FirebaseFirestore.instance
        .collection('notes')
        .add(note.toFirestore());

    _savedNote = note.copyWith(id: ref.id);

    // Record analytics
    try {
      await _analytics.recordNoteCreated(
        ref.id,
        durationSeconds: _durationSeconds,
        wordCount: note.wordCount,
        category: _category,
      );
    } catch (_) {
      debugPrint('Analytics recording failed');
    }
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
