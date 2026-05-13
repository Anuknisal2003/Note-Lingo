# Firestore Indexes for Optimal Performance

This document lists the Firestore composite indexes needed for efficient queries in the Note-Lingo application.

## Overview

Firestore requires composite indexes for queries that filter on multiple fields or use specific combinations. These indexes must be created in the Firebase Console.

---

## Required Indexes

### 1. **Notes by User + Tag**
- **Collection**: `notes`
- **Fields**:
  - `userId` (Ascending)
  - `tags` (Ascending/Array)
  - `createdAt` (Descending)
- **Query Type**: Range + Array query
- **Used by**: `TagQueryService.getNotesByTag()`, `TagQueryService.getNotesByTagsAny()`
- **Purpose**: Retrieve user's notes filtered by tag(s) in reverse chronological order

```dart
// Example query
db.collection('notes')
  .where('userId', isEqualTo: uid)
  .where('tags', arrayContains: 'work')
  .orderBy('createdAt', descending: true)
  .get()
```

---

### 2. **Notes by User + Tag + Category**
- **Collection**: `notes`
- **Fields**:
  - `userId` (Ascending)
  - `tags` (Ascending/Array)
  - `category` (Ascending)
  - `createdAt` (Descending)
- **Query Type**: Range + Array + Equality
- **Used by**: `TagQueryService.getNotesByTagAndCategory()`
- **Purpose**: Filter notes by user, tag, and category

```dart
// Example query
db.collection('notes')
  .where('userId', isEqualTo: uid)
  .where('tags', arrayContains: 'review')
  .where('category', isEqualTo: 'lecture')
  .orderBy('createdAt', descending: true)
  .get()
```

---

### 3. **Notes by User + Tags (Multiple) + Date Range**
- **Collection**: `notes`
- **Fields**:
  - `userId` (Ascending)
  - `tags` (Ascending/Array)
  - `createdAt` (Ascending)
- **Query Type**: Range + Array + Range
- **Used by**: `TagQueryService.getNotesByTagsAndDateRange()`
- **Purpose**: Find notes within a date range with specific tags

```dart
// Example query
db.collection('notes')
  .where('userId', isEqualTo: uid)
  .where('tags', arrayContainsAny: ['important', 'review'])
  .where('createdAt', isGreaterThanOrEqualTo: startDate)
  .where('createdAt', isLessThanOrEqualTo: endDate)
  .orderBy('createdAt', descending: true)
  .get()
```

---

### 4. **Notes by User + IsFavorite + CreatedAt**
- **Collection**: `notes`
- **Fields**:
  - `userId` (Ascending)
  - `isFavorite` (Ascending)
  - `createdAt` (Descending)
- **Query Type**: Equality + Range
- **Used by**: `TagQueryService.getNotesByPriority()` (when sortBy='favorite')
- **Purpose**: Retrieve favorite notes in chronological order

```dart
// Example query
db.collection('notes')
  .where('userId', isEqualTo: uid)
  .where('isFavorite', isEqualTo: true)
  .orderBy('createdAt', descending: true)
  .get()
```

---

### 5. **Study Groups by Member**
- **Collection**: `study_groups`
- **Fields**:
  - `memberIds` (Ascending/Array)
- **Query Type**: Array-contains
- **Used by**: `StudyGroupService.getMyGroups()`
- **Purpose**: Find all groups a user is a member of

```dart
// Example query
db.collection('study_groups')
  .where('memberIds', arrayContains: uid)
  .get()
```

---

### 6. **Study Groups by Tags**
- **Collection**: `study_groups`
- **Fields**:
  - `tags` (Ascending/Array)
  - `createdAt` (Descending)
- **Query Type**: Array-contains-any + Range
- **Used by**: `StudyGroupService.searchByTags()`
- **Purpose**: Search groups by tag

```dart
// Example query
db.collection('study_groups')
  .where('tags', arrayContainsAny: ['math', 'physics'])
  .limit(20)
  .get()
```

---

### 7. **Comments by Note (Real-time)**
- **Collection**: `notes/{noteId}/comments`
- **Fields**:
  - `createdAt` (Ascending)
- **Query Type**: Single-field index (usually auto-generated)
- **Used by**: `CollaborationService.getCommentsStream()`
- **Purpose**: Stream comments in order

```dart
// Example query
db.collection('notes')
  .doc(noteId)
  .collection('comments')
  .orderBy('createdAt', descending: false)
  .snapshots()
```

---

## How to Create Indexes in Firebase Console

1. **Open Firebase Console** → Select your project
2. **Navigate to Firestore Database** → **Indexes** tab
3. **Click "Create Index"** and fill in:
   - Collection ID
   - Fields (in order, with Ascending/Descending)
   - Query Scope (Collection or Sub-collection)
4. **Click "Create"** and wait for the index to build (usually 5-10 minutes)

Alternatively, the **Firebase CLI** can auto-generate indexes:

```bash
# If you have firestore.indexes.json in your project:
firebase deploy --only firestore:indexes
```

---

## Firestore Index Status

| Index | Collection | Fields | Status | Notes |
|-------|-----------|--------|--------|-------|
| 1 | notes | userId + tags + createdAt | ⏳ To Create | Essential for tag filtering |
| 2 | notes | userId + tags + category + createdAt | ⏳ To Create | For compound tag/category queries |
| 3 | notes | userId + tags + createdAt (range) | ⏳ To Create | For date range + tag queries |
| 4 | notes | userId + isFavorite + createdAt | ⏳ To Create | For favorite notes sorting |
| 5 | study_groups | memberIds | ⏳ To Create | Auto-generated for array-contains |
| 6 | study_groups | tags + createdAt | ⏳ To Create | For tag-based group search |
| 7 | notes/{noteId}/comments | createdAt | ✅ Auto-generated | Single-field (usually auto) |

---

## Performance Considerations

### Without Indexes
- Single-field queries execute quickly (~10-100ms)
- Multi-field queries fail unless all fields are equality filters except the last one
- Sorting by multiple fields requires indexes

### With Indexes
- Multi-field queries execute in 10-100ms
- Real-time listeners (`.snapshots()`) are efficient
- Pagination works reliably

### Query Costs
- **Read operations**: Each document read = 1 read
- **Index maintenance**: Firestore auto-maintains indexes (costs included in normal pricing)
- **No additional charges** for having indexes

---

## Testing Indexes

After creating indexes, test with these Dart examples:

```dart
// Test: Notes by user + tag
final notes1 = await tagQueryService.getNotesByTag('work');

// Test: Notes by user + tag + category
final notes2 = await tagQueryService.getNotesByTagAndCategory('review', 'lecture');

// Test: Notes by user + tags + date range
final notes3 = await tagQueryService.getNotesByTagsAndDateRange(
  ['important'],
  DateTime.now().subtract(Duration(days: 30)),
  DateTime.now(),
);

// Test: Favorite notes
final notes4 = await tagQueryService.getNotesByPriority(sortBy: 'favorite');

// Test: User's study groups
final groups = await studyGroupService.getMyGroups();

// Test: Real-time comments
final commentsStream = collaborationService.getCommentsStream(noteId);
```

---

## Troubleshooting

### "Composite index not found" Error
- **Solution**: Create the index in Firebase Console (see "How to Create Indexes" above)
- **Alternative**: Use `arrayContainsAny` + client-side filtering for array queries

### Slow Query Performance
- **Check**: Is the index built? (Status shows in Firebase Console)
- **Check**: Is the index using correct field order? (Range filters must be last)
- **Solution**: Add covering indexes if needed (indexes with additional fields to avoid document reads)

### Missing Indexes After Deploy
- **Solution**: Run `firebase deploy --only firestore:indexes`
- **Verify**: Check indexes in Firebase Console under "Indexes" tab

---

## Reference

- [Firestore Indexes Documentation](https://firebase.google.com/docs/firestore/query-data/index-overview)
- [Firestore Query Limitations](https://firebase.google.com/docs/firestore/query-data/queries)
- [Best Practices for Firestore](https://firebase.google.com/docs/firestore/best-practices)
