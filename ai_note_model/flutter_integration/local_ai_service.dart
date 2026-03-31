// flutter_integration/local_ai_service.dart
//
// Connects your Flutter app to YOUR trained Wav2Vec2 model.
// Drop this file into: lib/services/local_ai_service.dart
//
// Usage in recording_provider.dart:
//   final result = await LocalAiService().transcribe(audioFile);

import 'dart:io';
import 'dart:convert';
// ignore: uri_does_not_exist
import 'package:http/http.dart' as http;

class LocalAiService {
  // ── Singleton ────────────────────────────────────────────────
  static final LocalAiService _instance = LocalAiService._internal();
  factory LocalAiService() => _instance;
  LocalAiService._internal();

  // ─────────────────────────────────────────────────────────────
  //  CONFIGURE THIS:
  //
  //  Option A — PC and phone on same WiFi (recommended for testing)
  //    Replace with your PC's local IP address
  //    Find it with: ipconfig (Windows) or ifconfig (Mac/Linux)
  //
  //  Option B — Using ngrok (test from anywhere)
  //    Run: ngrok http 5000
  //    Replace with the https://xxxx.ngrok-free.app URL
  //
  //  Option C — Android emulator (talking to PC localhost)
  //    Use: http://10.0.2.2:5000
  // ─────────────────────────────────────────────────────────────
  static const String _baseUrl = 'http://192.168.1.100:5000';
  //                                      ↑ change this to your PC IP

  static const Duration _timeout = Duration(seconds: 60);

  // ── Health check ─────────────────────────────────────────────
  Future<bool> isReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Transcribe audio file ─────────────────────────────────────
  Future<LocalTranscriptionResult> transcribe(File audioFile) async {
    // Check if server is running
    final reachable = await isReachable();
    if (!reachable) {
      throw LocalAiException(
        'Cannot connect to local AI server.\n'
        'Make sure your Python server is running:\n'
        '  python flask_api/app.py\n'
        'And update _baseUrl in local_ai_service.dart',
      );
    }

    final uri = Uri.parse('$_baseUrl/transcribe');

    // Build multipart request
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );

    // Send
    final streamed = await request.send().timeout(
      _timeout,
      onTimeout: () => throw LocalAiException(
        'Transcription timed out. Is the model still loading?',
      ),
    );

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LocalTranscriptionResult(
        text: data['text'] ?? '',
        duration: (data['duration'] as num?)?.toDouble() ?? 0.0,
        inferenceTime: (data['inference_time'] as num?)?.toDouble() ?? 0.0,
        wordCount: data['word_count'] as int? ?? 0,
      );
    } else {
      final body = jsonDecode(response.body);
      throw LocalAiException(
        'Transcription failed (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }
  }

  // ── Get model info ────────────────────────────────────────────
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/info'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}

// ── Result model ─────────────────────────────────────────────────

class LocalTranscriptionResult {
  final String text;
  final double duration;
  final double inferenceTime;
  final int wordCount;

  const LocalTranscriptionResult({
    required this.text,
    required this.duration,
    required this.inferenceTime,
    required this.wordCount,
  });

  @override
  String toString() =>
      'LocalTranscriptionResult(text: "$text", '
      'duration: ${duration}s, inference: ${inferenceTime}s)';
}

// ── Custom exception ──────────────────────────────────────────────

class LocalAiException implements Exception {
  final String message;
  const LocalAiException(this.message);

  @override
  String toString() => message;
}
