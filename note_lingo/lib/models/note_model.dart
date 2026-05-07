import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteCategory { lecture, meeting, interview, personal, other }

extension NoteCategoryExt on NoteCategory {
  String get label {
    switch (this) {
      case NoteCategory.lecture:
        return 'Lecture';
      case NoteCategory.meeting:
        return 'Meeting';
      case NoteCategory.interview:
        return 'Interview';
      case NoteCategory.personal:
        return 'Personal';
      case NoteCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case NoteCategory.lecture:
        return '🎓';
      case NoteCategory.meeting:
        return '💼';
      case NoteCategory.interview:
        return '🤝';
      case NoteCategory.personal:
        return '📔';
      case NoteCategory.other:
        return '📝';
    }
  }
}

class NoteModel {
  final String id;
  final String userId;
  final String title;
  final String transcription;
  final String summary;
  final String language;
  final NoteCategory category;
  final List<String> keywords;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wordCount;
  final int duration; // in seconds
  final bool isFavorite;
  // New features
  final List<String> tags; // Smart tags from AI
  final String? folder; // Smart folder organization
  final List<String> relatedNoteIds; // Related notes
  final String? sentiment; // positive, negative, neutral
  final double sentimentScore; // 0-1
  final List<String> speakers; // Speaker labels
  final List<Map<String, dynamic>> qaItems; // Q&A pairs
  final List<String> entities; // Named entities
  final List<Map<String, dynamic>> sharedWith; // Shared access
  final int commentCount;

  const NoteModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.transcription,
    required this.summary,
    required this.language,
    required this.category,
    required this.keywords,
    this.audioUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.wordCount,
    required this.duration,
    this.isFavorite = false,
    this.tags = const [],
    this.folder,
    this.relatedNoteIds = const [],
    this.sentiment,
    this.sentimentScore = 0.5,
    this.speakers = const [],
    this.qaItems = const [],
    this.entities = const [],
    this.sharedWith = const [],
    this.commentCount = 0,
  });

  // Backward-compat alias used by some screens/providers.
  String get transcript => transcription;

  // Factory method from JSON (for API responses)
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? 'Untitled Note',
      transcription: json['transcription'] ?? '',
      summary: json['summary'] ?? '',
      language: json['language'] ?? 'en',
      category: NoteCategory.values.firstWhere(
        (e) => e.name == (json['category'] ?? 'other'),
        orElse: () => NoteCategory.other,
      ),
      keywords: List<String>.from(json['keywords'] ?? []),
      audioUrl: json['audioUrl'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['updatedAt'] ?? DateTime.now().toIso8601String(),
            ),
      wordCount: json['wordCount'] ?? 0,
      duration: json['duration'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      folder: json['folder'],
      relatedNoteIds: List<String>.from(json['relatedNoteIds'] ?? []),
      sentiment: json['sentiment'],
      sentimentScore: (json['sentimentScore'] ?? 0.5).toDouble(),
      speakers: List<String>.from(json['speakers'] ?? []),
      qaItems: List<Map<String, dynamic>>.from(json['qaItems'] ?? []),
      entities: List<String>.from(json['entities'] ?? []),
      sharedWith: List<Map<String, dynamic>>.from(json['sharedWith'] ?? []),
      commentCount: json['commentCount'] ?? 0,
    );
  }

  // ── From Firestore ─────────────────────────────────────────
  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      title: d['title'] ?? 'Untitled Note',
      transcription: d['transcription'] ?? '',
      summary: d['summary'] ?? '',
      language: d['language'] ?? 'en',
      category: NoteCategory.values.firstWhere(
        (e) => e.name == (d['category'] ?? 'other'),
        orElse: () => NoteCategory.other,
      ),
      keywords: List<String>.from(d['keywords'] ?? []),
      audioUrl: d['audioUrl'],
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      wordCount: d['wordCount'] ?? 0,
      duration: d['duration'] ?? 0,
      isFavorite: d['isFavorite'] ?? false,
      tags: List<String>.from(d['tags'] ?? []),
      folder: d['folder'],
      relatedNoteIds: List<String>.from(d['relatedNoteIds'] ?? []),
      sentiment: d['sentiment'],
      sentimentScore: (d['sentimentScore'] ?? 0.5).toDouble(),
      speakers: List<String>.from(d['speakers'] ?? []),
      qaItems: List<Map<String, dynamic>>.from(d['qaItems'] ?? []),
      entities: List<String>.from(d['entities'] ?? []),
      sharedWith: List<Map<String, dynamic>>.from(d['sharedWith'] ?? []),
      commentCount: d['commentCount'] ?? 0,
    );
  }

  // ── To Firestore ───────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'transcription': transcription,
      'summary': summary,
      'language': language,
      'category': category.name,
      'keywords': keywords,
      'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'wordCount': wordCount,
      'duration': duration,
      'isFavorite': isFavorite,
      'tags': tags,
      'folder': folder,
      'relatedNoteIds': relatedNoteIds,
      'sentiment': sentiment,
      'sentimentScore': sentimentScore,
      'speakers': speakers,
      'qaItems': qaItems,
      'entities': entities,
      'sharedWith': sharedWith,
      'commentCount': commentCount,
    };
  }

  // Backward-compat alias for older service code.
  Map<String, dynamic> toJson() => toFirestore();

  // ── CopyWith ───────────────────────────────────────────────
  NoteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? transcription,
    String? summary,
    String? language,
    NoteCategory? category,
    List<String>? keywords,
    String? audioUrl,
    DateTime? updatedAt,
    bool? isFavorite,
    int? wordCount,
    int? duration,
    List<String>? tags,
    String? folder,
    List<String>? relatedNoteIds,
    String? sentiment,
    double? sentimentScore,
    List<String>? speakers,
    List<Map<String, dynamic>>? qaItems,
    List<String>? entities,
    List<Map<String, dynamic>>? sharedWith,
    int? commentCount,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      transcription: transcription ?? this.transcription,
      summary: summary ?? this.summary,
      language: language ?? this.language,
      category: category ?? this.category,
      keywords: keywords ?? this.keywords,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wordCount: wordCount ?? this.wordCount,
      duration: duration ?? this.duration,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      folder: folder ?? this.folder,
      relatedNoteIds: relatedNoteIds ?? this.relatedNoteIds,
      sentiment: sentiment ?? this.sentiment,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      speakers: speakers ?? this.speakers,
      qaItems: qaItems ?? this.qaItems,
      entities: entities ?? this.entities,
      sharedWith: sharedWith ?? this.sharedWith,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  String get formattedDuration {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get languageLabel {
    switch (language) {
      case 'si':
        return 'Sinhala';
      case 'ta':
        return 'Tamil';
      default:
        return 'English';
    }
  }

  String get languageFlag {
    return languageLabel;
  }

  String get previewText {
    final text = summary.isNotEmpty ? summary : transcription;
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  String get categoryLabel => category.label;
}
