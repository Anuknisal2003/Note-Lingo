// lib/providers/notes_provider.dart
// STUB — Full implementation comes in the backend phase

import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

class NotesProvider extends ChangeNotifier {
  List<NoteModel> _notes = [];
  bool _isLoading = false;

  List<NoteModel> get notes => _notes;
  bool get isLoading => _isLoading;
  int get favoriteCount => _notes.where((n) => n.isFavorite).length;
  int get totalMinutes =>
      (_notes.fold(0, (s, n) => s + n.duration) / 60).round();

  List<NoteModel> filteredNotes(String query) {
    if (query.isEmpty) return _notes;
    final q = query.toLowerCase();
    return _notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.summary.toLowerCase().contains(q) ||
              n.keywords.any((k) => k.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> loadNotes() async {
    // Full Firestore implementation in backend phase
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNote(NoteModel note) async {
    _notes.insert(0, note);
    notifyListeners();
  }

  Future<void> updateNote(NoteModel updated) async {
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i != -1) {
      _notes[i] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> exportNote(
    NoteModel note, {
    required String format,
    required bool includeSummary,
    required bool includeTranscript,
    required bool includeKeywords,
    required bool includeMeta,
  }) async {
    // Full export implementation in backend phase
    await Future.delayed(const Duration(seconds: 1));
  }
}
