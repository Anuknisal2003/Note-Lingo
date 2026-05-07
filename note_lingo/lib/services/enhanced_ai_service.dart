import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      // Try OpenAI first if API key available
      if (_apiKey.isNotEmpty) {
        return await _analyzeWithOpenAi(text);
      }
      // Fallback to local sentiment analysis
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
      if (lowerContent.contains('positive'))
        sentiment = 'positive';
      else if (lowerContent.contains('negative'))
        sentiment = 'negative';

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
      // Try OpenAI first
      if (_apiKey.isNotEmpty) {
        return await _extractQaWithOpenAi(text);
      }
      return _extractQaWithLocal(text);
    } catch (e) {
      return _extractQaWithLocal(text);
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

  /// Detect speaker transitions/labels in transcript
  Future<List<String>> detectSpeakers(String text) async {
    // Local speaker detection: Look for patterns like "Speaker:", "Name:", etc.
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

    return speakers.toList().take(10).toList();
  }

  /// Extract named entities from text
  Future<Map<String, dynamic>> extractEntities(String text) async {
    try {
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
