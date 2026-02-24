// lib/services/ai_service.dart
//
// Handles all AI operations:
//  1. Speech-to-text  → OpenAI Whisper API
//  2. Summarization   → OpenAI GPT-4o
//  3. Keyword extract → OpenAI GPT-4o
//  4. Title generate  → OpenAI GPT-4o

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class AiService {
  // ── Singleton ────────────────────────────────────────────────
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (key.isEmpty || key == 'sk-your-openai-key-here') {
      throw AiException(
        'OpenAI API key not set. Add it to assets/.env file.\n'
        'Get your key at: https://platform.openai.com/api-keys',
      );
    }
    return key;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
  };

  // ── 1. TRANSCRIPTION (Whisper) ───────────────────────────────
  Future<String> transcribe(File audioFile, {String language = 'en'}) async {
    final uri = Uri.parse('${AppConstants.openAiBaseUrl}/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['model'] = AppConstants.whisperModel
      ..fields['response_format'] = 'text';

    // Map language code
    final langCode = AppConstants.whisperLanguageCodes[language];
    if (langCode != null) {
      request.fields['language'] = langCode;
    }

    // Attach audio file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        // Whisper supports: mp3, mp4, mpeg, mpga, m4a, wav, webm
      ),
    );

    final streamed = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw AiException(
        'Transcription timed out. Try a shorter recording.',
      ),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final text = response.body.trim();
      if (text.isEmpty) throw AiException('No speech detected in recording.');
      return text;
    } else {
      final body = jsonDecode(response.body);
      throw AiException(
        'Transcription failed (${response.statusCode}): '
        '${body['error']?['message'] ?? response.body}',
      );
    }
  }

  // ── 2. SUMMARIZATION (GPT-4o) ────────────────────────────────
  Future<String> summarize(String transcript, {String language = 'en'}) async {
    final langName = AppConstants.languageNames[language] ?? 'English';

    final prompt =
        '''You are an expert note-taking assistant for students, professionals, and researchers.

Analyze the following transcript and create a well-structured, concise summary.
Respond entirely in $langName.

TRANSCRIPT:
$transcript

Provide your response in this exact format:

OVERVIEW:
[2-3 sentence overview of the main topic]

KEY POINTS:
• [Key point 1]
• [Key point 2]
• [Key point 3]
• [Add more as needed]

ACTION ITEMS (if any):
• [Action item or conclusion]

Keep the total summary under 250 words. Be specific and informative.''';

    return await _chat(prompt, maxTokens: AppConstants.summaryMaxTokens);
  }

  // ── 3. KEYWORD EXTRACTION (GPT-4o) ──────────────────────────
  Future<List<String>> extractKeywords(String transcript) async {
    final prompt =
        '''Extract exactly 5-8 important keywords or key phrases from this text.
Return ONLY a valid JSON array of strings, nothing else. No explanation, no markdown.
Example: ["machine learning","data analysis","neural networks"]

Text: ${transcript.substring(0, transcript.length.clamp(0, 1500))}''';

    final raw = await _chat(prompt, maxTokens: AppConstants.keywordMaxTokens);

    try {
      // Clean any accidental markdown fences
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final List<dynamic> list = jsonDecode(cleaned);
      return list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(AppConstants.maxKeywords)
          .toList();
    } catch (_) {
      // Fallback: parse comma-separated
      return raw
          .replaceAll(RegExp(r'[\[\]"]'), '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(AppConstants.maxKeywords)
          .toList();
    }
  }

  // ── 4. TITLE GENERATION (GPT-4o) ────────────────────────────
  Future<String> generateTitle(String transcript) async {
    final snippet = transcript.substring(0, transcript.length.clamp(0, 600));

    final prompt =
        '''Generate a short, descriptive title (4-7 words) for a note based on this transcript.
Return ONLY the title text. No quotes, no punctuation at end, nothing else.

Transcript excerpt: $snippet''';

    final title = await _chat(prompt, maxTokens: AppConstants.titleMaxTokens);
    return title.replaceAll('"', '').replaceAll("'", '').trim();
  }

  // ── Internal: Chat completion ────────────────────────────────
  Future<String> _chat(String prompt, {int maxTokens = 500}) async {
    final uri = Uri.parse('${AppConstants.openAiBaseUrl}/chat/completions');

    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'model': AppConstants.gptModel,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': maxTokens,
            'temperature': 0.3,
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw AiException(
            'AI request timed out. Check your internet connection.',
          ),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) {
        throw AiException('Empty response from AI.');
      }
      return content.trim();
    } else {
      final body = jsonDecode(response.body);
      final msg = body['error']?['message'] ?? response.body;
      if (response.statusCode == 401) {
        throw AiException('Invalid OpenAI API key. Check your .env file.');
      }
      if (response.statusCode == 429) {
        throw AiException(
          'OpenAI rate limit reached. Wait a moment and try again.',
        );
      }
      if (response.statusCode == 402) {
        throw AiException(
          'OpenAI credit exhausted. Add credits at platform.openai.com.',
        );
      }
      throw AiException('AI failed (${response.statusCode}): $msg');
    }
  }
}

// ── Custom Exception ─────────────────────────────────────────────
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}
