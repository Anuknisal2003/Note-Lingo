import 'package:flutter/foundation.dart';
import '../services/collaboration_service.dart';

class CollaborationProvider extends ChangeNotifier {
  final CollaborationService _service = CollaborationService();

  bool _isLoading = false;
  String? _error;

  // State
  List<Comment> _comments = [];
  List<SharedAccess> _sharedWith = [];
  List<StudyGroup> _userGroups = [];
  StudyGroup? _currentGroup;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Comment> get comments => _comments;
  List<SharedAccess> get sharedWith => _sharedWith;
  List<StudyGroup> get userGroups => _userGroups;
  StudyGroup? get currentGroup => _currentGroup;

  /// Load comments for note
  Future<void> loadComments(String noteId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _comments = await _service.getComments(noteId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load comments: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add comment
  Future<void> addComment(
    String noteId,
    String content, {
    int lineNumber = 0,
  }) async {
    try {
      _error = null;
      await _service.addComment(noteId, content, lineNumber: lineNumber);

      // Reload comments
      await loadComments(noteId);
    } catch (e) {
      _error = 'Failed to add comment: $e';
      notifyListeners();
    }
  }

  /// Toggle like on comment
  Future<void> toggleCommentLike(String noteId, String commentId) async {
    try {
      _error = null;
      await _service.toggleCommentLike(noteId, commentId);

      // Reload comments
      await loadComments(noteId);
    } catch (e) {
      _error = 'Failed to toggle like: $e';
      notifyListeners();
    }
  }

  /// Delete comment
  Future<void> deleteComment(String noteId, String commentId) async {
    try {
      _error = null;
      await _service.deleteComment(noteId, commentId);

      // Reload comments
      await loadComments(noteId);
    } catch (e) {
      _error = 'Failed to delete comment: $e';
      notifyListeners();
    }
  }

  /// Share note
  Future<void> shareNote(
    String noteId,
    List<String> emails, {
    String role = 'viewer',
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.shareNote(noteId, emails, role: role);

      // Load access list
      await loadNoteAccess(noteId);
    } catch (e) {
      _error = 'Failed to share note: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load note access
  Future<void> loadNoteAccess(String noteId) async {
    try {
      _error = null;
      _sharedWith = await _service.getNoteAccess(noteId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load access: $e';
      notifyListeners();
    }
  }

  /// Revoke access
  Future<void> revokeAccess(String noteId, String email) async {
    try {
      _error = null;
      await _service.revokeAccess(noteId, email);
      await loadNoteAccess(noteId);
    } catch (e) {
      _error = 'Failed to revoke access: $e';
      notifyListeners();
    }
  }

  /// Create study group
  Future<String?> createStudyGroup(
    String name,
    String description, {
    int memberLimit = 50,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final groupId = await _service.createStudyGroup(
        name,
        description,
        memberLimit: memberLimit,
      );

      // Reload groups
      await loadUserGroups();
      return groupId;
    } catch (e) {
      _error = 'Failed to create group: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user's study groups
  Future<void> loadUserGroups() async {
    try {
      _error = null;
      _userGroups = await _service.getUserStudyGroups();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load groups: $e';
      notifyListeners();
    }
  }

  /// Load specific study group
  Future<void> loadStudyGroup(String groupId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentGroup = await _service.getStudyGroup(groupId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load group: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Join study group
  Future<void> joinStudyGroup(String groupId) async {
    try {
      _error = null;
      await _service.joinStudyGroup(groupId);
      await loadUserGroups();
    } catch (e) {
      _error = 'Failed to join group: $e';
      notifyListeners();
    }
  }

  /// Leave study group
  Future<void> leaveStudyGroup(String groupId) async {
    try {
      _error = null;
      await _service.leaveStudyGroup(groupId);
      await loadUserGroups();
      if (_currentGroup?.id == groupId) {
        _currentGroup = null;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to leave group: $e';
      notifyListeners();
    }
  }

  /// Add note to group
  Future<void> addNoteToGroup(String groupId, String noteId) async {
    try {
      _error = null;
      await _service.addNoteToGroup(groupId, noteId);
      await loadStudyGroup(groupId);
    } catch (e) {
      _error = 'Failed to add note to group: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearComments() {
    _comments = [];
    notifyListeners();
  }
}
