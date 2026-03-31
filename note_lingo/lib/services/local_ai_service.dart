// lib/services/local_ai_service.dart
// Connects Flutter app to your local Whisper + custom BART model
// Drop this file into: lib/services/local_ai_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SummaryResult {
  final String title;
  final String categoryHeading;
  final String overview;
  final List<String> keyPoints;
  final String pointsLabel;
  final List<String> keywords;
  final String conclusion;
  final String rawSummary;
  final String method;

  const SummaryResult({
    required this.title,
    required this.categoryHeading,
    required this.overview,
    required this.keyPoints,
    required this.pointsLabel,
    required this.keywords,
    required this.conclusion,
    required this.rawSummary,
    required this.method,
  });

  factory SummaryResult.fromJson(Map<String, dynamic> json) {
    return SummaryResult(
      title: json['title'] ?? '',
      categoryHeading: json['category_heading'] ?? '📄 Note Summary',
      overview: json['overview'] ?? '',
      keyPoints: List<String>.from(json['key_points'] ?? []),
      pointsLabel: json['points_label'] ?? 'Key Points',
      keywords: List<String>.from(json['keywords'] ?? []),
      conclusion: json['conclusion'] ?? '',
      rawSummary: json['raw_summary'] ?? '',
      method: json['method'] ?? 'unknown',
    );
  }

  /// Build markdown string for display in note detail screen
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln(categoryHeading);
    buf.writeln();
    buf.writeln('## 📖 Overview');
    buf.writeln(overview);
    buf.writeln();
    if (keyPoints.isNotEmpty) {
      buf.writeln('## 🔑 $pointsLabel');
      for (final pt in keyPoints) {
        buf.writeln('• $pt');
      }
      buf.writeln();
    }
    if (keywords.isNotEmpty) {
      buf.writeln('## 🏷️ Topic Keywords');
      buf.writeln(keywords.map((k) => '[$k]').join('  '));
      buf.writeln();
    }
    buf.writeln('## 💡 Conclusion');
    buf.writeln(conclusion);
    return buf.toString().trim();
  }
}

class LocalAiService {
  // ── Change this to your PC's local IP address ──
  // Find it with: ipconfig (Windows) or ifconfig (Mac/Linux)
  // Look for IPv4 Address under Wi-Fi — e.g. 192.168.1.15
  static const String _baseUrl = 'http://192.168.1.15:5000';

  static const Duration _timeout = Duration(seconds: 60);

  // ── Check if Flask server is running ───────────────────
  Future<bool> isServerAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Transcribe audio file ─────────────────────────────
  Future<String> transcribe(File audioFile) async {
    final uri = Uri.parse('$_baseUrl/transcribe');
    final req = http.MultipartRequest('POST', uri);

    req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final streamed = await req.send().timeout(_timeout);
    final body = await http.Response.fromStream(streamed);

    if (body.statusCode != 200) {
      final msg = _parseError(body.body);
      throw Exception('Transcription failed (${body.statusCode}): $msg');
    }

    final data = jsonDecode(body.body) as Map<String, dynamic>;
    return (data['text'] ?? '').toString().trim();
  }

  // ── Get structured summary from custom BART model ─────
  Future<SummaryResult> summarise(
    String text, {
    String category = 'general',
  }) async {
    final uri = Uri.parse('$_baseUrl/summarise');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'category': category}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      final msg = _parseError(res.body);
      throw Exception('Summarisation failed (${res.statusCode}): $msg');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return SummaryResult.fromJson(data);
  }

  String _parseError(String body) {
    try {
      final d = jsonDecode(body);
      return d['error']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
