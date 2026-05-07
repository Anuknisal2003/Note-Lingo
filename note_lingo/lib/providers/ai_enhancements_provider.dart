import 'package:flutter/foundation.dart';
import '../services/enhanced_ai_service.dart';
import '../services/analytics_service.dart';
import '../models/note_model.dart';

class AiEnhancementsProvider extends ChangeNotifier {
  final EnhancedAiService _aiService = EnhancedAiService();
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _isAnalyzing = false;
  String _analysisStatus = '';
  AiEnhancement? _enhancement;
  String? _error;

  // Getters
  bool get isAnalyzing => _isAnalyzing;
  String get analysisStatus => _analysisStatus;
  AiEnhancement? get enhancement => _enhancement;
  String? get error => _error;

  Future<void> analyzeNote(String text, String noteId) async {
    try {
      _isAnalyzing = true;
      _error = null;
      _analysisStatus = 'Analyzing sentiment...';
      notifyListeners();

      final enhancement = await _aiService.analyzeNote(text);
      _enhancement = enhancement;
      _analysisStatus = 'Analysis complete!';
      notifyListeners();
    } catch (e) {
      _error = 'Analysis failed: $e';
      notifyListeners();
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> recordNoteCreated(
    String noteId, {
    required int durationSeconds,
    required int wordCount,
    required NoteCategory category,
  }) async {
    try {
      await _analyticsService.recordNoteCreated(
        noteId,
        durationSeconds: durationSeconds,
        wordCount: wordCount,
        category: category,
      );
    } catch (e) {
      _error = 'Failed to record analytics: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearEnhancement() {
    _enhancement = null;
    notifyListeners();
  }
}
