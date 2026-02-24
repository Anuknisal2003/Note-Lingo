// lib/providers/notes_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/export_service.dart';

class NotesProvider extends ChangeNotifier {
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();
  final ExportService _export = ExportService();

  // ── State ────────────────────────────────────────────────────
  List<NoteModel> _notes = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<NoteModel>>? _sub;

  List<NoteModel> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Computed stats ───────────────────────────────────────────
  int get favoriteCount => _notes.where((n) => n.isFavorite).length;

  int get totalMinutes =>
      (_notes.fold<int>(0, (s, n) => s + n.duration) / 60).round();

  // ── Search + filter ──────────────────────────────────────────
  List<NoteModel> filteredNotes(String query) {
    if (query.trim().isEmpty) return _notes;
    final q = query.toLowerCase().trim();
    return _notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.summary.toLowerCase().contains(q) ||
              n.transcription.toLowerCase().contains(q) ||
              n.keywords.any((k) => k.toLowerCase().contains(q)),
        )
        .toList();
  }

  // ════════════════════════════════════════════════════════════
  //  LOAD — Real-time Firestore stream
  // ════════════════════════════════════════════════════════════

  Future<void> loadNotes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First, do a one-time fetch for instant display
      _notes = await _db.fetchNotes();
      _isLoading = false;
      notifyListeners();

      // Then subscribe to real-time updates
      _sub?.cancel();
      _sub = _db.notesStream().listen(
        (list) {
          _notes = list;
          notifyListeners();
        },
        onError: (e) {
          _error = 'Sync error: ${e.toString()}';
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Stop listening ───────────────────────────────────────────
  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  // ════════════════════════════════════════════════════════════
  //  ADD NOTE
  // ════════════════════════════════════════════════════════════

  Future<void> addNote(NoteModel note) async {
    // Optimistic: insert at top immediately
    _notes.insert(0, note);
    notifyListeners();

    try {
      await _db.createNote(note);
    } catch (e) {
      // Rollback on failure
      _notes.removeWhere((n) => n.id == note.id);
      _error = 'Failed to save note: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  UPDATE NOTE
  // ════════════════════════════════════════════════════════════

  Future<void> updateNote(NoteModel updated) async {
    final idx = _notes.indexWhere((n) => n.id == updated.id);
    final old = idx != -1 ? _notes[idx] : null;

    // Optimistic update
    if (idx != -1) {
      _notes[idx] = updated;
      notifyListeners();
    }

    try {
      await _db.updateNote(updated);
    } catch (e) {
      // Rollback
      if (idx != -1 && old != null) {
        _notes[idx] = old;
        notifyListeners();
      }
      _error = 'Failed to update note: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  TOGGLE FAVORITE
  // ════════════════════════════════════════════════════════════

  Future<void> toggleFavorite(String noteId) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;

    final note = _notes[idx];
    final toggled = note.copyWith(isFavorite: !note.isFavorite);

    _notes[idx] = toggled;
    notifyListeners();

    try {
      await _db.toggleFavorite(noteId, toggled.isFavorite);
    } catch (e) {
      _notes[idx] = note;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  DELETE NOTE
  // ════════════════════════════════════════════════════════════

  Future<void> deleteNote(String noteId) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    final note = idx != -1 ? _notes[idx] : null;

    // Optimistic remove
    _notes.removeWhere((n) => n.id == noteId);
    notifyListeners();

    try {
      await _db.deleteNote(noteId);

      // Also delete audio from Storage if present
      if (note?.audioUrl != null) {
        await _storage.deleteAudio(note!.audioUrl!).catchError((_) {});
      }
    } catch (e) {
      // Rollback
      if (note != null && idx != -1) {
        _notes.insert(idx, note);
        notifyListeners();
      }
      _error = 'Failed to delete note: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  EXPORT NOTE
  // ════════════════════════════════════════════════════════════

  Future<void> exportNote(
    NoteModel note, {
    required String format,
    required bool includeSummary,
    required bool includeTranscript,
    required bool includeKeywords,
    required bool includeMeta,
  }) async {
    await _export.export(
      note,
      format: format,
      includeSummary: includeSummary,
      includeTranscript: includeTranscript,
      includeKeywords: includeKeywords,
      includeMeta: includeMeta,
    );
  }

  // ── Clear error ──────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Clear all (on sign-out) ──────────────────────────────────
  void clear() {
    stopListening();
    _notes = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
