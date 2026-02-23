// lib/providers/recording_provider.dart
// STUB — Full implementation comes in the backend phase

import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class RecordingProvider extends ChangeNotifier {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  int _seconds = 0;
  String _liveTranscript = '';
  String _processingStatus = '';
  NoteModel? _processedNote;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isProcessing => _isProcessing;
  String get liveTranscript => _liveTranscript;
  String get processingStatus => _processingStatus;
  NoteModel? get processedNote => _processedNote;

  String get formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> startRecording() async {
    _isRecording = true;
    _isPaused = false;
    _seconds = 0;
    _liveTranscript = '';
    _processedNote = null;
    notifyListeners();
  }

  Future<void> pauseRecording() async {
    _isPaused = true;
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    _isPaused = false;
    notifyListeners();
  }

  Future<void> stopRecording({
    NoteCategory category = NoteCategory.lecture,
  }) async {
    _isRecording = false;
    _isPaused = false;
    // Full AI pipeline in backend phase
    notifyListeners();
  }

  void cancelRecording() {
    _isRecording = false;
    _isPaused = false;
    _isProcessing = false;
    _seconds = 0;
    _liveTranscript = '';
    _processedNote = null;
    notifyListeners();
  }

  void clearProcessed() {
    _processedNote = null;
    notifyListeners();
  }
}
