import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart';

class SmartTag {
  final String name;
  final double confidence;
  final String source; // 'ai', 'user', 'system'

  SmartTag({
    required this.name,
    required this.confidence,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'confidence': confidence,
    'source': source,
  };

  factory SmartTag.fromJson(Map<String, dynamic> json) => SmartTag(
    name: json['name'] ?? '',
    confidence: (json['confidence'] ?? 0.5).toDouble(),
    source: json['source'] ?? 'user',
  );
}

class RelatedNote {
  final String noteId;
  final String title;
  final double similarity;

  RelatedNote({
    required this.noteId,
    required this.title,
    required this.similarity,
  });
}

class SmartOrganizationService {
  static final SmartOrganizationService _instance =
      SmartOrganizationService._internal();
  factory SmartOrganizationService() => _instance;
  SmartOrganizationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Auto-tag note based on content
  Future<List<SmartTag>> autoTag(String text) async {
    final tags = <SmartTag>{};

    // Extract keywords and phrases
    final keywordTags = _extractKeywords(text);
    tags.addAll(keywordTags);

    // Category detection
    final categoryTag = _detectCategory(text);
    if (categoryTag != null) tags.add(categoryTag);

    // Topic detection
    final topicTags = _detectTopics(text);
    tags.addAll(topicTags);

    // Skills/technologies mentioned
    final techTags = _detectTechnologies(text);
    tags.addAll(techTags);

    return tags.toList();
  }

  List<SmartTag> _extractKeywords(String text) {
    final tags = <SmartTag>[];

    // Simple keyword extraction: words 4+ chars, not stopwords
    final words = text.toLowerCase().split(RegExp(r'[^\w]+'));
    final stopwords = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'was',
      'were',
      'be',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'can',
      'not',
      'and',
      'but',
      'or',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'this',
      'that',
    };

    final wordFreq = <String, int>{};
    for (final word in words) {
      if (word.length >= 4 && !stopwords.contains(word)) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // Sort by frequency and take top 10
    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted.take(10)) {
      tags.add(
        SmartTag(
          name: entry.key,
          confidence: (entry.value / words.length).clamp(0.3, 0.95),
          source: 'ai',
        ),
      );
    }

    return tags;
  }

  SmartTag? _detectCategory(String text) {
    final lowerText = text.toLowerCase();

    const categories = {
      'meeting': ['meeting', 'discussion', 'team', 'project', 'deadline'],
      'lecture': ['lecture', 'class', 'course', 'professor', 'assignment'],
      'interview': ['interview', 'candidate', 'question', 'experience'],
      'research': ['research', 'study', 'hypothesis', 'data', 'analysis'],
      'personal': ['personal', 'reminder', 'todo', 'goal', 'idea'],
    };

    final scores = <String, int>{};

    for (final entry in categories.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        score += RegExp(r'\b' + keyword + r'\b').allMatches(lowerText).length;
      }
      if (score > 0) scores[entry.key] = score;
    }

    if (scores.isNotEmpty) {
      final topCategory = scores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return SmartTag(name: topCategory, confidence: 0.7, source: 'ai');
    }
    return null;
  }

  List<SmartTag> _detectTopics(String text) {
    final tags = <SmartTag>[];
    final lowerText = text.toLowerCase();

    const topics = {
      'time-management': ['deadline', 'schedule', 'plan', 'manage', 'organize'],
      'learning': ['learn', 'understand', 'study', 'practice', 'improve'],
      'health': ['health', 'exercise', 'sleep', 'nutrition', 'wellness'],
      'technology': ['technology', 'software', 'code', 'app', 'digital'],
      'business': ['business', 'market', 'strategy', 'revenue', 'growth'],
      'communication': [
        'communication',
        'presentation',
        'speak',
        'listen',
        'feedback',
      ],
    };

    for (final entry in topics.entries) {
      int matches = 0;
      for (final keyword in entry.value) {
        matches += RegExp(r'\b' + keyword + r'\b').allMatches(lowerText).length;
      }
      if (matches >= 2) {
        tags.add(
          SmartTag(
            name: entry.key,
            confidence: (matches / entry.value.length * 0.8).clamp(0.4, 0.9),
            source: 'ai',
          ),
        );
      }
    }

    return tags;
  }

  List<SmartTag> _detectTechnologies(String text) {
    final tags = <SmartTag>[];
    final lowerText = text.toLowerCase();

    const techs = [
      'javascript',
      'python',
      'java',
      'kotlin',
      'swift',
      'flutter',
      'react',
      'angular',
      'vue',
      'django',
      'spring',
      'aws',
      'gcp',
      'azure',
      'docker',
      'kubernetes',
      'git',
      'firebase',
      'mongodb',
      'postgres',
    ];

    for (final tech in techs) {
      if (lowerText.contains(tech)) {
        tags.add(SmartTag(name: tech, confidence: 0.85, source: 'ai'));
      }
    }

    return tags;
  }

  /// Find related notes based on similarity
  Future<List<RelatedNote>> findRelatedNotes(
    String currentNoteId,
    String userId,
    String textContent,
  ) async {
    try {
      final snapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .where('id', isNotEqualTo: currentNoteId)
          .limit(50)
          .get();

      final relatedNotes = <RelatedNote>[];

      for (final doc in snapshot.docs) {
        final note = NoteModel.fromJson(doc.data());
        final similarity = _calculateSimilarity(
          textContent,
          note.transcription,
        );

        if (similarity > 0.2) {
          relatedNotes.add(
            RelatedNote(
              noteId: note.id,
              title: note.title,
              similarity: similarity,
            ),
          );
        }
      }

      // Sort by similarity descending
      relatedNotes.sort((a, b) => b.similarity.compareTo(a.similarity));
      return relatedNotes.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  double _calculateSimilarity(String text1, String text2) {
    // Simple Jaccard similarity
    final words1 = text1.toLowerCase().split(RegExp(r'\W+')).toSet();
    final words2 = text2.toLowerCase().split(RegExp(r'\W+')).toSet();

    if (words1.isEmpty || words2.isEmpty) return 0;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return union > 0 ? intersection / union : 0;
  }

  /// Get smart folder suggestions
  Future<List<String>> suggestFolders(
    String userId,
    List<SmartTag> tags,
  ) async {
    final suggestions = <String>{};

    // Add tags as potential folders
    for (final tag in tags.where((t) => t.confidence > 0.6)) {
      suggestions.add(tag.name);
    }

    // Get existing folders from user's notes
    try {
      final snapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      for (final doc in snapshot.docs) {
        final folder = doc.data()['folder'];
        if (folder is String && folder.isNotEmpty) {
          suggestions.add(folder);
        }
      }
    } catch (_) {}

    return suggestions.toList().take(10).toList();
  }

  /// Create smart folder
  Future<void> createSmartFolder(
    String userId,
    String folderName,
    List<String> tags,
  ) async {
    try {
      await _db.collection('users').doc(userId).update({
        'smartFolders': FieldValue.arrayUnion([
          {
            'name': folderName,
            'tags': tags,
            'createdAt': FieldValue.serverTimestamp(),
            'noteCount': 0,
          },
        ]),
      });
    } catch (e) {
      // Folder might already exist or other error
      rethrow;
    }
  }

  /// Get notes by smart folder/tag filter
  Future<List<NoteModel>> getNotesByTag(String userId, String tag) async {
    try {
      final snapshot = await _db
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .where('tags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => NoteModel.fromJson(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
