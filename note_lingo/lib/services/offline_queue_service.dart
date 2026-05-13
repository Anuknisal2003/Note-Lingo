import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import 'retry_backoff_service.dart';

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
  final DateTime? lastRetryTime;
  final String denoiseMethod;
  final double denoiseStrength;

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
    this.lastRetryTime,
    this.denoiseMethod = 'auto',
    this.denoiseStrength = 1.0,
  });

  /// Check if this item is ready to retry based on backoff policy.
  bool isReadyToRetry() {
    return RetryBackoffService.isReadyToRetry(retries, lastRetryTime);
  }

  /// Get remaining backoff delay in seconds.
  int getRetryDelaySeconds() {
    return RetryBackoffService.getBackoffDelay(retries, lastRetryTime);
  }

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
    'lastRetryTime': lastRetryTime?.toIso8601String(),
    'denoiseMethod': denoiseMethod,
    'denoiseStrength': denoiseStrength,
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
        lastRetryTime: json['lastRetryTime'] != null
            ? DateTime.parse(json['lastRetryTime'])
            : null,
        denoiseMethod: json['denoiseMethod'] ?? 'auto',
        denoiseStrength: (json['denoiseStrength'] ?? 1.0).toDouble(),
      );
}

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const int _maxRetries = 3;

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_queue.json');
  }

  /// Add item to offline queue
  Future<void> addToQueue(OfflineQueueItem item) async {
    final file = await _queueFile();
    final queue = await getQueue();
    queue.add(item);
    final jsonList = queue.map((i) => i.toJson()).toList();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(jsonList));
    await tmp.rename(file.path);
  }

  /// Get all queued items
  Future<List<OfflineQueueItem>> getQueue() async {
    try {
      final file = await _queueFile();
      if (!await file.exists()) return [];
      final s = await file.readAsString();
      if (s.trim().isEmpty) return [];
      final jsonList = jsonDecode(s) as List;
      return jsonList
          .map((j) => OfflineQueueItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get pending items (not yet processed and ready to retry)
  Future<List<OfflineQueueItem>> getPendingItems() async {
    final queue = await getQueue();
    return queue
        .where(
          (item) =>
              item.transcript == null &&
              item.retries < _maxRetries &&
              item.isReadyToRetry(),
        )
        .toList();
  }

  /// Get items not ready yet (backoff in effect)
  Future<List<OfflineQueueItem>> getBackoffItems() async {
    final queue = await getQueue();
    return queue
        .where(
          (item) =>
              item.transcript == null &&
              item.retries < _maxRetries &&
              !item.isReadyToRetry(),
        )
        .toList();
  }

  /// Batch sync: process multiple items and update all atomically.
  /// Returns map of item IDs to success (true) or failure (false).
  Future<Map<String, bool>> batchProcessItems(
    List<OfflineQueueItem> items,
    Future<(String transcript, String summary)> Function(OfflineQueueItem)
    processItem,
  ) async {
    final results = <String, bool>{};
    // final _queue = await getQueue();

    for (final item in items) {
      try {
        await processItem(item);
        await removeFromQueue(item.id);
        results[item.id] = true;
      } catch (e) {
        // Mark as failed; update lastRetryTime for backoff
        var updated = OfflineQueueItem(
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
          lastRetryTime: DateTime.now(),
        );
        await updateItem(updated);
        results[item.id] = false;
      }
    }

    return results;
  }

  /// Update _queue item
  Future<void> updateItem(OfflineQueueItem item) async {
    final file = await _queueFile();
    var queue = await getQueue();
    final index = queue.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      queue[index] = item;
      final jsonList = queue.map((i) => i.toJson()).toList();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(jsonList));
      await tmp.rename(file.path);
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

  /// Increment retry count (called when retry fails; updates lastRetryTime).
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
        lastRetryTime: DateTime.now(),
      );
      await updateItem(item);
    }
  }

  /// Remove item from queue
  Future<void> removeFromQueue(String itemId) async {
    final file = await _queueFile();
    var queue = await getQueue();
    queue.removeWhere((i) => i.id == itemId);
    final jsonList = queue.map((i) => i.toJson()).toList();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(jsonList));
    await tmp.rename(file.path);
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    try {
      final file = await _queueFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Get queue count — only items that still have sync attempts remaining
  Future<int> getQueueCount() async {
    final queue = await getQueue();
    return queue.where((item) => item.transcript == null).length;
  }

  /// Reset a failed item so it can be retried again
  Future<void> resetRetries(String itemId) async {
    final queue = await getQueue();
    final index = queue.indexWhere((i) => i.id == itemId);
    if (index >= 0) {
      final item = queue[index];
      await updateItem(
        OfflineQueueItem(
          id: item.id,
          audioPath: item.audioPath,
          transcript: item.transcript,
          summary: item.summary,
          category: item.category,
          language: item.language,
          isFavorite: item.isFavorite,
          createdAt: item.createdAt,
          retries: 0,
          isProcessing: false,
          lastRetryTime: null,
          denoiseMethod: item.denoiseMethod,
          denoiseStrength: item.denoiseStrength,
        ),
      );
    }
  }

  /// Get failed items (exceeded max retries)
  Future<List<OfflineQueueItem>> getFailedItems() async {
    final queue = await getQueue();
    return queue.where((item) => item.retries >= _maxRetries).toList();
  }
}
