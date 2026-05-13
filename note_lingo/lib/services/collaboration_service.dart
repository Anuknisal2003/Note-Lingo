// lib/services/collaboration_service.dart
// Real-time collaboration: sharing notes, commenting, and access management

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../models/comment_model.dart';

/// Service for managing note sharing, comments, and real-time collaboration.
class CollaborationService {
  static final CollaborationService _instance =
      CollaborationService._internal();
  factory CollaborationService() => _instance;
  CollaborationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Sharing ────────────────────────────────────────────────

  /// Share a note with another user.
  /// accessLevel: 'view' (read-only), 'comment' (read + comment), 'edit' (full access)
  Future<void> shareNote(
    String noteId,
    String targetUserEmail,
    String accessLevel,
  ) async {
    try {
      final noteRef = _firestore.collection('notes').doc(noteId);

      await noteRef.update({
        'sharedWith': FieldValue.arrayUnion([
          {
            'userEmail': targetUserEmail,
            'accessLevel': accessLevel,
            'sharedAt': Timestamp.now(),
          },
        ]),
      });

      debugPrint(
        '[CollaborationService] Shared note $noteId with $targetUserEmail',
      );
    } catch (e) {
      debugPrint('[CollaborationService] Share error: $e');
      rethrow;
    }
  }

  /// Revoke access to a shared note.
  Future<void> revokeAccess(String noteId, String userEmail) async {
    try {
      final noteRef = _firestore.collection('notes').doc(noteId);

      await noteRef.update({
        'sharedWith': FieldValue.arrayRemove([
          {'userEmail': userEmail},
        ]),
      });

      debugPrint(
        '[CollaborationService] Revoked access for $userEmail on $noteId',
      );
    } catch (e) {
      debugPrint('[CollaborationService] Revoke error: $e');
      rethrow;
    }
  }

  /// Update access level for a shared user.
  Future<void> updateAccessLevel(
    String noteId,
    String userEmail,
    String newAccessLevel,
  ) async {
    try {
      final noteRef = _firestore.collection('notes').doc(noteId);
      final doc = await noteRef.get();
      final note = NoteModel.fromFirestore(doc);

      final updated = note.sharedWith.map((entry) {
        if (entry['userEmail'] == userEmail) {
          return {...entry, 'accessLevel': newAccessLevel};
        }
        return entry;
      }).toList();

      await noteRef.update({'sharedWith': updated});

      debugPrint(
        '[CollaborationService] Updated $userEmail access to $newAccessLevel',
      );
    } catch (e) {
      debugPrint('[CollaborationService] Update access error: $e');
      rethrow;
    }
  }

  /// Fetch all notes shared with current user.
  Future<List<NoteModel>> getSharedWithMe() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final snapshot = await _firestore
          .collection('notes')
          .where('sharedWith', arrayContains: {'userEmail': uid})
          .get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .toList();

      debugPrint('[CollaborationService] Fetched ${notes.length} shared notes');
      return notes;
    } catch (e) {
      debugPrint('[CollaborationService] Get shared error: $e');
      return [];
    }
  }

  // ── Comments (Real-time) ───────────────────────────────────

  /// Add a comment to a note.
  Future<String> addComment(
    String noteId,
    String content, {
    String? parentCommentId,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      final email = _auth.currentUser?.email;
      final displayName = _auth.currentUser?.displayName ?? 'Anonymous';

      if (uid == null || email == null) {
        throw StateError('User not authenticated');
      }

      final commentRef = await _firestore
          .collection('notes')
          .doc(noteId)
          .collection('comments')
          .add({
            'noteId': noteId,
            'userId': uid,
            'userName': displayName,
            'userEmail': email,
            'content': content,
            'createdAt': Timestamp.now(),
            'updatedAt': null,
            'likes': 0,
            'likedBy': [],
            'parentCommentId': parentCommentId,
            'replyIds': [],
          });

      if (parentCommentId != null) {
        await _firestore
            .collection('notes')
            .doc(noteId)
            .collection('comments')
            .doc(parentCommentId)
            .update({
              'replyIds': FieldValue.arrayUnion([commentRef.id]),
            });
      }

      await _firestore.collection('notes').doc(noteId).update({
        'commentCount': FieldValue.increment(1),
      });

      debugPrint(
        '[CollaborationService] Added comment ${commentRef.id} to $noteId',
      );
      return commentRef.id;
    } catch (e) {
      debugPrint('[CollaborationService] Add comment error: $e');
      rethrow;
    }
  }

  /// Edit a comment (owner only).
  Future<void> editComment(
    String noteId,
    String commentId,
    String newContent,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;

      final commentRef = _firestore
          .collection('notes')
          .doc(noteId)
          .collection('comments')
          .doc(commentId);
      final doc = await commentRef.get();
      // FIX: was `final CommentModel = CommentModel.fromFirestore(doc)`
      // — used the type name as the variable name, causing a compile error.
      final comment = CommentModel.fromFirestore(doc);

      if (comment.userId != uid) {
        throw StateError('Not authorized to edit this comment');
      }

      await commentRef.update({
        'content': newContent,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('[CollaborationService] Edited comment $commentId');
    } catch (e) {
      debugPrint('[CollaborationService] Edit comment error: $e');
      rethrow;
    }
  }

  /// Delete a comment (owner or note author).
  Future<void> deleteComment(String noteId, String commentId) async {
    try {
      final uid = _auth.currentUser?.uid;
      final noteRef = _firestore.collection('notes').doc(noteId);
      final commentRef = noteRef.collection('comments').doc(commentId);

      final doc = await commentRef.get();
      // FIX: same issue as editComment — variable name shadowed the type name.
      final comment = CommentModel.fromFirestore(doc);

      final noteDoc = await noteRef.get();
      final note = NoteModel.fromFirestore(noteDoc);

      if (comment.userId != uid && note.userId != uid) {
        throw StateError('Not authorized to delete this comment');
      }

      if (comment.parentCommentId != null) {
        await noteRef
            .collection('comments')
            .doc(comment.parentCommentId)
            .update({
              'replyIds': FieldValue.arrayRemove([commentId]),
            });
      }

      await commentRef.delete();

      await noteRef.update({'commentCount': FieldValue.increment(-1)});

      debugPrint('[CollaborationService] Deleted comment $commentId');
    } catch (e) {
      debugPrint('[CollaborationService] Delete comment error: $e');
      rethrow;
    }
  }

  /// Real-time stream of comments for a note.
  Stream<List<CommentModel>> getCommentsStream(String noteId) {
    return _firestore
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Like a comment.
  Future<void> likeComment(String noteId, String commentId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final commentRef = _firestore
          .collection('notes')
          .doc(noteId)
          .collection('comments')
          .doc(commentId);

      await commentRef.update({
        'likedBy': FieldValue.arrayUnion([uid]),
        'likes': FieldValue.increment(1),
      });

      debugPrint('[CollaborationService] Liked comment $commentId');
    } catch (e) {
      debugPrint('[CollaborationService] Like comment error: $e');
      rethrow;
    }
  }

  /// Unlike a comment.
  Future<void> unlikeComment(String noteId, String commentId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('User not authenticated');

      final commentRef = _firestore
          .collection('notes')
          .doc(noteId)
          .collection('comments')
          .doc(commentId);

      await commentRef.update({
        'likedBy': FieldValue.arrayRemove([uid]),
        'likes': FieldValue.increment(-1),
      });

      debugPrint('[CollaborationService] Unliked comment $commentId');
    } catch (e) {
      debugPrint('[CollaborationService] Unlike comment error: $e');
      rethrow;
    }
  }

}

// ── Supporting models ──────────────────────────────────────

class SharedAccess {
  final String userId;
  final String email;
  final String displayName;
  final String role; // 'viewer', 'editor', 'owner'
  final DateTime grantedAt;

  SharedAccess({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.grantedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': role,
    'grantedAt': Timestamp.fromDate(grantedAt),
  };

  factory SharedAccess.fromJson(Map<String, dynamic> json) => SharedAccess(
    userId: json['userId'] ?? '',
    email: json['email'] ?? '',
    displayName: json['displayName'] ?? '',
    role: json['role'] ?? 'viewer',
    grantedAt: (json['grantedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
