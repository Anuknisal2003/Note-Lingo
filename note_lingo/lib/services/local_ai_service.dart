// lib/services/local_ai_service.dart
// Connects Flutter app to your local Whisper + custom BART model
// Drop this file into: lib/services/local_ai_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  // Optional override: --dart-define=LOCAL_AI_BASE_URL=http://<ip>:5000
  static const String _configuredBaseUrl = String.fromEnvironment(
    'LOCAL_AI_BASE_URL',
    defaultValue: '',
  );

  static const Duration _timeout = Duration(seconds: 60);
  String? _activeBaseUrl;

  List<String> _candidateBaseUrls() {
    final urls = <String>[];

    if (_configuredBaseUrl.isNotEmpty) {
      urls.add(_configuredBaseUrl);
    }

    final envBaseUrl = dotenv.env['LOCAL_AI_BASE_URL']?.trim() ?? '';
    if (envBaseUrl.isNotEmpty) {
      urls.add(envBaseUrl);
    }

    // Android emulator routes host machine localhost through 10.0.2.2.
    if (Platform.isAndroid) {
      urls.add('http://10.0.2.2:5000');
    }

    urls.addAll([
      'http://127.0.0.1:5000',
      'http://localhost:5000',
      // Current machine LAN address from Flask startup logs.
      'http://172.20.10.4:5000',
    ]);

    return urls.toSet().toList();
  }

  Future<String> _resolveBaseUrl() async {
    if (_activeBaseUrl != null) return _activeBaseUrl!;

    for (final baseUrl in _candidateBaseUrls()) {
      try {
        final res = await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          _activeBaseUrl = baseUrl;
          return baseUrl;
        }
      } catch (_) {
        // Keep scanning candidates until one responds.
      }
    }

    throw Exception(
      'AI server not reachable. Set LOCAL_AI_BASE_URL in assets/.env or dart-define to your PC IP, e.g. http://192.168.x.x:5000',
    );
  }

  // ── Check if Flask server is running ───────────────────
  Future<bool> isServerAvailable() async {
    try {
      await _resolveBaseUrl();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Transcribe audio file ─────────────────────────────
  Future<String> transcribe(File audioFile) async {
    // Basic validation
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found: ${audioFile.path}');
    }
    final size = await audioFile.length();
    debugPrint(
      '[LocalAiService] transcribe: file=${audioFile.path} size=$size',
    );
    if (size < 1024) {
      throw Exception(
        'Audio file appears too small (${size} bytes), likely empty.',
      );
    }

    // Try local first
    try {
      final baseUrl = await _resolveBaseUrl();
      final uri = Uri.parse('$baseUrl/transcribe');
      final req = http.MultipartRequest('POST', uri);

      req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      final streamed = await req.send().timeout(_timeout);
      final body = await http.Response.fromStream(streamed);

      if (body.statusCode != 200) {
        final msg = _parseError(body.body);
        throw Exception('Transcription failed (${body.statusCode}): $msg');
      }

      final data = jsonDecode(body.body) as Map<String, dynamic>;
      final text = (data['text'] ?? '').toString().trim();
      debugPrint(
        '[LocalAiService] local response: status=${body.statusCode} text_len=${text.length}',
      );
      return text;
    } catch (e) {
      // If OpenAI API key is present, try Whisper API as a fallback
      final openai = dotenv.env['OPENAI_API_KEY']?.trim() ?? '';
      if (openai.isNotEmpty) {
        try {
          final uri = Uri.parse(
            'https://api.openai.com/v1/audio/transcriptions',
          );
          final req = http.MultipartRequest('POST', uri);
          req.headers['Authorization'] = 'Bearer $openai';
          req.files.add(
            await http.MultipartFile.fromPath('file', audioFile.path),
          );
          req.fields['model'] = 'whisper-1';

          final streamed = await req.send().timeout(_timeout);
          final body = await http.Response.fromStream(streamed);
          final data = jsonDecode(body.body) as Map<String, dynamic>;
          final text = (data['text'] ?? '').toString().trim();
          debugPrint(
            '[LocalAiService] OpenAI response: status=${body.statusCode} text_len=${text.length}',
          );
          if (body.statusCode == 200) {
            return text;
          } else {
            final msg = _parseError(body.body);
            throw Exception(
              'OpenAI transcription failed (${body.statusCode}): $msg',
            );
          }
        } catch (oe) {
          throw Exception(
            'Transcription failed (local and OpenAI fallback): $oe',
          );
        }
      }

      // No OpenAI key — surface helpful error
      throw Exception(
        'Local AI transcription failed. Ensure Flask server is running on your PC:\n'
        '  python -m flask_api.app\n\n'
        'Or set OPENAI_API_KEY in assets/.env to enable OpenAI fallback. Error: $e',
      );
    }
  }

  // ── Get structured summary from custom BART model ─────
  Future<SummaryResult> summarise(
    String text, {
    String category = 'general',
  }) async {
    try {
      final baseUrl =
          dotenv.env['LOCAL_AI_BASE_URL'] ?? 'http://localhost:5000';
      final uri = Uri.parse('$baseUrl/summarise');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'category': category}),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        final msg = _parseError(res.body);
        throw Exception('Summarisation failed (${res.statusCode}): $msg');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return SummaryResult.fromJson(data);
    } catch (e) {
      throw Exception('Summarization failed: $e');
    }
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
