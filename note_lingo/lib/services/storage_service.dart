import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAudio(File file, {required String path}) async {
    final ref = _storage.ref(path);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/m4a'),
    );

    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> deleteAudio(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Ignore if already deleted
    }
  }
}
