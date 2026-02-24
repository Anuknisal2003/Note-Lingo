// lib/services/storage_service.dart
//
// Firebase Storage operations:
//  - Upload audio recordings
//  - Delete audio files
//  - Get download URLs

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';

class StorageService {
  // ── Singleton ────────────────────────────────────────────────
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── Upload Audio ─────────────────────────────────────────────
  /// Uploads a local audio file to Firebase Storage.
  /// Returns the public download URL.
  Future<String> uploadAudio(
    File audioFile, {
    required String noteId,
    void Function(double progress)? onProgress,
  }) async {
    final ext = audioFile.path.split('.').last;
    final path = '${AppConstants.audioStoragePath}/$_uid/$noteId.$ext';

    final ref = _storage.ref(path);

    final metadata = SettableMetadata(
      contentType: _contentType(ext),
      customMetadata: {
        'userId': _uid,
        'noteId': noteId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final task = ref.putFile(audioFile, metadata);

    // Progress callback
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // ── Delete Audio ─────────────────────────────────────────────
  /// Deletes a file given its download URL.
  Future<void> deleteAudio(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // Ignore if already deleted or not found
    }
  }

  // ── Get Download URL ─────────────────────────────────────────
  Future<String> getDownloadUrl(String storagePath) async {
    final ref = _storage.ref(storagePath);
    return await ref.getDownloadURL();
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'm4a':
        return 'audio/m4a';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/octet-stream';
    }
  }
}
