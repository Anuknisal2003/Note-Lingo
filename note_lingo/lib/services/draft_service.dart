import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DraftItem {
  final String id;
  final String? audioPath;
  final String? transcript;
  final DateTime updatedAt;

  DraftItem({
    required this.id,
    this.audioPath,
    this.transcript,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'audioPath': audioPath,
    'transcript': transcript,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DraftItem.fromJson(Map<String, dynamic> j) => DraftItem(
    id: j['id'] ?? '',
    audioPath: j['audioPath'],
    transcript: j['transcript'],
    updatedAt: j['updatedAt'] != null
        ? DateTime.parse(j['updatedAt'])
        : DateTime.now(),
  );
}

class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  static const _fileName = 'drafts.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final s = await f.readAsString();
      if (s.trim().isEmpty) return {};
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(f.path);
  }

  Future<void> saveDraft(DraftItem item) async {
    final all = await _readAll();
    all[item.id] = item.toJson();
    await _writeAll(all);
  }

  Future<DraftItem?> getDraft(String id) async {
    final all = await _readAll();
    if (!all.containsKey(id)) return null;
    return DraftItem.fromJson(Map<String, dynamic>.from(all[id]));
  }

  Future<void> deleteDraft(String id) async {
    final all = await _readAll();
    all.remove(id);
    await _writeAll(all);
  }

  Future<List<DraftItem>> listDrafts() async {
    final all = await _readAll();
    return all.values
        .map((e) => DraftItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
