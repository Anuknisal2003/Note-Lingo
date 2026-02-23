import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static const String _whisperUrl =
      'https://api.openai.com/v1/audio/transcriptions';
  static const String _chatUrl = 'https://api.openai.com/v1/chat/completions';

  // Load from .env file — see setup instructions below
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  // ── 1. TRANSCRIPTION (Whisper) ──────────────────
  Future<String> transcribe(File audioFile, {String language = 'en'}) async {
    final request = http.MultipartRequest('POST', Uri.parse(_whisperUrl));
    request.headers['Authorization'] = 'Bearer $_apiKey';

    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );
    request.fields['model'] = 'whisper-1';

    // Map language codes for Whisper
    final whisperLang = _mapLanguage(language);
    if (whisperLang != null) {
      request.fields['language'] = whisperLang;
    }
    request.fields['response_format'] = 'text';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return response.body.trim();
    } else {
      throw 'Transcription failed: ${response.body}';
    }
  }

  // ── 2. SUMMARIZATION (GPT) ──────────────────────
  Future<String> summarize(String text, {String language = 'en'}) async {
    final langName = _languageName(language);
    final prompt =
        '''
You are an expert note-taking assistant. Analyze the following transcript and create a concise, 
well-structured summary. Use clear bullet points for key points. Respond in $langName.

Transcript:
$text

Provide:
- A brief overview (2-3 sentences)
- Key points (bullet list)
- Action items if any

Keep it professional and under 200 words.
''';

    return await _chatCompletion(prompt);
  }

  // ── 3. KEYWORD EXTRACTION ───────────────────────
  Future<List<String>> extractKeywords(String text) async {
    final prompt =
        '''
Extract 5-8 key topics/keywords from this text. Return ONLY a JSON array of strings.
Example: ["machine learning", "neural networks", "training data"]

Text: $text
''';

    final response = await _chatCompletion(prompt);
    try {
      // Clean the response and parse JSON
      final cleaned = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final List<dynamic> keywords = jsonDecode(cleaned);
      return keywords.map((k) => k.toString()).take(8).toList();
    } catch (e) {
      // Fallback: split by commas if JSON fails
      return response
          .replaceAll(RegExp(r'[\[\]"]'), '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(8)
          .toList();
    }
  }

  // ── 4. TITLE GENERATION ─────────────────────────
  Future<String> generateTitle(String text) async {
    final prompt =
        '''
Generate a short, descriptive title (5-8 words) for this transcript. 
Return ONLY the title, nothing else.

Transcript (first 500 chars): ${text.substring(0, text.length.clamp(0, 500))}
''';

    final title = await _chatCompletion(prompt);
    return title.replaceAll('"', '').trim();
  }

  // ── INTERNAL: Chat completion ───────────────────
  Future<String> _chatCompletion(String prompt) async {
    final response = await http.post(
      Uri.parse(_chatUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o', // Use gpt-4o as gpt-5 is accessed same way
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 500,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw 'AI request failed: ${response.body}';
    }
  }

  String? _mapLanguage(String code) {
    switch (code) {
      case 'si':
        return 'si'; // Sinhala
      case 'ta':
        return 'ta'; // Tamil
      case 'en':
        return 'en';
      default:
        return null;
    }
  }

  String _languageName(String code) {
    switch (code) {
      case 'si':
        return 'Sinhala';
      case 'ta':
        return 'Tamil';
      default:
        return 'English';
    }
  }
}
