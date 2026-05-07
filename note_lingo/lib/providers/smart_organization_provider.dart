import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/smart_organization_service.dart';
import '../models/note_model.dart';

class SmartOrganizationProvider extends ChangeNotifier {
  final SmartOrganizationService _service = SmartOrganizationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<SmartTag> _suggestedTags = [];
  List<RelatedNote> _relatedNotes = [];
  List<String> _suggestedFolders = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SmartTag> get suggestedTags => _suggestedTags;
  List<RelatedNote> get relatedNotes => _relatedNotes;
  List<String> get suggestedFolders => _suggestedFolders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Auto-tag note and get suggestions
  Future<void> tagNote(
    String text,
    String noteId,
    NoteCategory category,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get AI-suggested tags
      _suggestedTags = await _service.autoTag(text);

      // Get folder suggestions
      final user = _auth.currentUser;
      if (user != null) {
        _suggestedFolders = await _service.suggestFolders(
          user.uid,
          _suggestedTags,
        );

        // Find related notes
        _relatedNotes = await _service.findRelatedNotes(noteId, user.uid, text);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Tagging failed: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a smart folder
  Future<void> createSmartFolder(String name, List<String> tags) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _service.createSmartFolder(user.uid, name, tags);

      // Refresh suggestions
      _suggestedFolders = await _service.suggestFolders(
        user.uid,
        _suggestedTags,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create folder: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get notes with specific tag
  Future<List<NoteModel>> getNotesByTag(String tag) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      return await _service.getNotesByTag(user.uid, tag);
    } catch (e) {
      _error = 'Failed to fetch notes: $e';
      notifyListeners();
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSuggestions() {
    _suggestedTags = [];
    _relatedNotes = [];
    _suggestedFolders = [];
    notifyListeners();
  }
}
