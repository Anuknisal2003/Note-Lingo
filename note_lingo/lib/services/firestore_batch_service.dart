// lib/services/firestore_batch_service.dart
// Batch writes and transactional operations for Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

/// Service for managing Firestore batch writes and transactions.
class FirestoreBatchService {
  static final FirestoreBatchService _instance =
      FirestoreBatchService._internal();
  factory FirestoreBatchService() => _instance;
  FirestoreBatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Batch write: save multiple notes atomically.
  /// Returns list of document IDs created.
  Future<List<String>> saveBatch(List<NoteModel> notes) async {
    if (notes.isEmpty) return [];

    final batch = _firestore.batch();
    final ids = <String>[];

    for (final note in notes) {
      final docRef = _firestore.collection('notes').doc();
      batch.set(docRef, note.toFirestore());
      ids.add(docRef.id);
    }

    await batch.commit();
    debugPrint(
      '[FirestoreBatchService] Batch saved ${notes.length} notes: $ids',
    );
    return ids;
  }

  /// Batch update: update multiple notes atomically.
  Future<void> updateBatch(Map<String, Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return;

    final batch = _firestore.batch();

    updates.forEach((docId, data) {
      final docRef = _firestore.collection('notes').doc(docId);
      batch.update(docRef, data);
    });

    await batch.commit();
    debugPrint('[FirestoreBatchService] Batch updated ${updates.length} notes');
  }

  /// Batch delete: remove multiple notes atomically.
  Future<void> deleteBatch(List<String> noteIds) async {
    if (noteIds.isEmpty) return;

    final batch = _firestore.batch();

    for (final id in noteIds) {
      final docRef = _firestore.collection('notes').doc(id);
      batch.delete(docRef);
    }

    await batch.commit();
    debugPrint('[FirestoreBatchService] Batch deleted ${noteIds.length} notes');
  }

  /// Transactional read-modify-write: atomically update a note with computed value.
  /// Example: increment view count, update favorite status.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) updateFn) async {
    try {
      final result = await _firestore.runTransaction(updateFn);
      debugPrint('[FirestoreBatchService] Transaction completed');
      return result;
    } catch (e) {
      debugPrint('[FirestoreBatchService] Transaction failed: $e');
      rethrow;
    }
  }

  /// Transactional note update with conflict detection.
  /// Fails if the note's updatedAt doesn't match (optimistic locking).
  Future<void> updateNoteWithConflictDetection(
    String noteId,
    NoteModel newNote,
    DateTime expectedUpdatedAt,
  ) async {
    await transaction((txn) async {
      final docRef = _firestore.collection('notes').doc(noteId);
      final snapshot = await txn.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Note $noteId not found');
      }

      final currentNote = NoteModel.fromFirestore(snapshot);
      if (currentNote.updatedAt != expectedUpdatedAt) {
        throw Exception(
          'Conflict: note was modified by another user. '
          'Expected updatedAt=$expectedUpdatedAt, '
          'got ${currentNote.updatedAt}',
        );
      }

      txn.update(docRef, newNote.toFirestore());
    });

    debugPrint(
      '[FirestoreBatchService] Updated $noteId with conflict detection',
    );
  }

  /// Batch save with parent-child relationship (e.g., notes with shared access).
  /// Atomically creates note + adds sharedWith records.
  Future<String> saveBatchWithSharedAccess(
    NoteModel note,
    List<String> sharedWithUserIds,
  ) async {
    String noteId = '';

    await transaction((txn) async {
      final noteRef = _firestore.collection('notes').doc();
      noteId = noteRef.id;

      // Save note
      txn.set(noteRef, note.toFirestore());

      // Save shared access records (sub-collection)
      for (final userId in sharedWithUserIds) {
        final sharedRef = noteRef.collection('sharedWith').doc(userId);
        txn.set(sharedRef, {
          'userId': userId,
          'sharedAt': FieldValue.serverTimestamp(),
          'accessLevel': 'view',
        });
      }
    });

    debugPrint(
      '[FirestoreBatchService] Saved note $noteId with '
      '${sharedWithUserIds.length} shared users',
    );
    return noteId;
  }

  /// Atomic increment counters (e.g., view count, likes).
  Future<void> incrementCounters(
    String noteId,
    Map<String, int> counters,
  ) async {
    final updates = <String, dynamic>{};

    for (final entry in counters.entries) {
      updates[entry.key] = FieldValue.increment(entry.value);
    }

    await _firestore.collection('notes').doc(noteId).update(updates);
    debugPrint(
      '[FirestoreBatchService] Incremented counters on $noteId: $counters',
    );
  }

  /// Bulk fetch with transactional consistency.
  /// Reads multiple documents in a single transaction.
  Future<List<NoteModel>> fetchBatch(List<String> noteIds) async {
    final notes = <NoteModel>[];

    await transaction((txn) async {
      for (final id in noteIds) {
        final docRef = _firestore.collection('notes').doc(id);
        final snapshot = await txn.get(docRef);
        if (snapshot.exists) {
          notes.add(NoteModel.fromFirestore(snapshot));
        }
      }
    });

    debugPrint(
      '[FirestoreBatchService] Fetched ${notes.length}/${noteIds.length} notes',
    );
    return notes;
  }
}
