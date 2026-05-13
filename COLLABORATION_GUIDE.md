# Collaboration & Study Groups Implementation Guide

This guide documents the implementation of collaboration features (shared notes, comments) and study groups with tag-based organization in Note-Lingo.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Frontend                           │
│                                                                 │
│  CollaborationProvider ─────┬─────── StudyGroupService          │
│  (UI State)                 │       (Data Operations)           │
│                             │                                   │
│  TagQueryService ───────────┴─────── Firestore SDK             │
│  (Advanced Queries)                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Firestore Backend                            │
│                                                                 │
│  Collections:                                                   │
│  ├── notes (with tags, sharedWith fields)                       │
│  │   └── comments (sub-collection, real-time)                   │
│  ├── study_groups (groups, members, shared notes)               │
│  │   └── presence (sub-collection, online users)                │
│  └── Indexes (for compound queries)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Collaboration Features (Sharing & Comments)

### 1.1 Note Sharing

**Flow**: User A → Shares Note → User B (Access Control)

**Implementation** (`CollaborationService`):

```dart
// Share a note with another user
Future<void> shareNote(
  String noteId,
  String targetUserEmail,
  String accessLevel, // 'view' | 'comment' | 'edit'
) async {
  await noteRef.update({
    'sharedWith': FieldValue.arrayUnion([
      {
        'userEmail': targetUserEmail,
        'accessLevel': accessLevel,
        'sharedAt': Timestamp.now(),
      }
    ]),
  });
}
```

**Data Model** (`NoteModel.sharedWith`):
```dart
sharedWith: [
  {
    'userEmail': 'user@example.com',
    'accessLevel': 'view', // read-only
    'sharedAt': Timestamp
  },
  {
    'userEmail': 'colleague@example.com',
    'accessLevel': 'comment', // can read & comment
    'sharedAt': Timestamp
  },
]
```

**Access Levels**:
- **`view`**: Read-only access (no modifications)
- **`comment`**: Can read and add comments
- **`edit`**: Full access (read, edit, delete)

**Usage in UI**:
```dart
// Share a note from recording_screen.dart or notes_list.dart
await collaborationProvider.shareNote(
  noteId: note.id,
  targetUserEmail: 'colleague@example.com',
  accessLevel: 'comment',
);

// Load notes shared with you
await collaborationProvider.loadSharedNotes();
final sharedNotes = collaborationProvider.sharedNotes;
```

---

### 1.2 Real-Time Comments

**Flow**: User → Writes Comment → Stream to all viewers

**Implementation** (`CollaborationService`):

```dart
// Add a comment
Future<String> addComment(String noteId, String content) async {
  final commentRef = await firestore
      .collection('notes')
      .doc(noteId)
      .collection('comments')
      .add({
        'userId': uid,
        'userName': displayName,
        'content': content,
        'createdAt': Timestamp.now(),
        'likes': 0,
        'likedBy': [],
        'parentCommentId': null, // for reply chains
        'replyIds': [],
      });
  
  // Update note's commentCount
  await firestore.collection('notes').doc(noteId).update({
    'commentCount': FieldValue.increment(1),
  });
  
  return commentRef.id;
}

// Listen to real-time comments
Stream<List<CommentModel>> getCommentsStream(String noteId) {
  return firestore
      .collection('notes')
      .doc(noteId)
      .collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList());
}
```

**Data Model** (`CommentModel`):
```dart
CommentModel(
  id: 'comment123',
  noteId: 'note456',
  userId: 'user789',
  userName: 'Alice',
  userEmail: 'alice@example.com',
  content: 'Great insight!',
  createdAt: DateTime.now(),
  updatedAt: null,
  likes: 2,
  likedBy: ['user1', 'user2'],
  parentCommentId: null, // null if top-level comment
  replyIds: ['comment789'], // IDs of direct replies
)
```

**Usage in UI**:
```dart
// Watch comments in real-time
StreamBuilder<List<CommentModel>>(
  stream: collaborationProvider.watchComments(noteId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final comments = snapshot.data!;
      return ListView.builder(
        itemCount: comments.length,
        itemBuilder: (context, index) {
          final comment = comments[index];
          return CommentTile(
            comment: comment,
            onLike: () => collaborationProvider.likeComment(
              noteId,
              comment.id,
            ),
            onDelete: () => collaborationProvider.deleteComment(
              noteId,
              comment.id,
            ),
          );
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

### 1.3 Comment Threading (Replies)

**Flow**: User → Replies to Comment → Nested thread

**Hierarchy**:
```
Note (noteId: "note123")
├── Comment (id: "comment1", parentCommentId: null)
│   ├── Reply (id: "comment2", parentCommentId: "comment1")
│   └── Reply (id: "comment3", parentCommentId: "comment1")
└── Comment (id: "comment4", parentCommentId: null)
```

**Implementation**:
```dart
// Add a reply to a comment
Future<String> addReply(
  String noteId,
  String parentCommentId,
  String content,
) async {
  return await addComment(
    noteId,
    content,
    parentCommentId: parentCommentId, // Link to parent
  );
}

// In CommentModel:
final String? parentCommentId; // null for top-level
final List<String> replyIds; // IDs of direct replies
```

---

## 2. Study Groups & Tags

### 2.1 Study Groups

**Purpose**: Organize users into collaborative groups with shared notes

**Implementation** (`StudyGroupService`):

```dart
// Create a group
Future<String> createGroup({
  required String name,
  required String description,
  List<String> tags = const [],
  bool isPrivate = false,
}) async {
  return await firestore.collection('study_groups').add({
    'name': 'Introduction to Physics',
    'description': 'Fall 2026 Physics Lecture Notes',
    'createdBy': uid,
    'createdAt': Timestamp.now(),
    'memberIds': [uid],
    'memberRoles': {uid: 'admin'},
    'sharedNoteIds': [],
    'tags': ['physics', 'lecture'],
    'isPrivate': false,
    'memberCount': 1,
  });
}
```

**Data Model** (`StudyGroup`):
```dart
StudyGroup(
  id: 'group123',
  name: 'Physics Study Group',
  description: 'Collaborative notes for Physics 101',
  createdBy: 'prof@university.edu',
  createdAt: DateTime.now(),
  memberIds: ['prof@university.edu', 'student1@..', 'student2@..'],
  memberRoles: {
    'prof@university.edu': 'admin',
    'student1@..': 'member',
    'student2@..': 'moderator',
  },
  sharedNoteIds: ['note1', 'note2', 'note3'],
  tags: ['physics', 'lecture', 'fall2026'],
  isPrivate: false,
  memberCount: 3,
)
```

**Member Roles**:
- **`admin`**: Can modify group, manage members, delete group
- **`moderator`**: Can manage members, moderate comments
- **`member`**: Can view/comment, but not modify group settings

---

### 2.2 Member Management

**Implementation**:

```dart
// Add member to group
Future<void> addMember(String groupId, String userEmail) async {
  await firestore.collection('study_groups').doc(groupId).update({
    'memberIds': FieldValue.arrayUnion([userEmail]),
    'memberRoles': newRoles,
    'memberCount': FieldValue.increment(1),
  });
}

// Remove member
Future<void> removeMember(String groupId, String userEmail) async {
  await firestore.collection('study_groups').doc(groupId).update({
    'memberIds': FieldValue.arrayRemove([userEmail]),
    'memberRoles': newRoles,
    'memberCount': FieldValue.increment(-1),
  });
}

// Update member role
Future<void> updateMemberRole(
  String groupId,
  String userEmail,
  String newRole,
) async {
  // Read → Update roles map → Write back
}
```

**UI Example**:
```dart
// Member list with role management
ListView.builder(
  itemCount: group.memberIds.length,
  itemBuilder: (context, index) {
    final memberId = group.memberIds[index];
    final role = group.memberRoles[memberId];
    
    return ListTile(
      title: Text(memberId),
      subtitle: Text('Role: $role'),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          PopupMenuItem(
            child: Text('Admin'),
            onTap: () => groupProvider.updateMemberRole(
              groupId,
              memberId,
              'admin',
            ),
          ),
          PopupMenuItem(
            child: Text('Remove'),
            onTap: () => groupProvider.removeGroupMember(groupId, memberId),
          ),
        ],
      ),
    );
  },
)
```

---

### 2.3 Sharing Notes with Groups

**Implementation**:

```dart
// Share note with group
Future<void> shareNoteWithGroup(String groupId, String noteId) async {
  await firestore.collection('study_groups').doc(groupId).update({
    'sharedNoteIds': FieldValue.arrayUnion([noteId]),
  });
}

// Get all notes in user's groups
Future<List<NoteModel>> getNotesInMyGroups() async {
  final groups = await getMyGroups();
  
  // Collect all shared note IDs
  final noteIds = <String>{};
  for (final group in groups) {
    noteIds.addAll(group.sharedNoteIds);
  }
  
  // Batch fetch notes (max 10 per query)
  final notes = <NoteModel>[];
  for (var batch in batchIds) {
    notes.addAll(await firestore
        .collection('notes')
        .where(FieldPath.documentId, whereIn: batch)
        .get()
        .then((snap) => snap.docs.map(NoteModel.fromFirestore)));
  }
  
  return notes;
}
```

---

## 3. Tags & Advanced Queries

### 3.1 Tag Management

**Implementation** (`TagQueryService`):

```dart
// Get all unique tags for user
Future<Set<String>> getUserTags() async {
  final snapshot = await firestore
      .collection('notes')
      .where('userId', isEqualTo: uid)
      .get();
  
  final tags = <String>{};
  for (final doc in snapshot.docs) {
    final note = NoteModel.fromFirestore(doc);
    tags.addAll(note.tags);
  }
  return tags;
}

// Add tag to note
Future<void> addTag(String noteId, String tag) async {
  await firestore.collection('notes').doc(noteId).update({
    'tags': FieldValue.arrayUnion([tag]),
  });
}

// Remove tag
Future<void> removeTag(String noteId, String tag) async {
  await firestore.collection('notes').doc(noteId).update({
    'tags': FieldValue.arrayRemove([tag]),
  });
}
```

**UI Example**:
```dart
// Tag selection in note detail screen
final userTags = await tagQueryService.getUserTags();

showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Edit Tags'),
    content: Wrap(
      children: userTags.map((tag) {
        final isSelected = note.tags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (selected) async {
            if (selected) {
              await tagQueryService.addTag(note.id, tag);
            } else {
              await tagQueryService.removeTag(note.id, tag);
            }
          },
        );
      }).toList(),
    ),
  ),
)
```

---

### 3.2 Compound Tag Queries

**Implementation** (`TagQueryService`):

```dart
// Query by tag only
Future<List<NoteModel>> getNotesByTag(String tag) async {
  return await firestore
      .collection('notes')
      .where('userId', isEqualTo: uid)
      .where('tags', arrayContains: tag)
      .orderBy('createdAt', descending: true)
      .get()
      .then((snap) => snap.docs.map(NoteModel.fromFirestore).toList());
}

// Query by tag AND category
Future<List<NoteModel>> getNotesByTagAndCategory(String tag, String category) async {
  return await firestore
      .collection('notes')
      .where('userId', isEqualTo: uid)
      .where('tags', arrayContains: tag)
      .where('category', isEqualTo: category)
      .orderBy('createdAt', descending: true)
      .get()
      .then((snap) => snap.docs.map(NoteModel.fromFirestore).toList());
}

// Query by multiple tags AND date range
Future<List<NoteModel>> getNotesByTagsAndDateRange(
  List<String> tags,
  DateTime startDate,
  DateTime endDate,
) async {
  return await firestore
      .collection('notes')
      .where('userId', isEqualTo: uid)
      .where('tags', arrayContainsAny: tags)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
      .orderBy('createdAt', descending: true)
      .get()
      .then((snap) => snap.docs.map(NoteModel.fromFirestore).toList());
}
```

---

## 4. Real-Time Presence

### 4.1 Online User Awareness

**Purpose**: Show which users are currently active in a study group

**Implementation** (`CollaborationService`):

```dart
// Mark user as online in group
Future<void> markOnline(String groupId) async {
  await firestore
      .collection('study_groups')
      .doc(groupId)
      .collection('presence')
      .doc(uid)
      .set({
        'userId': uid,
        'lastSeen': Timestamp.now(),
        'online': true,
      }, SetOptions(merge: true));
}

// Mark offline (call on app background/close)
Future<void> markOffline(String groupId) async {
  await firestore
      .collection('study_groups')
      .doc(groupId)
      .collection('presence')
      .doc(uid)
      .update({
        'online': false,
        'lastSeen': Timestamp.now(),
      });
}

// Stream of online users
Stream<List<String>> getOnlineUsersStream(String groupId) {
  return firestore
      .collection('study_groups')
      .doc(groupId)
      .collection('presence')
      .where('online', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc['userId']).toList());
}
```

**Firestore Data**:
```
study_groups/{groupId}/presence/{userId}
{
  'userId': 'user@example.com',
  'lastSeen': Timestamp(2026-05-13 14:30:45),
  'online': true
}
```

**UI Example**:
```dart
// Show online users in group detail
StreamBuilder<List<String>>(
  stream: collaborationProvider.watchGroupOnlineUsers(groupId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final onlineCount = snapshot.data!.length;
      return Text('$onlineCount online');
    }
    return Text('Loading...');
  },
)
```

---

## 5. Integration Checklist

### Phase 1: Data Models (✅ Complete)
- [x] `CommentModel` created
- [x] `StudyGroup` created
- [x] `NoteModel.tags` already exists
- [x] `NoteModel.sharedWith` already exists

### Phase 2: Backend Services (✅ Complete)
- [x] `CollaborationService` (sharing, comments, presence)
- [x] `StudyGroupService` (group CRUD, members, queries)
- [x] `TagQueryService` (tag management, compound queries)

### Phase 3: State Management (✅ Complete)
- [x] `CollaborationProvider` (provider pattern for UI)

### Phase 4: Firestore Indexes (⏳ To Do)
- [ ] Create indexes in Firebase Console (see `FIRESTORE_INDEXES.md`)
- [ ] Test queries with real data

### Phase 5: UI Implementation (⏳ To Do)
- [ ] Share note dialog (select recipient, choose access level)
- [ ] Comments thread view (display, reply, like, delete)
- [ ] Study group browser (search, join, create)
- [ ] Tag management interface (add/remove tags)
- [ ] Member management screen (add/remove/promote)
- [ ] Online users indicator (real-time presence)

### Phase 6: Integration Points (⏳ To Do)
- [ ] Add "Share" button to note detail screen
- [ ] Add "Comments" section to note viewer
- [ ] Add "Study Groups" tab to main navigation
- [ ] Add "Tags" sidebar for filtering
- [ ] Wire collaboration provider to app's main provider

---

## 6. Usage Examples

### Example 1: Share Note from Notes List
```dart
// In notes_list_screen.dart
ListTile(
  trailing: PopupMenuButton(
    itemBuilder: (_) => [
      PopupMenuItem(
        child: Text('Share'),
        onTap: () async {
          final email = await showShareDialog(context);
          if (email != null) {
            await collaborationProvider.shareNote(
              note.id,
              email,
              'comment',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Note shared!')),
            );
          }
        },
      ),
    ],
  ),
)
```

### Example 2: View Comments in Real-Time
```dart
// In note_detail_screen.dart
@override
void initState() {
  super.initState();
  collaborationProvider.addListener(_onCollaborationChange);
}

@override
Widget build(BuildContext context) {
  return StreamBuilder<List<CommentModel>>(
    stream: collaborationProvider.watchComments(widget.noteId),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return CommentsList(comments: snapshot.data!);
      }
      return CircularProgressIndicator();
    },
  );
}
```

### Example 3: Query Notes by Tag & Category
```dart
// In notes_filter_screen.dart
final notes = await tagQueryService.getNotesByTagAndCategory(
  'important',
  'lecture',
);

setState(() {
  _filteredNotes = notes;
});
```

### Example 4: Show Online Users in Group
```dart
// In group_detail_screen.dart
Padding(
  padding: EdgeInsets.all(8),
  child: StreamBuilder<List<String>>(
    stream: collaborationProvider.watchGroupOnlineUsers(groupId),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final onlineCount = snapshot.data!.length;
        return Chip(
          label: Text('$onlineCount online'),
          backgroundColor: Colors.green.shade100,
        );
      }
      return SizedBox.shrink();
    },
  ),
)
```

---

## 7. Performance Optimization

### Query Performance
- **Indexes**: All compound queries require indexes (see `FIRESTORE_INDEXES.md`)
- **Pagination**: Use `.limit(20).startAfter(lastDoc)` for large result sets
- **Caching**: Cache frequently-accessed tags and group memberships locally

### Comment Performance
- **Sub-collections**: Comments stored under `notes/{noteId}/comments` (avoids loading all comments on note load)
- **Real-time streams**: Use `.snapshots()` only for active screens
- **Pagination**: Load older comments on-demand (scrolling up)

### Tag Query Performance
- **Single-field queries**: `getNotesByTag()` is fast (uses indexes)
- **Multi-field queries**: `getNotesByTagAndCategory()` requires composite index
- **Client-side filtering**: AND queries do final filtering in Dart code

---

## 8. Migration Path

### From Existing System to Collaboration:

1. **Existing `NoteModel`**: Already has `tags` and `sharedWith` fields ✅
2. **Add Comments**: Enable sub-collection in Firestore + create indexes
3. **Add Study Groups**: Create `study_groups` collection + implement CRUD
4. **Backfill Data** (optional):
   - Migrate existing notes' access control to `sharedWith` field
   - Automatically tag notes based on content (AI analysis)

---

## 9. Error Handling

```dart
// In CollaborationService/StudyGroupService
try {
  await collaborationService.shareNote(...);
} on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    print('Access denied: ensure Firestore rules allow sharing');
  } else if (e.code == 'not-found') {
    print('Note or user not found');
  } else {
    print('Firestore error: $e');
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

---

## 10. Next Steps

1. **Deploy to Firebase**:
   - Update Firestore rules to allow sharing/comments
   - Create required composite indexes

2. **Build UI Screens**:
   - Share dialog with email input + access level selector
   - Comments view with real-time updates
   - Study group browser and creation screen
   - Tag management interface

3. **Wire Integration**:
   - Add `CollaborationProvider` to app's `MultiProvider`
   - Add Share/Comments buttons to existing screens
   - Add Study Groups tab to navigation

4. **Testing**:
   - Unit tests for service methods (tag queries, member management)
   - Integration tests for sharing workflows
   - E2E tests with multiple users

---

**Document Version**: 1.0  
**Last Updated**: May 13, 2026  
**Status**: Ready for implementation
