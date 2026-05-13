// lib/services/tag_query_service.dart
// Tag-based queries and advanced filtering

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

/// Service for tag-based queries and advanced filtering.
class TagQueryService {
  static final TagQueryService _instance = TagQueryService._internal();
  factory TagQueryService() => _instance;
  TagQueryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Tag Management ─────────────────────────────────────────

  /// Get all unique tags used by current user.
  Future<Set<String>> getUserTags() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .get();

      final tags = <String>{};
      for (final doc in snapshot.docs) {
        final note = NoteModel.fromFirestore(doc);
        tags.addAll(note.tags);
      }

      debugPrint('[TagQueryService] Found ${tags.length} unique tags');
      return tags;
    } catch (e) {
      debugPrint('[TagQueryService] Get user tags error: $e');
      return {};
    }
  }

  /// Add a tag to a note.
  Future<void> addTag(String noteId, String tag) async {
    try {
      final ref = _firestore.collection('notes').doc(noteId);

      await ref.update({
        'tags': FieldValue.arrayUnion([tag]),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('[TagQueryService] Added tag "$tag" to note $noteId');
    } catch (e) {
      debugPrint('[TagQueryService] Add tag error: $e');
      rethrow;
    }
  }

  /// Remove a tag from a note.
  Future<void> removeTag(String noteId, String tag) async {
    try {
      final ref = _firestore.collection('notes').doc(noteId);

      await ref.update({
        'tags': FieldValue.arrayRemove([tag]),
        'updatedAt': Timestamp.now(),
      });

      debugPrint('[TagQueryService] Removed tag "$tag" from note $noteId');
    } catch (e) {
      debugPrint('[TagQueryService] Remove tag error: $e');
      rethrow;
    }
  }

  /// Replace all tags on a note.
  Future<void> setTags(String noteId, List<String> newTags) async {
    try {
      final ref = _firestore.collection('notes').doc(noteId);

      await ref.update({'tags': newTags, 'updatedAt': Timestamp.now()});

      debugPrint('[TagQueryService] Set tags on note $noteId to $newTags');
    } catch (e) {
      debugPrint('[TagQueryService] Set tags error: $e');
      rethrow;
    }
  }

  // ── Queries ────────────────────────────────────────────────

  /// Get all notes with a specific tag.
  Future<List<NoteModel>> getNotesByTag(String tag) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .where('tags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
      debugPrint(
        '[TagQueryService] Found ${notes.length} notes with tag "$tag"',
      );
      return notes;
    } catch (e) {
      debugPrint('[TagQueryService] Get notes by tag error: $e');
      return [];
    }
  }

  /// Get notes with any of the given tags (OR query).
  Future<List<NoteModel>> getNotesByTagsAny(List<String> tags) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      if (tags.isEmpty) return [];

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .where('tags', arrayContainsAny: tags)
          .orderBy('createdAt', descending: true)
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
      debugPrint(
        '[TagQueryService] Found ${notes.length} notes with any tag from $tags',
      );
      return notes;
    } catch (e) {
      debugPrint('[TagQueryService] Get notes by any tag error: $e');
      return [];
    }
  }

  /// Get notes with ALL of the given tags (AND query - client-side filter).
  Future<List<NoteModel>> getNotesByTagsAll(List<String> tags) async {
    try {
      if (tags.isEmpty) return [];

      // Use arrayContainsAny and filter client-side
      final notesList = await getNotesByTagsAny(tags);

      final result = notesList.where((note) {
        return tags.every((tag) => note.tags.contains(tag));
      }).toList();

      debugPrint(
        '[TagQueryService] Found ${result.length} notes with all tags from $tags',
      );
      return result;
    } catch (e) {
      debugPrint('[TagQueryService] Get notes by all tags error: $e');
      return [];
    }
  }

  /// Get notes with a tag and category (compound query).
  Future<List<NoteModel>> getNotesByTagAndCategory(
    String tag,
    String category,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .where('tags', arrayContains: tag)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
      debugPrint(
        '[TagQueryService] Found ${notes.length} notes with tag "$tag" and '
        'category "$category"',
      );
      return notes;
    } catch (e) {
      debugPrint('[TagQueryService] Get notes by tag and category error: $e');
      return [];
    }
  }

  /// Get notes within a date range and with specific tags (compound query).
  Future<List<NoteModel>> getNotesByTagsAndDateRange(
    List<String> tags,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      if (tags.isEmpty) return [];

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .where('tags', arrayContainsAny: tags)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
      debugPrint(
        '[TagQueryService] Found ${notes.length} notes with tags $tags '
        'between ${startDate.toIso8601String()} and ${endDate.toIso8601String()}',
      );
      return notes;
    } catch (e) {
      debugPrint(
        '[TagQueryService] Get notes by tags and date range error: $e',
      );
      return [];
    }
  }

  /// Get tag frequency (count of notes per tag).
  Future<Map<String, int>> getTagFrequency() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid)
          .get();

      final frequency = <String, int>{};
      for (final doc in snapshot.docs) {
        final note = NoteModel.fromFirestore(doc);
        for (final tag in note.tags) {
          frequency[tag] = (frequency[tag] ?? 0) + 1;
        }
      }

      debugPrint(
        '[TagQueryService] Computed frequency for ${frequency.length} tags',
      );
      return frequency;
    } catch (e) {
      debugPrint('[TagQueryService] Get tag frequency error: $e');
      return {};
    }
  }

  /// Get notes by priority (favorite, recent, high engagement).
  Future<List<NoteModel>> getNotesByPriority({
    String sortBy = 'recent', // 'recent', 'favorite', 'engagement'
    int limit = 20,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      var query = _firestore
          .collection('notes')
          .where('userId', isEqualTo: uid);

      if (sortBy == 'favorite') {
        query = query.where('isFavorite', isEqualTo: true);
      }

      final snapshot = await query
          .orderBy(
            sortBy == 'recent' ? 'createdAt' : 'commentCount',
            descending: true,
          )
          .limit(limit)
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();
      debugPrint('[TagQueryService] Fetched $limit notes sorted by $sortBy');
      return notes;
    } catch (e) {
      debugPrint('[TagQueryService] Get notes by priority error: $e');
      return [];
    }
  }

  // ── Real-time Streams ──────────────────────────────────────

  /// Stream of notes with a specific tag (real-time updates).
  Stream<List<NoteModel>> getNotesByTagStream(String tag) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList(),
        );
  }

  /// Stream of all user's notes (real-time updates).
  Stream<List<NoteModel>> getAllNotesStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList(),
        );
  }
}
