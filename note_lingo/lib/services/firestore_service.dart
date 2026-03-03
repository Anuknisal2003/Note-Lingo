// All Firestore database operations:
//  - User profile CRUD
//  - Notes CRUD
//  - Real-time streams

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  // ── Singleton ────────────────────────────────────────────────
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Shorthand refs ───────────────────────────────────────────
  CollectionReference get _users =>
      _db.collection(AppConstants.usersCollection);

  CollectionReference get _notes =>
      _db.collection(AppConstants.notesCollection);

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ════════════════════════════════════════════════════════════
  //  USER PROFILE
  // ════════════════════════════════════════════════════════════

  Future<void> createUserProfile(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<void> updateUserProfile(Map<String, dynamic> fields) async {
    await _users.doc(_uid).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> userProfileStream() {
    return _users
        .doc(_uid)
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
  }

  // ════════════════════════════════════════════════════════════
  //  NOTES — CRUD
  // ════════════════════════════════════════════════════════════

  /// Create a new note document
  Future<void> createNote(NoteModel note) async {
    await _notes.doc(note.id).set(note.toFirestore());
  }

  /// Update an existing note document
  Future<void> updateNote(NoteModel note) async {
    await _notes.doc(note.id).update({
      ...note.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a note by ID
  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String noteId, bool isFavorite) async {
    await _notes.doc(noteId).update({
      'isFavorite': isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ════════════════════════════════════════════════════════════
  //  NOTES — QUERIES
  // ════════════════════════════════════════════════════════════

  /// Fetch all notes for the current user (one-time)
  Future<List<NoteModel>> fetchNotes() async {
    final snap = await _notes
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => NoteModel.fromFirestore(d)).toList();
  }

  /// Real-time stream of current user's notes
  Stream<List<NoteModel>> notesStream() {
    return _notes
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => NoteModel.fromFirestore(d)).toList(),
        );
  }

  /// Fetch notes by category
  Future<List<NoteModel>> fetchNotesByCategory(NoteCategory cat) async {
    final snap = await _notes
        .where('userId', isEqualTo: _uid)
        .where('category', isEqualTo: cat.name)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => NoteModel.fromFirestore(d)).toList();
  }

  /// Fetch favourite notes
  Future<List<NoteModel>> fetchFavoriteNotes() async {
    final snap = await _notes
        .where('userId', isEqualTo: _uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => NoteModel.fromFirestore(d)).toList();
  }
}
