// lib/providers/recording_provider.dart
// Full pipeline: Record → Whisper transcribe → Custom BART summarise → Save
// With offline support, OpenAI fallback, and AI enhancements

import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/note_model.dart';
import '../services/local_ai_service.dart';
import '../services/enhanced_ai_service.dart';
import '../services/offline_queue_service.dart';
import '../services/smart_organization_service.dart';
import '../services/analytics_service.dart';
import '../services/draft_service.dart';
import '../services/retry_backoff_service.dart';
import '../services/firestore_batch_service.dart';
import '../services/model_preload_service.dart';

enum RecordingStatus { idle, recording, processing, done, error }

enum RecordingQuality { low, medium, high }

class RecordingProvider extends ChangeNotifier with WidgetsBindingObserver {
  RecordingProvider() {
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(syncOfflineQueue());
      } else {
        unawaited(updateOfflineQueueCount());
      }
    });
    unawaited(updateOfflineQueueCount());
    unawaited(syncOfflineQueue());
    // Trigger async model preload (non-blocking)
    unawaited(_modelPreload.preloadModels());

    // Sync when network becomes available (WiFi or mobile data turns on)
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      if (hasNetwork) {
        _addLog('Network available — triggering offline sync');
        unawaited(syncOfflineQueue());
      }
    });
  }

  // ── State ─────────────────────────────────────────────
  RecordingStatus _status = RecordingStatus.idle;
  String _statusMsg = '';
  String _transcript = '';
  String _originalTranscript = '';
  String _englishTranscript = '';
  final String _localizedTranscript = '';
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
  // VAD / quality settings
  RecordingQuality _quality = RecordingQuality.high;
  bool _vadEnabled = true;
  bool _noiseCancellation = false;
  // Denoising configuration
  String _denoiseMethod = 'auto'; // 'auto', 'light', 'spectral', 'aggressive'
  double _denoiseStrength = 1.0; // 0.5=light, 1.0=medium, 1.5=aggressive

  // ── Internal ──────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final LocalAiService _ai = LocalAiService();
  final EnhancedAiService _enhancedAi = EnhancedAiService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final SmartOrganizationService _smartOrg = SmartOrganizationService();
  final AnalyticsService _analytics = AnalyticsService();
  final DraftService _draftService = DraftService();
  final FirestoreBatchService _batch = FirestoreBatchService();
  final ModelPreloadService _modelPreload = ModelPreloadService();
  String? _audioPath;
  String? _currentDraftId;
  bool _draftSaved = false;
  Timer? _draftTimer;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncingOfflineQueue = false;

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
  RecordingQuality get quality => _quality;
  bool get vadEnabled => _vadEnabled;
  bool get noiseCancellationEnabled => _noiseCancellation;
  bool get draftSaved => _draftSaved;
  String? get currentDraftId => _currentDraftId;
  String get denoiseMethod => _denoiseMethod;
  double get denoiseStrength => _denoiseStrength;

  // Activity logging: terminal-only
  /// Check offline queue count
  Future<void> updateOfflineQueueCount() async {
    _offlineQueueCount = await _offlineQueue.getQueueCount();
    notifyListeners();
  }

  /// Get pending offline items (ready to retry)
  Future<List<OfflineQueueItem>> getPendingItems() async {
    return _offlineQueue.getPendingItems();
  }

  /// Get backoff items (not yet ready to retry)
  Future<List<OfflineQueueItem>> getBackoffItems() async {
    return _offlineQueue.getBackoffItems();
  }

  /// Get all offline queue items
  Future<List<OfflineQueueItem>> getAllQueueItems() async {
    return _offlineQueue.getQueue();
  }

  /// Get failed items (exhausted all retries)
  Future<List<OfflineQueueItem>> getFailedItems() async {
    return _offlineQueue.getFailedItems();
  }

  /// Reset a failed item so it can be retried again
  Future<void> resetFailedItem(String itemId) async {
    await _offlineQueue.resetRetries(itemId);
    await updateOfflineQueueCount();
  }

  void _addLog(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$stamp] $message';
    debugPrint(line);
  }

  /// Sync offline recordings with batch processing and exponential backoff.
  Future<void> syncOfflineQueue() async {
    if (_isSyncingOfflineQueue) return;
    _isSyncingOfflineQueue = true;
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      if (!await _ai.isServerAvailable()) {
        _addLog('AI server offline; sync skipped');
        return;
      }

      // Show items still in backoff
      final backoffItems = await _offlineQueue.getBackoffItems();
      if (backoffItems.isNotEmpty) {
        final delays = backoffItems
            .map((i) {
              final delayStr = RetryBackoffService.formatDelay(
                i.getRetryDelaySeconds(),
              );
              return '${i.id.substring(0, 8)}($delayStr)';
            })
            .join(', ');
        _addLog('In backoff: $delays');
      }

      final pendingItems = await _offlineQueue.getPendingItems();
      if (pendingItems.isEmpty) {
        _addLog('No offline notes ready to sync');
        await updateOfflineQueueCount();
        return;
      }

      _addLog('Batch syncing ${pendingItems.length} offline note(s)');
      _status = RecordingStatus.processing;
      _uploadProgress = 0.3;
      notifyListeners();

      // Batch process: all items use transactional sync
      final results = await _offlineQueue.batchProcessItems(pendingItems, (
        item,
      ) async {
        final audioFile = File(item.audioPath);
        if (!await audioFile.exists()) throw Exception('audio missing');

        _statusMsg = 'Syncing ${item.id.substring(0, 8)}…';
        _uploadProgress = 0.5;
        notifyListeners();

        _addLog('Processing pipeline for ${item.id}');
        final summaryResult = await _ai.processAudio(
          audioFile,
          category: _categoryForApi(item.category),
          enableDenoise: true,
          denoiseMethod: item.denoiseMethod,
          denoiseStrength: item.denoiseStrength,
        );

        if (summaryResult.originalTranscript.isEmpty) {
          throw Exception('no transcript');
        }

        _originalTranscript = summaryResult.originalTranscript;
        _englishTranscript = summaryResult.englishTranscript.isNotEmpty
            ? summaryResult.englishTranscript
            : summaryResult.originalTranscript;
        _transcript = summaryResult.originalTranscript;
        _summaryResult = summaryResult;
        _summary = summaryResult.toMarkdown();
        _keywords = summaryResult.keywords;
        _noteTitle = summaryResult.title.isNotEmpty
            ? summaryResult.title
            : _extractTitle(_englishTranscript);
        _category = item.category;
        _language = summaryResult.detectedLanguage.isNotEmpty
            ? summaryResult.detectedLanguage
            : item.language;
        _isFavorite = item.isFavorite;
        _enhancement = await _enhancedAi.analyzeNote(_englishTranscript);
        _smartTags = await _smartOrg.autoTag(_englishTranscript);

        await _saveNoteToFirestore(audioFile);
        try {
          await _draftService.deleteDraft(item.id);
        } catch (_) {}
        _addLog('${item.id} ✓');
        return (summaryResult.originalTranscript, summaryResult.toMarkdown());
      });

      int ok = results.values.where((s) => s).length;
      int fail = results.values.where((s) => !s).length;
      _addLog('Batch result: $ok success, $fail retrying');

      await updateOfflineQueueCount();
      _status = RecordingStatus.done;
      _statusMsg = ok > 0 ? '$ok synced!' : 'Retrying…';
      _uploadProgress = 1;
      notifyListeners();
    } catch (e) {
      _addLog('Sync error: $e');
      debugPrint('Offline sync error: $e');
    } finally {
      _isSyncingOfflineQueue = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncOfflineQueue());
      unawaited(updateOfflineQueueCount());
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

  void setDenoiseMethod(String method) {
    _denoiseMethod = method;
    notifyListeners();
  }

  void setDenoiseStrength(double strength) {
    _denoiseStrength = (strength * 100).round() / 100; // Round to 2 decimals
    notifyListeners();
  }

  // ── Start recording ───────────────────────────────────
  Future<void> startRecording() async {
    await startRecordingWithOptions();
  }

  Future<void> startRecordingWithOptions({
    RecordingQuality quality = RecordingQuality.high,
    bool vadEnabled = true,
    bool noiseCancellation = false,
    String denoiseMethod = 'auto',
    double denoiseStrength = 1.0,
  }) async {
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

      // Apply quality presets
      _quality = quality;
      _vadEnabled = vadEnabled;
      _noiseCancellation = noiseCancellation;
      _denoiseMethod = denoiseMethod;
      _denoiseStrength = denoiseStrength;

      var encoder = AudioEncoder.aacLc;
      var bitRate = 128000;
      var sampleRate = 16000; // Use 16kHz for emulator compatibility
      switch (_quality) {
        case RecordingQuality.low:
          bitRate = 48000;
          sampleRate = 16000;
          break;
        case RecordingQuality.medium:
          bitRate = 64000;
          sampleRate = 16000;
          break;
        case RecordingQuality.high:
          bitRate = 128000;
          sampleRate = 16000;
      }

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: bitRate,
          sampleRate: sampleRate,
        ),
        path: _audioPath!,
      );

      // Start VAD polling if enabled
      if (_vadEnabled) {
        // VAD monitoring (voice activity detection)
      }

      // Start draft autosave timer (every 5s)
      _currentDraftId = 'draft_${DateTime.now().microsecondsSinceEpoch}';
      _draftSaved = false;
      _draftTimer?.cancel();
      _draftTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await _saveDraft();
      });

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
      // Stop VAD monitoring
      // stop draft autosave timer (keep draft on-disk for restore)
      _draftTimer?.cancel();
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

      // ── Step 2: Full pipeline (transcribe → translate → summarise) ──
      _statusMsg = 'Transcribing → Translating → Summarising…';
      _uploadProgress = 0.45;
      _addLog('Sending audio to /process pipeline');
      notifyListeners();

      final pipelineWatch = Stopwatch()..start();
      final fileSize = await audioFile.length();
      _addLog('Audio path: ${audioFile.path} (size: $fileSize bytes)');

      if (fileSize < 2048) {
        _setError(
          'No audio was captured. On the Android emulator, enable microphone input in the emulator settings or test on a device with a working mic.',
        );
        return;
      }

      SummaryResult result;
      try {
        result = await _ai.processAudio(
          audioFile,
          category: _categoryForApi(_category),
          enableDenoise: _noiseCancellation,
          denoiseMethod: _denoiseMethod,
          denoiseStrength: _denoiseStrength,
        );
        pipelineWatch.stop();
        _addLog(
          'Pipeline complete in ${pipelineWatch.elapsedMilliseconds} ms  '
          'lang=${result.detectedLanguage}  translated=${result.isTranslated}',
        );
      } catch (pipelineErr) {
        _addLog('Pipeline failed: $pipelineErr');
        final errStr = pipelineErr.toString();
        if (errStr.contains('TimeoutException')) {
          _setError(
            'Processing timed out. The AI model may need more time. '
            'Try a shorter recording or ensure the Flask server is running on a capable machine.',
          );
        } else {
          _setError('Processing failed: $pipelineErr');
        }
        return;
      }

      if (result.originalTranscript.isEmpty) {
        final size = await audioFile.length();
        _addLog('Pipeline returned empty transcript (file size: $size bytes)');
        _setError(
          size < 2048
              ? 'No audio was captured. On the Android emulator, enable microphone input in the emulator settings or test on a device with a working mic.'
              : 'No speech detected. Audio file size: $size bytes. Please speak louder, check microphone permissions, or try again.',
        );
        return;
      }

      // Populate provider state from pipeline result
      _originalTranscript = result.originalTranscript;
      _englishTranscript = result.englishTranscript.isNotEmpty
          ? result.englishTranscript
          : result.originalTranscript;
      _transcript = result.originalTranscript; // original stored in NoteModel
      _language = result.detectedLanguage.isNotEmpty
          ? result.detectedLanguage
          : _language;
      _summaryResult = result;
      _summary = result.toMarkdown();
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
      final draftId =
          _currentDraftId ?? 'draft_${DateTime.now().microsecondsSinceEpoch}';
      _currentDraftId = draftId;
      await _draftService.saveDraft(
        DraftItem(
          id: draftId,
          audioPath: audioFile.path,
          transcript: _transcript.isNotEmpty ? _transcript : null,
        ),
      );
      _draftSaved = true;

      final item = OfflineQueueItem(
        id: draftId,
        audioPath: audioFile.path,
        transcript: null,
        summary: null,
        category: _category,
        language: _language,
        isFavorite: _isFavorite,
        createdAt: DateTime.now(),
        denoiseMethod: _denoiseMethod,
        denoiseStrength: _denoiseStrength,
      );

      await _offlineQueue.addToQueue(item);
      await updateOfflineQueueCount();
      _addLog(
        'Recorded offline note saved to drafts and queued for later sync',
      );
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

    _enhancement = await _enhancedAi.analyzeNote(
      _englishTranscript.isNotEmpty ? _englishTranscript : _transcript,
    );
    _smartTags = await _smartOrg.autoTag(
      _englishTranscript.isNotEmpty ? _englishTranscript : _transcript,
    );

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

    // Use batch write for atomic operation
    final ids = await _batch.saveBatch([note]);
    final noteId = ids.isNotEmpty ? ids.first : '';

    _savedNote = note.copyWith(id: noteId);

    // Remove associated draft after successful save
    if (_currentDraftId != null) {
      try {
        await _draftService.deleteDraft(_currentDraftId!);
      } catch (_) {}
      _currentDraftId = null;
      _draftSaved = false;
    }

    // Record analytics
    try {
      await _analytics.recordNoteCreated(
        noteId,
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
    // Remove draft if user cancels explicitly
    if (_currentDraftId != null) {
      try {
        await _draftService.deleteDraft(_currentDraftId!);
      } catch (_) {}
      _currentDraftId = null;
      _draftSaved = false;
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

  Future<void> _saveDraft() async {
    try {
      if (_currentDraftId == null || _audioPath == null) return;
      final item = DraftItem(
        id: _currentDraftId!,
        audioPath: _audioPath,
        transcript: _transcript.isNotEmpty ? _transcript : null,
      );
      await _draftService.saveDraft(item);
      _draftSaved = true;
      _addLog('Draft saved: $_currentDraftId');
    } catch (e) {
      debugPrint('Draft save failed: $e');
    }
  }

  Future<void> restoreDraft(String id) async {
    final d = await _draftService.getDraft(id);
    if (d == null) throw StateError('Draft not found');
    _audioPath = d.audioPath;
    _transcript = d.transcript ?? '';
    _currentDraftId = d.id;
    _draftSaved = true;
    _status = RecordingStatus.idle;
    notifyListeners();
  }

  Future<List<DraftItem>> listDrafts() async {
    return await _draftService.listDrafts();
  }

  Future<void> deleteDraft(String id) async {
    try {
      await _draftService.deleteDraft(id);
      if (_currentDraftId == id) {
        _currentDraftId = null;
        _draftSaved = false;
      }
      notifyListeners();
    } catch (_) {}
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _connectivitySub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
