import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

class OfflineQueueItem {
  final String id;
  final String audioPath;
  final String? transcript;
  final String? summary;
  final NoteCategory category;
  final String language;
  final bool isFavorite;
  final DateTime createdAt;
  final int retries;
  final bool isProcessing;

  OfflineQueueItem({
    required this.id,
    required this.audioPath,
    this.transcript,
    this.summary,
    required this.category,
    required this.language,
    required this.isFavorite,
    required this.createdAt,
    this.retries = 0,
    this.isProcessing = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'audioPath': audioPath,
    'transcript': transcript,
    'summary': summary,
    'category': category.name,
    'language': language,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'retries': retries,
    'isProcessing': isProcessing,
  };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) =>
      OfflineQueueItem(
        id: json['id'] ?? '',
        audioPath: json['audioPath'] ?? '',
        transcript: json['transcript'],
        summary: json['summary'],
        category: NoteCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => NoteCategory.other,
        ),
        language: json['language'] ?? 'en',
        isFavorite: json['isFavorite'] ?? false,
        createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
        retries: json['retries'] ?? 0,
        isProcessing: json['isProcessing'] ?? false,
      );
}

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const String _queueKey = 'offline_queue_items';
  static const int _maxRetries = 3;

  Future<SharedPreferences> _getPrefs() => SharedPreferences.getInstance();

  /// Add item to offline queue
  Future<void> addToQueue(OfflineQueueItem item) async {
    final prefs = await _getPrefs();
    final queue = await getQueue();
    queue.add(item);

    final jsonList = queue.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_queueKey, jsonList);
  }

  /// Get all queued items
  Future<List<OfflineQueueItem>> getQueue() async {
    final prefs = await _getPrefs();
    final jsonList = prefs.getStringList(_queueKey) ?? [];

    return jsonList
        .map((json) => OfflineQueueItem.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Get pending items (not yet processed)
  Future<List<OfflineQueueItem>> getPendingItems() async {
    final queue = await getQueue();
    return queue
        .where((item) => item.transcript == null && item.retries < _maxRetries)
        .toList();
  }

  /// Update queue item
  Future<void> updateItem(OfflineQueueItem item) async {
    final prefs = await _getPrefs();
    var queue = await getQueue();

    final index = queue.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      queue[index] = item;
      final jsonList = queue.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_queueKey, jsonList);
    }
  }

  /// Mark item as processed and update with results
  Future<void> markAsProcessed(
    String itemId, {
    required String transcript,
    required String summary,
  }) async {
    final queue = await getQueue();
    final itemIndex = queue.indexWhere((i) => i.id == itemId);

    if (itemIndex >= 0) {
      var item = queue[itemIndex];
      item = OfflineQueueItem(
        id: item.id,
        audioPath: item.audioPath,
        transcript: transcript,
        summary: summary,
        category: item.category,
        language: item.language,
        isFavorite: item.isFavorite,
        createdAt: item.createdAt,
        retries: item.retries,
        isProcessing: false,
      );
      await updateItem(item);
    }
  }

  /// Increment retry count
  Future<void> incrementRetry(String itemId) async {
    final queue = await getQueue();
    final itemIndex = queue.indexWhere((i) => i.id == itemId);

    if (itemIndex >= 0) {
      var item = queue[itemIndex];
      item = OfflineQueueItem(
        id: item.id,
        audioPath: item.audioPath,
        transcript: item.transcript,
        summary: item.summary,
        category: item.category,
        language: item.language,
        isFavorite: item.isFavorite,
        createdAt: item.createdAt,
        retries: item.retries + 1,
        isProcessing: false,
      );
      await updateItem(item);
    }
  }

  /// Remove item from queue
  Future<void> removeFromQueue(String itemId) async {
    final prefs = await _getPrefs();
    var queue = await getQueue();
    queue.removeWhere((i) => i.id == itemId);

    final jsonList = queue.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_queueKey, jsonList);
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    final prefs = await _getPrefs();
    await prefs.remove(_queueKey);
  }

  /// Get queue count
  Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Get failed items (exceeded max retries)
  Future<List<OfflineQueueItem>> getFailedItems() async {
    final queue = await getQueue();
    return queue.where((item) => item.retries >= _maxRetries).toList();
  }
}
