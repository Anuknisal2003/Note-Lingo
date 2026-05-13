import 'package:cloud_firestore/cloud_firestore.dart';

/// Comment on a shared note with real-time collaboration support.
class CommentModel {
  final String id;
  final String noteId; // Reference to parent note
  final String userId; // Author
  final String userName; // Author's display name
  final String userEmail; // Author's email
  final String content; // Comment text
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likes; // Like count
  final List<String> likedBy; // User IDs who liked this comment
  final String? parentCommentId; // For reply chains
  final List<String> replyIds; // IDs of direct replies

  const CommentModel({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.likes = 0,
    this.likedBy = const [],
    this.parentCommentId,
    this.replyIds = const [],
  });

  // ── From Firestore ─────────────────────────────────────────
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      noteId: d['noteId'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? 'Anonymous',
      userEmail: d['userEmail'] ?? '',
      content: d['content'] ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
      likes: d['likes'] ?? 0,
      likedBy: List<String>.from(d['likedBy'] ?? []),
      parentCommentId: d['parentCommentId'],
      replyIds: List<String>.from(d['replyIds'] ?? []),
    );
  }

  // ── To Firestore ───────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'likes': likes,
      'likedBy': likedBy,
      'parentCommentId': parentCommentId,
      'replyIds': replyIds,
    };
  }

  // ── CopyWith ───────────────────────────────────────────────
  CommentModel copyWith({
    String? id,
    String? noteId,
    String? userId,
    String? userName,
    String? userEmail,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likes,
    List<String>? likedBy,
    String? parentCommentId,
    List<String>? replyIds,
  }) {
    return CommentModel(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyIds: replyIds ?? this.replyIds,
    );
  }

  @override
  String toString() => 'CommentModel(id=$id, noteId=$noteId, userId=$userId)';
}
