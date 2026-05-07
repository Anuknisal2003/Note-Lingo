import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';

class DailyStats {
  final DateTime date;
  final int notesCreated;
  final int totalMinutesRecorded;
  final int wordsTranscribed;

  DailyStats({
    required this.date,
    required this.notesCreated,
    required this.totalMinutesRecorded,
    required this.wordsTranscribed,
  });

  Map<String, dynamic> toJson() => {
    'date': Timestamp.fromDate(date),
    'notesCreated': notesCreated,
    'totalMinutesRecorded': totalMinutesRecorded,
    'wordsTranscribed': wordsTranscribed,
  };

  factory DailyStats.fromJson(Map<String, dynamic> json) => DailyStats(
    date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    notesCreated: json['notesCreated'] ?? 0,
    totalMinutesRecorded: json['totalMinutesRecorded'] ?? 0,
    wordsTranscribed: json['wordsTranscribed'] ?? 0,
  );
}

class WordFrequency {
  final String word;
  final int count;
  final double frequency;

  WordFrequency({
    required this.word,
    required this.count,
    required this.frequency,
  });
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Record note creation event
  Future<void> recordNoteCreated(
    String noteId, {
    required int durationSeconds,
    required int wordCount,
    required NoteCategory category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _db
        .collection('analytics')
        .doc(user.uid)
        .collection('daily')
        .doc(dateKey)
        .set({
          'date': Timestamp.fromDate(today),
          'notesCreated': FieldValue.increment(1),
          'totalMinutesRecorded': FieldValue.increment(durationSeconds ~/ 60),
          'wordsTranscribed': FieldValue.increment(wordCount),
        }, SetOptions(merge: true));

    // Update user's total stats
    await _db.collection('users').doc(user.uid).update({
      'totalNotesCreated': FieldValue.increment(1),
      'totalMinutesRecorded': FieldValue.increment(durationSeconds ~/ 60),
      'totalWordsTranscribed': FieldValue.increment(wordCount),
      'lastNoteDate': Timestamp.now(),
    });
  }

  /// Get daily stats for date range
  Future<List<DailyStats>> getDailyStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _db
          .collection('analytics')
          .doc(user.uid)
          .collection('daily')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => DailyStats.fromJson(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get word frequency chart data
  Future<List<WordFrequency>> getWordFrequency(
    DateTime startDate,
    DateTime endDate, {
    int limit = 20,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final notesSnapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final wordCounts = <String, int>{};
      int totalWords = 0;

      for (final doc in notesSnapshot.docs) {
        final text = (doc['transcription'] ?? '').toString().toLowerCase();
        final words = text.split(RegExp(r'\W+'));

        for (final word in words) {
          if (word.length > 3 && !_isStopword(word)) {
            wordCounts[word] = (wordCounts[word] ?? 0) + 1;
            totalWords++;
          }
        }
      }

      // Convert to list and sort by frequency
      final frequencies = wordCounts.entries
          .map(
            (e) => WordFrequency(
              word: e.key,
              count: e.value,
              frequency: totalWords > 0 ? e.value / totalWords : 0,
            ),
          )
          .toList();

      frequencies.sort((a, b) => b.count.compareTo(a.count));
      return frequencies.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get recording heatmap data (busiest hours/days)
  Future<Map<String, int>> getRecordingHeatmap(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final notesSnapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final heatmap = <String, int>{};

      for (final doc in notesSnapshot.docs) {
        final timestamp = (doc['createdAt'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          // Group by day and hour
          final key =
              '${timestamp.weekday}-${timestamp.hour}'; // Day-Hour format
          heatmap[key] = (heatmap[key] ?? 0) + 1;
        }
      }

      return heatmap;
    } catch (_) {
      return {};
    }
  }

  /// Get progress statistics
  Future<Map<String, dynamic>> getProgressStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final totalNotes = userData['totalNotesCreated'] ?? 0;
      final totalMinutes = userData['totalMinutesRecorded'] ?? 0;
      final totalWords = userData['totalWordsTranscribed'] ?? 0;
      final lastNoteDate = (userData['lastNoteDate'] as Timestamp?)?.toDate();

      // Calculate streak
      int streak = 0;
      if (lastNoteDate != null) {
        final today = DateTime.now();
        final daysSinceLast = today.difference(lastNoteDate).inDays;
        if (daysSinceLast <= 1) {
          // Get actual streak from daily stats
          streak = await _calculateStreak();
        }
      }

      return {
        'totalNotes': totalNotes,
        'totalMinutes': totalMinutes,
        'totalWords': totalWords,
        'currentStreak': streak,
        'averageNotesPerDay': totalNotes > 0 ? totalNotes / 30 : 0,
        'averageWordsPerNote': totalNotes > 0 ? totalWords ~/ totalNotes : 0,
      };
    } catch (_) {
      return {};
    }
  }

  Future<int> _calculateStreak() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    int streak = 0;
    var checkDate = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final dateKey =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

      final doc = await _db
          .collection('analytics')
          .doc(user.uid)
          .collection('daily')
          .doc(dateKey)
          .get();

      if (doc.exists && (doc['notesCreated'] ?? 0) > 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Get category breakdown
  Future<Map<String, int>> getCategoryStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final notesSnapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .get();

      final categoryStats = <String, int>{};

      for (final doc in notesSnapshot.docs) {
        final category = doc['category'] ?? 'other';
        categoryStats[category] = (categoryStats[category] ?? 0) + 1;
      }

      return categoryStats;
    } catch (_) {
      return {};
    }
  }

  /// Track favorite vs regular notes
  Future<Map<String, dynamic>> getFavoriteStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final allNotes = await _db
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .get();

      final total = allNotes.size;
      final favorited = allNotes.docs
          .where((doc) => doc['isFavorite'] ?? false)
          .length;

      return {
        'total': total,
        'favorited': favorited,
        'percentage': total > 0
            ? (favorited / total * 100).toStringAsFixed(1)
            : '0',
      };
    } catch (_) {
      return {};
    }
  }

  /// Get WER (Word Error Rate) score if available
  Future<double> getWerScore() async {
    // This would require speech recognition confidence scores
    // For now, return a placeholder
    return 0.92; // 92% accuracy
  }

  bool _isStopword(String word) {
    const stopwords = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'was',
      'were',
      'be',
      'being',
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
      'may',
      'might',
      'can',
      'not',
      'and',
      'but',
      'or',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'this',
      'that',
      'from',
      'by',
      'it',
      'its',
    };
    return stopwords.contains(word);
  }
}
