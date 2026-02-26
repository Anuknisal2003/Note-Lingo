// flutter_integration/recording_provider_local_patch.dart
//
// HOW TO SWITCH YOUR APP FROM OPENAI WHISPER TO YOUR LOCAL MODEL
// ──────────────────────────────────────────────────────────────
// In lib/providers/recording_provider.dart, find the stopRecording()
// method and replace the Whisper call with this:
//
// ── BEFORE (OpenAI Whisper) ──────────────────────────────────────
//
//   final transcription = await _ai.transcribe(audioFile, language: language);
//
// ── AFTER (Your Local Model) ─────────────────────────────────────
//
//   String transcription;
//   final localAi = LocalAiService();
//   final isLocal = await localAi.isReachable();
//
//   if (isLocal) {
//     _setStatus('Transcribing with your AI model…', PipelineStep.transcribing);
//     final result = await localAi.transcribe(audioFile);
//     transcription = result.text;
//   } else {
//     // Fallback to OpenAI Whisper if local server is not running
//     _setStatus('Transcribing with Whisper…', PipelineStep.transcribing);
//     transcription = await _ai.transcribe(audioFile, language: language);
//   }
//
// ── FULL UPDATED stopRecording() ─────────────────────────────────
//
// Copy this entire method into recording_provider.dart to replace
// the existing stopRecording():

/*

  Future<void> stopRecording({
    NoteCategory category = NoteCategory.lecture,
    String language = 'en',
  }) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _isRecording  = false;
    _isPaused     = false;
    _isProcessing = true;
    notifyListeners();

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        throw Exception('Recording failed — no audio captured.');
      }

      final audioFile = File(path);
      final fileSize  = await audioFile.length();
      if (fileSize < 1000) {
        throw Exception('Recording too short. Please record at least 2 seconds.');
      }

      final noteId = _pendingNoteId ?? _uuid.v4();
      final uid    = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final dur    = _seconds;

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
        debugPrint('Storage upload failed: $e');
      }

      // ── Step 2: Transcribe ────────────────────────────────
      // Try local model first, fall back to Whisper
      String transcription;
      final localAi = LocalAiService();
      final useLocal = await localAi.isReachable();

      if (useLocal) {
        _setStatus('Transcribing with your AI model…', PipelineStep.transcribing);
        final result = await localAi.transcribe(audioFile);
        transcription = result.text;
        debugPrint('Local AI inference time: ${result.inferenceTime}s');
      } else {
        _setStatus('Transcribing with Whisper…', PipelineStep.transcribing);
        transcription = await _ai.transcribe(audioFile, language: language);
      }

      _liveTranscript = transcription;
      notifyListeners();

      // ── Step 3: Summarize ─────────────────────────────────
      _setStatus('Summarizing with GPT-4o…', PipelineStep.summarizing);
      final summary = await _ai.summarize(transcription, language: language);

      // ── Step 4: Keywords ──────────────────────────────────
      _setStatus('Extracting keywords…', PipelineStep.keywords);
      final keywords = await _ai.extractKeywords(transcription);

      // ── Step 5: Title ─────────────────────────────────────
      _setStatus('Generating title…', PipelineStep.title);
      final title = await _ai.generateTitle(transcription);

      // ── Step 6: Build NoteModel ───────────────────────────
      final wordCount = transcription.trim().split(RegExp(r'\s+')).length;
      final now       = DateTime.now();

      _processedNote = NoteModel(
        id:            noteId,
        userId:        uid,
        title:         title,
        transcription: transcription,
        summary:       summary,
        language:      language,
        category:      category,
        keywords:      keywords,
        audioUrl:      audioUrl,
        createdAt:     now,
        updatedAt:     now,
        wordCount:     wordCount,
        duration:      dur,
        isFavorite:    false,
      );

      _setStatus('Done!', PipelineStep.done);

      try { await audioFile.delete(); } catch (_) {}

    } catch (e) {
      _error = e.toString();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

*/
