import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'local_ai_service.dart';

/// AI enhancement results
class AiEnhancement {
  final String sentiment; // positive, negative, neutral
  final double sentimentScore; // 0-1
  final List<String> speakers; // Speaker names/labels
  final List<QaItem> qaItems; // Extracted Q&A
  final List<String> entities; // Named entities (persons, locations, orgs)
  final Map<String, int> entityCounts; // Entity frequency

  AiEnhancement({
    required this.sentiment,
    required this.sentimentScore,
    required this.speakers,
    required this.qaItems,
    required this.entities,
    required this.entityCounts,
  });

  factory AiEnhancement.empty() => AiEnhancement(
    sentiment: 'neutral',
    sentimentScore: 0.5,
    speakers: [],
    qaItems: [],
    entities: [],
    entityCounts: {},
  );

  Map<String, dynamic> toJson() => {
    'sentiment': sentiment,
    'sentimentScore': sentimentScore,
    'speakers': speakers,
    'qaItems': qaItems.map((q) => q.toJson()).toList(),
    'entities': entities,
    'entityCounts': entityCounts,
  };

  factory AiEnhancement.fromJson(Map<String, dynamic> json) => AiEnhancement(
    sentiment: json['sentiment'] ?? 'neutral',
    sentimentScore: (json['sentimentScore'] ?? 0.5).toDouble(),
    speakers: List<String>.from(json['speakers'] ?? []),
    qaItems:
        (json['qaItems'] as List?)?.map((q) => QaItem.fromJson(q)).toList() ??
        [],
    entities: List<String>.from(json['entities'] ?? []),
    entityCounts: Map<String, int>.from(json['entityCounts'] ?? {}),
  );
}

class QaItem {
  final String question;
  final String answer;

  QaItem({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory QaItem.fromJson(Map<String, dynamic> json) =>
      QaItem(question: json['question'] ?? '', answer: json['answer'] ?? '');
}

class EnhancedAiService {
  static final EnhancedAiService _instance = EnhancedAiService._internal();
  factory EnhancedAiService() => _instance;
  EnhancedAiService._internal();

  final LocalAiService _local = LocalAiService();

  String? _openaiApiKey;

  String get _apiKey {
    _openaiApiKey ??= dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_openaiApiKey?.isEmpty ?? true) {
      // Return empty string instead of throwing to allow fallback
      return '';
    }
    return _openaiApiKey!;
  }

  /// Extract sentiment from text using local NLP or OpenAI fallback
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    try {
      // Try local server first if available
      final base = await _local.getBaseUrlOrNull();
      if (base != null) {
        try {
          final uri = Uri.parse('$base/detect_sentiment');
          final res = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'text': text}),
              )
              .timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            final d = jsonDecode(res.body) as Map<String, dynamic>;
            return {
              'sentiment': d['sentiment'] ?? 'neutral',
              'score': (d['score'] ?? 0.5),
            };
          }
        } catch (_) {}
      }

      // Try OpenAI if configured
      if (_apiKey.isNotEmpty) {
        return await _analyzeWithOpenAi(text);
      }

      // Fallback to local simple analysis
      return _analyzeWithLocal(text);
    } catch (e) {
      return _analyzeWithLocal(text);
    }
  }

  Future<Map<String, dynamic>> _analyzeWithOpenAi(String text) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': [
              {
                'role': 'system',
                'content':
                    'Analyze sentiment in one word: positive, negative, or neutral. Also provide a score from 0-1.',
              },
              {
                'role': 'user',
                'content': text.substring(
                  0,
                  text.length > 2000 ? 2000 : text.length,
                ),
              },
            ],
            'temperature': 0.3,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? 'neutral';

      // Parse sentiment from response
      final lowerContent = content.toLowerCase();
      String sentiment = 'neutral';
      if (lowerContent.contains('positive')) {
        sentiment = 'positive';
      } else if (lowerContent.contains('negative')) {
        sentiment = 'negative';
      }

      return {
        'sentiment': sentiment,
        'score': lowerContent.contains('0.')
            ? double.tryParse(lowerContent.split('0.')[1].split(' ')[0]) ?? 0.5
            : 0.5,
      };
    }
    throw Exception('OpenAI sentiment analysis failed');
  }

  Map<String, dynamic> _analyzeWithLocal(String text) {
    // Simple local sentiment analysis based on keywords
    const positiveWords = {
      'good',
      'great',
      'excellent',
      'amazing',
      'wonderful',
      'fantastic',
      'awesome',
      'love',
      'perfect',
      'beautiful',
      'brilliant',
      'outstanding',
      'happy',
      'enjoy',
      'best',
      'successful',
      'glad',
      'pleased',
    };
    const negativeWords = {
      'bad',
      'terrible',
      'awful',
      'horrible',
      'poor',
      'worst',
      'hate',
      'fail',
      'problem',
      'issue',
      'sad',
      'angry',
      'disappointed',
      'wrong',
      'broken',
      'stuck',
      'error',
    };

    final lowerText = text.toLowerCase();
    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in positiveWords) {
      positiveCount += RegExp(
        r'\b' + word + r'\b',
      ).allMatches(lowerText).length;
    }
    for (final word in negativeWords) {
      negativeCount += RegExp(
        r'\b' + word + r'\b',
      ).allMatches(lowerText).length;
    }

    final total = positiveCount + negativeCount;
    final score = total > 0 ? positiveCount / total : 0.5;
    final sentiment = score > 0.6
        ? 'positive'
        : score < 0.4
        ? 'negative'
        : 'neutral';

    return {'sentiment': sentiment, 'score': score};
  }

  /// Extract Q&A pairs from text
  Future<List<QaItem>> extractQA(String text) async {
    try {
      // Try local server first
      final base = await _local.getBaseUrlOrNull();
      if (base != null) {
        try {
          final uri = Uri.parse('$base/extract_qa');
          final res = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'text': text}),
              )
              .timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            final d = jsonDecode(res.body) as Map<String, dynamic>;
            final list = (d['qa'] as List?) ?? [];
            return list
                .map((e) => QaItem.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        } catch (_) {}
      }

      // Try OpenAI
      if (_apiKey.isNotEmpty) {
        final qaItems = await _extractQaWithOpenAi(text);
        if (qaItems.isNotEmpty) return qaItems;
      }

      final localItems = _extractQaWithLocal(text);
      return localItems.isNotEmpty ? localItems : _extractQaFallback(text);
    } catch (e) {
      final localItems = _extractQaWithLocal(text);
      return localItems.isNotEmpty ? localItems : _extractQaFallback(text);
    }
  }

  Future<List<QaItem>> _extractQaWithOpenAi(String text) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': [
              {
                'role': 'system',
                'content':
                    'Extract Q&A pairs from the text. Return as JSON array: [{"question":"...", "answer":"..."}]',
              },
              {
                'role': 'user',
                'content': text.substring(
                  0,
                  text.length > 2000 ? 2000 : text.length,
                ),
              },
            ],
            'temperature': 0.3,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '[]';
      try {
        final qaList = jsonDecode(content) as List;
        return qaList.map((q) => QaItem.fromJson(q)).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  List<QaItem> _extractQaWithLocal(String text) {
    // Local Q&A extraction: Find sentences with question patterns
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final qaItems = <QaItem>[];

    for (int i = 0; i < sentences.length - 1; i++) {
      final sentence = sentences[i].trim();
      if ((sentence.endsWith('?') ||
              sentence.toLowerCase().startsWith('what ') ||
              sentence.toLowerCase().startsWith('why ') ||
              sentence.toLowerCase().startsWith('how ')) &&
          sentence.length > 10) {
        final question = sentence;
        final answer = i + 1 < sentences.length ? sentences[i + 1].trim() : '';
        if (answer.length > 10) {
          qaItems.add(QaItem(question: question, answer: answer));
        }
      }
    }
    return qaItems.take(5).toList();
  }

  List<QaItem> _extractQaFallback(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 12)
        .toList();

    if (sentences.isEmpty) {
      return [];
    }

    final question = 'What is the main topic?';
    final answer = sentences.first;
    final items = <QaItem>[QaItem(question: question, answer: answer)];

    if (sentences.length > 1) {
      items.add(
        QaItem(question: 'What is one key point?', answer: sentences[1]),
      );
    }

    if (sentences.length > 2) {
      items.add(
        QaItem(question: 'What is the conclusion?', answer: sentences.last),
      );
    }

    return items;
  }

  /// Detect speaker transitions/labels in transcript
  Future<List<String>> detectSpeakers(String text) async {
    // Try local server diarization first
    try {
      final base = await _local.getBaseUrlOrNull();
      if (base != null) {
        final uri = Uri.parse('$base/speaker_diarization');
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': text}),
            )
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final d = jsonDecode(res.body) as Map<String, dynamic>;
          final sp = (d['speakers'] as List?) ?? [];
          return sp.map((s) => s.toString()).toList();
        }
      }
    } catch (_) {}

    // Fallback local detection
    final speakers = <String>{};
    final patterns = [
      RegExp(r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*:', multiLine: true),
      RegExp(r'Speaker\s+(\d+|[A-Z][a-z]+)', multiLine: true),
    ];
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        speakers.add(match.group(1) ?? match.group(0) ?? 'Unknown');
      }
    }

    // Simple fallback segmentation
    if (speakers.isEmpty) {
      final parts = text
          .split('\n')
          .where((p) => p.trim().length > 20)
          .take(4)
          .toList();
      return List.generate(parts.length, (i) => 'Speaker ${i + 1}');
    }
    return speakers.toList().take(10).toList();
  }

  /// Extract named entities from text
  Future<Map<String, dynamic>> extractEntities(String text) async {
    try {
      // Try local server first
      final base = await _local.getBaseUrlOrNull();
      if (base != null) {
        try {
          final uri = Uri.parse('$base/related_notes');
          final res = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'text': text}),
              )
              .timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            final d = jsonDecode(res.body) as Map<String, dynamic>;
            return d;
          }
        } catch (_) {}
      }

      if (_apiKey.isNotEmpty) {
        return await _extractWithOpenAi(text);
      }
      return _extractEntitiesLocal(text);
    } catch (_) {
      return _extractEntitiesLocal(text);
    }
  }

  Future<Map<String, dynamic>> _extractWithOpenAi(String text) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': [
              {
                'role': 'system',
                'content':
                    'Extract named entities (persons, locations, organizations). Return as JSON: {"entities": [...], "counts": {...}}',
              },
              {
                'role': 'user',
                'content': text.substring(
                  0,
                  text.length > 2000 ? 2000 : text.length,
                ),
              },
            ],
            'temperature': 0.3,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '{}';
      try {
        return jsonDecode(content);
      } catch (_) {
        return _extractEntitiesLocal(text);
      }
    }
    return _extractEntitiesLocal(text);
  }

  Map<String, dynamic> _extractEntitiesLocal(String text) {
    // Basic local NER: Find capitalized words/phrases
    final entities = <String>{};
    final entityCounts = <String, int>{};

    // Capitalized word patterns (simple NER)
    final capPattern = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b');
    for (final match in capPattern.allMatches(text)) {
      final entity = match.group(1) ?? '';
      if (entity.length > 2 && !_isCommonWord(entity)) {
        entities.add(entity);
        entityCounts[entity] = (entityCounts[entity] ?? 0) + 1;
      }
    }

    return {'entities': entities.toList(), 'counts': entityCounts};
  }

  bool _isCommonWord(String word) {
    const common = {
      'The',
      'And',
      'But',
      'For',
      'From',
      'With',
      'This',
      'That',
      'Have',
      'Has',
      'Had',
      'Does',
      'Did',
      'Will',
      'Would',
      'Could',
    };
    return common.contains(word);
  }

  /// Translate arbitrary text to English using OpenAI fallback when available.
  /// If no API key is configured, returns the original text.
  Future<String> translateToEnglish(String text) async {
    if (_apiKey.isEmpty) return text;
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-3.5-turbo',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a translator. Translate the user text to English. Preserve meaning but do not add commentary.',
                },
                {
                  'role': 'user',
                  'content': text.substring(
                    0,
                    text.length > 3000 ? 3000 : text.length,
                  ),
                },
              ],
              'temperature': 0.0,
              'max_tokens': 1200,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        return content.toString().trim();
      }
    } catch (_) {}
    return text;
  }

  /// Translate English text into `targetLang` (ISO code or language name) using OpenAI if available.
  Future<String> translate(String text, String targetLang) async {
    if (_apiKey.isEmpty) return text;
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-3.5-turbo',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a translator. Translate the user text into the requested language exactly. Respond with the translation only.',
                },
                {
                  'role': 'user',
                  'content':
                      'Translate the following text to $targetLang:\n\n'
                      '${text.substring(0, text.length > 3000 ? 3000 : text.length)}',
                },
              ],
              'temperature': 0.0,
              'max_tokens': 1200,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        return content.toString().trim();
      }
    } catch (_) {}
    return text;
  }

  /// Full enhancement analysis
  Future<AiEnhancement> analyzeNote(String text) async {
    try {
      final sentiment = await analyzeSentiment(text);
      final qaItems = await extractQA(text);
      final speakers = await detectSpeakers(text);
      final entities = await extractEntities(text);

      return AiEnhancement(
        sentiment: sentiment['sentiment'] ?? 'neutral',
        sentimentScore: (sentiment['score'] ?? 0.5).toDouble(),
        speakers: speakers,
        qaItems: qaItems,
        entities: List<String>.from(entities['entities'] ?? []),
        entityCounts: Map<String, int>.from(entities['counts'] ?? {}),
      );
    } catch (e) {
      return AiEnhancement.empty();
    }
  }
}
