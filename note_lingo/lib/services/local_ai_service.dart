// lib/services/local_ai_service.dart
// Connects Flutter app to your local Whisper + custom BART model
// Drop this file into: lib/services/local_ai_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranscriptionResult {
  final String text;
  final String language;

  const TranscriptionResult({required this.text, required this.language});

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: (json['text'] ?? '').toString().trim(),
      language: (json['language'] ?? 'en').toString().trim().toLowerCase(),
    );
  }
}

class SummaryResult {
  // ── Core summary fields ───────────────────────────────
  final String title;
  final String categoryHeading;
  final String overview;
  final List<String> keyPoints;
  final String pointsLabel;
  final List<String> keywords;
  final String conclusion;
  final String rawSummary;
  final String method;

  // ── Multi-language pipeline fields ───────────────────
  final String originalTranscript;
  final String englishTranscript;
  final String detectedLanguage;
  final bool isTranslated;
  final String? translatedOverview;
  final List<String>? translatedKeyPoints;
  final String? translatedConclusion;
  final String? translatedSummary;
  final double processingTime;

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
    this.originalTranscript = '',
    this.englishTranscript = '',
    this.detectedLanguage = 'en',
    this.isTranslated = false,
    this.translatedOverview,
    this.translatedKeyPoints,
    this.translatedConclusion,
    this.translatedSummary,
    this.processingTime = 0,
  });

  factory SummaryResult.fromJson(Map<String, dynamic> json) {
    List<String>? tKeyPoints;
    final rawTKP = json['translated_key_points'];
    if (rawTKP is List) {
      tKeyPoints = rawTKP
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return SummaryResult(
      title: json['title']?.toString() ?? '',
      categoryHeading:
          json['category_heading']?.toString() ?? '📄 Note Summary',
      overview: json['overview']?.toString() ?? '',
      keyPoints: List<String>.from(json['key_points'] ?? []),
      pointsLabel: json['points_label']?.toString() ?? 'Key Points',
      keywords: List<String>.from(json['keywords'] ?? []),
      conclusion: json['conclusion']?.toString() ?? '',
      rawSummary: json['raw_summary']?.toString() ?? '',
      method: json['method']?.toString() ?? 'unknown',
      originalTranscript: json['original_transcript']?.toString() ?? '',
      englishTranscript: json['english_transcript']?.toString() ?? '',
      detectedLanguage: json['detected_language']?.toString() ?? 'en',
      isTranslated: json['is_translated'] == true,
      translatedOverview: json['translated_overview']?.toString(),
      translatedKeyPoints: tKeyPoints,
      translatedConclusion: json['translated_conclusion']?.toString(),
      translatedSummary: json['translated_summary']?.toString(),
      processingTime: (json['processing_time'] as num?)?.toDouble() ?? 0,
    );
  }

  // ── Display getters (prefer translated when available) ─
  /// Overview in the original detected language (falls back to English).
  String get displayOverview => (translatedOverview?.isNotEmpty ?? false)
      ? translatedOverview!
      : overview;

  /// Key points in the original detected language (falls back to English).
  List<String> get displayKeyPoints =>
      (translatedKeyPoints?.isNotEmpty ?? false)
      ? translatedKeyPoints!
      : keyPoints;

  /// Conclusion in the original detected language (falls back to English).
  String get displayConclusion => (translatedConclusion?.isNotEmpty ?? false)
      ? translatedConclusion!
      : conclusion;

  /// Build markdown for display — uses translated fields when available.
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln(categoryHeading);
    buf.writeln();
    buf.writeln('## 📖 Overview');
    buf.writeln(displayOverview);
    buf.writeln();
    if (displayKeyPoints.isNotEmpty) {
      buf.writeln('## 🔑 $pointsLabel');
      for (final pt in displayKeyPoints) {
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
    buf.writeln(displayConclusion);
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
  // Full pipeline (transcribe + translate + summarise) can take 2-4 min on CPU
  static const Duration _pipelineTimeout = Duration(minutes: 5);
  String? _activeBaseUrl;

  String? _normalizeLanguageHint(String? value) {
    if (value == null) return null;
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty || raw == 'auto' || raw == 'detect') return null;

    const aliases = {
      'english': 'en',
      'en-us': 'en',
      'en-gb': 'en',
      'sinhala': 'si',
      'sinhalese': 'si',
      'tamil': 'ta',
    };
    final mapped = aliases[raw] ?? raw;
    final isIso2 = RegExp(r'^[a-z]{2}$').hasMatch(mapped);
    return isIso2 ? mapped : null;
  }

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
      // Prefer explicit config via --dart-define or assets/.env instead
      // of embedding a single hardcoded LAN IP here.
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

  /// Public helper: try to return a reachable base URL or null if none.
  Future<String?> getBaseUrlOrNull() async {
    try {
      return await _resolveBaseUrl();
    } catch (_) {
      return null;
    }
  }

  // ── Check if Flask server is running ───────────────────
  /// Always does a fresh health check — clears any cached URL first
  /// so that a reconnected network gets a real re-probe of all candidates.
  Future<bool> isServerAvailable() async {
    _activeBaseUrl = null; // invalidate stale cached URL
    try {
      await _resolveBaseUrl();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Transcribe audio file ─────────────────────────────
  Future<TranscriptionResult> transcribe(
    File audioFile, {
    bool enableDenoise = true,
    String denoiseMethod = 'auto',
    double denoiseStrength = 1.0,
    String? languageHint,
  }) async {
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found: ${audioFile.path}');
    }
    final size = await audioFile.length();
    debugPrint(
      '[LocalAiService] transcribe: file=${audioFile.path} size=$size denoise=$enableDenoise method=$denoiseMethod',
    );
    if (size < 1024) {
      throw Exception(
        'Audio file appears too small ($size bytes), likely empty.',
      );
    }

    final normalizedLanguageHint = _normalizeLanguageHint(languageHint);

    // Try local first
    try {
      final baseUrl = await _resolveBaseUrl();
      final uri = Uri.parse('$baseUrl/transcribe');
      final req = http.MultipartRequest('POST', uri);

      req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      // Add denoise parameters
      req.fields['denoise'] = enableDenoise ? denoiseMethod : '0';
      if (enableDenoise && denoiseStrength != 1.0) {
        req.fields['denoise_strength'] = denoiseStrength.toString();
      }
      if (normalizedLanguageHint != null) {
        req.fields['language'] = normalizedLanguageHint;
      }

      final streamed = await req.send().timeout(_timeout);
      final body = await http.Response.fromStream(streamed);

      if (body.statusCode != 200) {
        final msg = _parseError(body.body);
        throw Exception('Transcription failed (${body.statusCode}): $msg');
      }

      final data = jsonDecode(body.body) as Map<String, dynamic>;
      final transcription = TranscriptionResult.fromJson(data);
      debugPrint(
        '[LocalAiService] local response: status=${body.statusCode} text_len=${transcription.text.length} lang=${transcription.language}',
      );
      return transcription;
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
          if (normalizedLanguageHint != null) {
            req.fields['language'] = normalizedLanguageHint;
          }

          final streamed = await req.send().timeout(_timeout);
          final body = await http.Response.fromStream(streamed);
          final data = jsonDecode(body.body) as Map<String, dynamic>;
          final text = (data['text'] ?? '').toString().trim();
          final language = (data['language'] ?? 'en')
              .toString()
              .trim()
              .toLowerCase();
          debugPrint(
            '[LocalAiService] OpenAI response: status=${body.statusCode} text_len=${text.length}',
          );
          if (body.statusCode == 200) {
            return TranscriptionResult(text: text, language: language);
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

  // ── Full pipeline: audio → transcript → translate → summarise → translate back ──
  Future<SummaryResult> processAudio(
    File audioFile, {
    String category = 'general',
    bool enableDenoise = true,
    String denoiseMethod = 'auto',
    double denoiseStrength = 1.0,
  }) async {
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found: ${audioFile.path}');
    }
    final size = await audioFile.length();
    debugPrint(
      '[LocalAiService] processAudio: file=${audioFile.path} size=$size',
    );
    if (size < 1024) {
      throw Exception(
        'Audio file appears too small ($size bytes), likely empty.',
      );
    }

    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/process');
    final req = http.MultipartRequest('POST', uri);

    req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    req.fields['category'] = category;
    req.fields['denoise'] = enableDenoise ? denoiseMethod : '0';
    if (enableDenoise && denoiseStrength != 1.0) {
      req.fields['denoise_strength'] = denoiseStrength.toString();
    }

    final streamed = await req.send().timeout(_pipelineTimeout);
    final body = await http.Response.fromStream(streamed);

    if (body.statusCode != 200) {
      final msg = _parseError(body.body);
      throw Exception('Process pipeline failed (${body.statusCode}): $msg');
    }

    final data = jsonDecode(body.body) as Map<String, dynamic>;
    debugPrint(
      '[LocalAiService] /process response: lang=${data['detected_language']} '
      'translated=${data['is_translated']} time=${data['processing_time']}s',
    );
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
