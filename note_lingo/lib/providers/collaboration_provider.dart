// lib/providers/collaboration_provider.dart
// State management for collaboration features (sharing, commenting, groups)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/comment_model.dart';
import '../models/note_model.dart';
import '../services/collaboration_service.dart';

class CollaborationProvider extends ChangeNotifier {
  final CollaborationService _collaboration = CollaborationService();

  List<NoteModel> _sharedNotes = [];
  List<CommentModel> _comments = [];
  final List<String> _onlineUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NoteModel> get sharedNotes => _sharedNotes;
  List<CommentModel> get comments => _comments;
  List<String> get onlineUsers => _onlineUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;

  Future<void> shareNote(
    String noteId,
    String targetUserEmail,
    String accessLevel,
  ) async {
    try {
      _setLoading(true);
      await _collaboration.shareNote(noteId, targetUserEmail, accessLevel);
      await loadSharedNotes();
    } catch (e) {
      _setError('Failed to share note: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSharedNotes() async {
    try {
      _setLoading(true);
      _sharedNotes = await _collaboration.getSharedWithMe();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load shared notes: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> revokeAccess(String noteId, String userEmail) async {
    try {
      await _collaboration.revokeAccess(noteId, userEmail);
      notifyListeners();
    } catch (e) {
      _setError('Failed to revoke access: $e');
    }
  }

  Future<void> addComment(String noteId, String content) async {
    try {
      await _collaboration.addComment(noteId, content);
      await loadComments(noteId);
    } catch (e) {
      _setError('Failed to add comment: $e');
    }
  }

  Future<void> loadComments(String noteId) async {
    try {
      _comments = await _collaboration.getCommentsStream(noteId).first;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load comments: $e');
    }
  }

  Future<void> toggleCommentLike(String noteId, String commentId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      CommentModel? currentComment;
      for (final comment in _comments) {
        if (comment.id == commentId) {
          currentComment = comment;
          break;
        }
      }

      if (currentComment != null &&
          currentComment.likedBy.contains(currentUserId)) {
        await _collaboration.unlikeComment(noteId, commentId);
      } else {
        await _collaboration.likeComment(noteId, commentId);
      }

      await loadComments(noteId);
    } catch (e) {
      _setError('Failed to toggle like: $e');
    }
  }

  Future<void> deleteComment(String noteId, String commentId) async {
    try {
      await _collaboration.deleteComment(noteId, commentId);
      _comments.removeWhere((comment) => comment.id == commentId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete comment: $e');
    }
  }

  Future<void> likeComment(String noteId, String commentId) async {
    try {
      await _collaboration.likeComment(noteId, commentId);
      await loadComments(noteId);
    } catch (e) {
      _setError('Failed to like comment: $e');
    }
  }

  Stream<List<CommentModel>> watchComments(String noteId) {
    return _collaboration.getCommentsStream(noteId);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    debugPrint('[CollaborationProvider] Error: $message');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearComments() {
    _comments = [];
    notifyListeners();
  }
}
