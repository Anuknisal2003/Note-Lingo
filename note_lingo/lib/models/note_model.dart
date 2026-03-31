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
  });

  // Backward-compat alias used by some screens/providers.
  String get transcript => transcription;

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
    switch (language) {
      case 'si':
        return '🇱🇰';
      case 'ta':
        return '🇱🇰';
      default:
        return '🇬🇧';
    }
  }

  String get previewText {
    final text = summary.isNotEmpty ? summary : transcription;
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  String get categoryLabel => category.label;
}
