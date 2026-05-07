import 'package:flutter/foundation.dart';
import '../services/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsService _service = AnalyticsService();

  bool _isLoading = false;
  String? _error;

  // Data
  List<DailyStats>? _dailyStats;
  List<WordFrequency>? _wordFrequencies;
  Map<String, int>? _recordingHeatmap;
  Map<String, dynamic>? _progressStats;
  Map<String, int>? _categoryStats;
  Map<String, dynamic>? _favoriteStats;
  double _werScore = 0.92;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DailyStats>? get dailyStats => _dailyStats;
  List<WordFrequency>? get wordFrequencies => _wordFrequencies;
  Map<String, int>? get recordingHeatmap => _recordingHeatmap;
  Map<String, dynamic>? get progressStats => _progressStats;
  Map<String, int>? get categoryStats => _categoryStats;
  Map<String, dynamic>? get favoriteStats => _favoriteStats;
  double get werScore => _werScore;

  /// Load all analytics
  Future<void> loadAllAnalytics(DateTime startDate, DateTime endDate) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Load in parallel
      await Future.wait([
        _loadDailyStats(startDate, endDate),
        _loadWordFrequencies(startDate, endDate),
        _loadHeatmap(startDate, endDate),
        _loadProgressStats(),
        _loadCategoryStats(),
        _loadFavoriteStats(),
        _loadWerScore(),
      ]);

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load analytics: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDailyStats(DateTime startDate, DateTime endDate) async {
    try {
      _dailyStats = await _service.getDailyStats(startDate, endDate);
    } catch (e) {
      _error = 'Failed to load daily stats: $e';
    }
  }

  Future<void> _loadWordFrequencies(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      _wordFrequencies = await _service.getWordFrequency(startDate, endDate);
    } catch (e) {
      _error = 'Failed to load word frequencies: $e';
    }
  }

  Future<void> _loadHeatmap(DateTime startDate, DateTime endDate) async {
    try {
      _recordingHeatmap = await _service.getRecordingHeatmap(
        startDate,
        endDate,
      );
    } catch (e) {
      _error = 'Failed to load heatmap: $e';
    }
  }

  Future<void> _loadProgressStats() async {
    try {
      _progressStats = await _service.getProgressStats();
    } catch (e) {
      _error = 'Failed to load progress stats: $e';
    }
  }

  Future<void> _loadCategoryStats() async {
    try {
      _categoryStats = await _service.getCategoryStats();
    } catch (e) {
      _error = 'Failed to load category stats: $e';
    }
  }

  Future<void> _loadFavoriteStats() async {
    try {
      _favoriteStats = await _service.getFavoriteStats();
    } catch (e) {
      _error = 'Failed to load favorite stats: $e';
    }
  }

  Future<void> _loadWerScore() async {
    try {
      _werScore = await _service.getWerScore();
    } catch (e) {
      _werScore = 0.92;
    }
  }

  /// Get stats for custom date range
  Future<void> updateDateRange(DateTime startDate, DateTime endDate) async {
    await loadAllAnalytics(startDate, endDate);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _dailyStats = null;
    _wordFrequencies = null;
    _recordingHeatmap = null;
    _progressStats = null;
    _categoryStats = null;
    _favoriteStats = null;
    notifyListeners();
  }
}
