import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;
  final List<String> likes;
  final int lineNumber;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
    required this.likes,
    this.lineNumber = 0,
  });

  bool get isLikedByCurrentUser =>
      likes.contains(FirebaseAuth.instance.currentUser?.uid);

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'content': content,
    'createdAt': Timestamp.fromDate(createdAt),
    'likes': likes,
    'lineNumber': lineNumber,
  };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] ?? '',
    userId: json['userId'] ?? '',
    userName: json['userName'] ?? 'Unknown',
    userAvatar: json['userAvatar'] ?? '',
    content: json['content'] ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    likes: List<String>.from(json['likes'] ?? []),
    lineNumber: json['lineNumber'] ?? 0,
  );
}

class SharedAccess {
  final String userId;
  final String email;
  final String displayName;
  final String role; // 'viewer', 'editor', 'owner'
  final DateTime grantedAt;

  SharedAccess({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.grantedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': role,
    'grantedAt': Timestamp.fromDate(grantedAt),
  };

  factory SharedAccess.fromJson(Map<String, dynamic> json) => SharedAccess(
    userId: json['userId'] ?? '',
    email: json['email'] ?? '',
    displayName: json['displayName'] ?? '',
    role: json['role'] ?? 'viewer',
    grantedAt: (json['grantedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

class StudyGroup {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;
  final List<String> noteIds;
  final int memberLimit;

  StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.noteIds,
    this.memberLimit = 50,
  });

  bool get isFull => members.length >= memberLimit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'members': members,
    'noteIds': noteIds,
    'memberLimit': memberLimit,
  };

  factory StudyGroup.fromJson(Map<String, dynamic> json) => StudyGroup(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    createdBy: json['createdBy'] ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    members: List<String>.from(json['members'] ?? []),
    noteIds: List<String>.from(json['noteIds'] ?? []),
    memberLimit: json['memberLimit'] ?? 50,
  );
}

class CollaborationService {
  static final CollaborationService _instance =
      CollaborationService._internal();
  factory CollaborationService() => _instance;
  CollaborationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Comments ──────────────────────────────────────────

  /// Add comment to note
  Future<void> addComment(
    String noteId,
    String content, {
    int lineNumber = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final commentId = _db
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .doc()
        .id;

    await _db
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .doc(commentId)
        .set({
          'id': commentId,
          'userId': user.uid,
          'userName': user.displayName ?? 'Anonymous',
          'userAvatar': user.photoURL ?? '',
          'content': content,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': [],
          'lineNumber': lineNumber,
        });

    // Update note's comment count
    await _db.collection('notes').doc(noteId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  /// Get comments for note
  Future<List<Comment>> getComments(String noteId) async {
    try {
      final snapshot = await _db
          .collection('notes')
          .doc(noteId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) => Comment.fromJson(doc.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Like/unlike comment
  Future<void> toggleCommentLike(String noteId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final commentRef = _db
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .doc(commentId);

    final doc = await commentRef.get();
    if (!doc.exists) return;

    final comment = Comment.fromJson(doc.data() ?? {});
    final likes = List<String>.from(comment.likes);

    if (likes.contains(user.uid)) {
      likes.remove(user.uid);
    } else {
      likes.add(user.uid);
    }

    await commentRef.update({'likes': likes});
  }

  /// Delete comment
  Future<void> deleteComment(String noteId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Get comment to verify ownership
    final doc = await _db
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .doc(commentId)
        .get();

    if (doc.exists && doc['userId'] == user.uid) {
      await doc.reference.delete();

      // Update note's comment count
      await _db.collection('notes').doc(noteId).update({
        'commentCount': FieldValue.increment(-1),
      });
    }
  }

  // ── Sharing ───────────────────────────────────────────

  /// Share note with user(s)
  Future<void> shareNote(
    String noteId,
    List<String> emails, {
    String role = 'viewer',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Get note owner
    final noteDoc = await _db.collection('notes').doc(noteId).get();
    if (noteDoc['userId'] != user.uid) {
      throw Exception('Only note owner can share');
    }

    // Add shared access records
    for (final email in emails) {
      // In production, look up user by email
      await _db.collection('notes').doc(noteId).update({
        'sharedWith': FieldValue.arrayUnion([
          {
            'email': email,
            'role': role,
            'grantedAt': FieldValue.serverTimestamp(),
          },
        ]),
      });
    }
  }

  /// Get users with access to note
  Future<List<SharedAccess>> getNoteAccess(String noteId) async {
    try {
      final doc = await _db.collection('notes').doc(noteId).get();
      final sharedWith = doc['sharedWith'] as List? ?? [];

      return sharedWith.map((item) => SharedAccess.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Revoke note access
  Future<void> revokeAccess(String noteId, String email) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final noteDoc = await _db.collection('notes').doc(noteId).get();
    if (noteDoc['userId'] != user.uid) {
      throw Exception('Only note owner can revoke access');
    }

    await _db.collection('notes').doc(noteId).update({
      'sharedWith': FieldValue.arrayRemove([
        {'email': email},
      ]),
    });
  }

  // ── Study Groups ──────────────────────────────────────

  /// Create study group
  Future<String> createStudyGroup(
    String name,
    String description, {
    int memberLimit = 50,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final groupRef = _db.collection('study_groups').doc();

    await groupRef.set({
      'id': groupRef.id,
      'name': name,
      'description': description,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [user.uid],
      'noteIds': [],
      'memberLimit': memberLimit,
    });

    return groupRef.id;
  }

  /// Join study group
  Future<void> joinStudyGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final groupDoc = await _db.collection('study_groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final group = StudyGroup.fromJson(groupDoc.data()!);
    if (group.isFull) throw Exception('Group is full');

    await _db.collection('study_groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([user.uid]),
    });
  }

  /// Leave study group
  Future<void> leaveStudyGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _db.collection('study_groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([user.uid]),
    });
  }

  /// Add note to study group
  Future<void> addNoteToGroup(String groupId, String noteId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Verify user is member of group
    final groupDoc = await _db.collection('study_groups').doc(groupId).get();
    final group = StudyGroup.fromJson(groupDoc.data()!);

    if (!group.members.contains(user.uid)) {
      throw Exception('Not a member of this group');
    }

    await _db.collection('study_groups').doc(groupId).update({
      'noteIds': FieldValue.arrayUnion([noteId]),
    });
  }

  /// Get user's study groups
  Future<List<StudyGroup>> getUserStudyGroups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _db
          .collection('study_groups')
          .where('members', arrayContains: user.uid)
          .get();

      return snapshot.docs
          .map((doc) => StudyGroup.fromJson(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get study group
  Future<StudyGroup?> getStudyGroup(String groupId) async {
    try {
      final doc = await _db.collection('study_groups').doc(groupId).get();
      if (doc.exists) {
        return StudyGroup.fromJson(doc.data()!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get notes shared in group
  Future<List<String>> getGroupNotes(String groupId) async {
    try {
      final doc = await _db.collection('study_groups').doc(groupId).get();
      if (doc.exists) {
        return List<String>.from(doc['noteIds'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
