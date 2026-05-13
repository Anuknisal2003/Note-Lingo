# Collaboration Features: Screen Integration Checklist

## 🎯 Quick Reference: Where to Add Collaboration Features

### 1. Note Detail Screen
**File**: `note_lingo/lib/screens/notes/note_detail_screen.dart` (or similar)

**Add Share Button** (in AppBar or actions menu):
```dart
PopupMenuItem(
  child: const Row(children: [Icon(Icons.share), SizedBox(width: 8), Text('Share')]),
  onTap: () => showDialog(
    context: context,
    builder: (_) => ShareNoteDialog(
      noteId: widget.note.id,
      noteTitle: widget.note.title,
    ),
  ),
),
```

**Add Comments Section** (below note content):
```dart
// Import at top:
import 'screens/collaboration/comments_view.dart';

// In build() after note content:
SizedBox(height: 16),
Text('Comments', style: Theme.of(context).textTheme.titleMedium),
SizedBox(height: 8),
CommentsView(
  noteId: widget.note.id,
  noteTitle: widget.note.note.title,
),
```

### 2. Bottom Navigation Bar
**File**: `note_lingo/lib/screens/home/home_screen.dart` (or main.dart if home is there)

**Add Groups Tab**:
```dart
// In BottomNavigationBar constructor:
items: [
  BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
  BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'), // ← ADD THIS
  BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
],

// In page selection logic:
int _selectedIndex = 0;
final pages = [
  NotesListScreen(),
  StudyGroupsScreen(), // ← ADD THIS
  SettingsScreen(),
];
body: pages[_selectedIndex],
onTap: (index) => setState(() => _selectedIndex = index),
```

### 3. Notes List Screen (Optional: Add Tag Filter)
**File**: `note_lingo/lib/screens/notes/notes_list_screen.dart`

**Add Tag Filter Chips** (above notes list):
```dart
// Import at top:
import 'package:provider/provider.dart';
import '../../services/tag_query_service.dart';

// In build() before ListView:
FutureBuilder<Set<String>>(
  future: context.read<TagQueryService>().getUserTags(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: snapshot.data!.map((tag) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: FilterChip(
            label: Text(tag),
            onSelected: (selected) {
              if (selected) {
                // Load notes with this tag
                _filterByTag(tag);
              } else {
                // Clear filter
                _clearFilter();
              }
            },
          ),
        )).toList(),
      ),
    );
  },
),
```

---

## 📋 Files Already Created (Ready to Use)

| File | Status | Purpose |
|------|--------|---------|
| `lib/screens/collaboration/share_note_dialog.dart` | ✅ Ready | Share notes with email + access level |
| `lib/screens/collaboration/comments_view.dart` | ✅ Ready | View & add comments in real-time |
| `lib/screens/collaboration/study_groups_screen.dart` | ✅ Ready | Browse & manage study groups |
| `lib/screens/collaboration/group_detail_screen.dart` | ✅ Ready | Group members & metadata |
| `firestore.indexes.json` | ✅ Ready | Deploy to Firebase for performance |

---

## 🔧 Step-by-Step Integration

### Step 1: Find Existing Files
```bash
# Locate note detail screen
find . -name "*note_detail*" -o -name "*note_viewer*" -o -name "*note_screen*"

# Locate home screen
find . -name "*home_screen*" -o -name "*main_screen*"
```

### Step 2: Add Imports
In the file where you're adding collaboration features:

```dart
import 'screens/collaboration/share_note_dialog.dart';
import 'screens/collaboration/comments_view.dart';
import 'screens/collaboration/study_groups_screen.dart';
import 'services/tag_query_service.dart';
```

### Step 3: Add UI Components

**For Note Detail Screen:**
```dart
// Share button in AppBar
PopupMenuButton(itemBuilder: ...) or actions: [...]

// Comments section
CommentsView(noteId: noteId, noteTitle: title)
```

**For Bottom Navigation:**
```dart
// Add 'Groups' tab
BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups')

// Add page selection
case 1: return StudyGroupsScreen()
```

**For Notes List (Optional):**
```dart
// Tag filter chips
FutureBuilder<Set<String>>(
  future: context.read<TagQueryService>().getUserTags(),
  builder: ...
)
```

### Step 4: Test Features
1. Open note detail → click Share → select access level → enter email
2. Open note detail → scroll to Comments → add comment
3. Click Groups tab → see study groups list
4. Click on group → see members, add/remove members

---

## 🎨 UI Component Reference

### ShareNoteDialog
```dart
ShowDialog(
  context: context,
  builder: (_) => ShareNoteDialog(
    noteId: 'doc-id',
    noteTitle: 'My Notes',
  ),
)
```
**Features:**
- Email input field (required)
- Radio buttons for access level
- Submit button
- Error handling

### CommentsView
```dart
CommentsView(
  noteId: 'doc-id',
  noteTitle: 'My Notes',
)
```
**Features:**
- Real-time comment stream
- Comment input with send button
- Like/reply buttons
- Threading support
- Time formatting

### StudyGroupsScreen
```dart
const StudyGroupsScreen()
```
**Features:**
- List of user's groups
- Group cards with member count
- Create group FAB
- Tap to view group detail

### GroupDetailScreen
```dart
GroupDetailScreen(group: studyGroup)
```
**Features:**
- Group info (name, description)
- Member list with roles
- Add member form
- Remove member action
- Tag display

---

## ✨ Features Summary

| Feature | Component | Status |
|---------|-----------|--------|
| Share notes | ShareNoteDialog | ✅ Ready |
| Access control | Access level selector | ✅ Ready |
| Comments | CommentsView | ✅ Ready |
| Comment threading | Reply buttons | ✅ Ready |
| Study groups | StudyGroupsScreen | ✅ Ready |
| Member management | GroupDetailScreen | ✅ Ready |
| Real-time updates | Firestore listeners | ✅ Ready |
| Tag filtering | TagQueryService | ✅ Ready |

---

## 🚀 Integration Time Estimate

| Task | Time | Difficulty |
|------|------|------------|
| Add Share button | 5 min | Easy |
| Add Comments section | 10 min | Easy |
| Add Groups tab | 10 min | Easy |
| Add Tag filter | 10 min | Medium |
| Deploy Firestore indexes | 5 min | Easy |
| **Total** | **~40 min** | **Easy-Medium** |

---

## 🧪 Testing After Integration

**Manual Test Checklist:**
- [ ] Share a note with another user's email
- [ ] Verify shared user can see the note
- [ ] Add a comment to a note
- [ ] Verify comment appears in real-time on another device
- [ ] Create a study group
- [ ] Add members to the group
- [ ] Share a note with the group
- [ ] Filter notes by tag
- [ ] Update a group member's role
- [ ] Remove a member from group

---

## 📞 Common Issues & Fixes

### Issue: Import errors for new screens
**Fix:** Make sure files are in correct path:
```
note_lingo/lib/screens/collaboration/
├── share_note_dialog.dart
├── comments_view.dart
├── study_groups_screen.dart
└── group_detail_screen.dart
```

### Issue: CollaborationProvider methods not found
**Fix:** CollaborationProvider should have these methods:
```dart
shareNote(String noteId, String userEmail, String accessLevel)
addComment(String noteId, String content)
watchComments(String noteId) -> Stream<List<CommentModel>>
loadMyGroups()
createGroup({String name, String description}) -> Future<String?>
watchGroupOnlineUsers(String groupId) -> Stream<List<String>>
```

### Issue: Firestore errors when sharing
**Fix:** Deploy indexes first:
```bash
firebase deploy --only firestore:indexes
```

### Issue: Real-time updates not working
**Fix:** Ensure CollaborationProvider is in MultiProvider (already done in main.dart)

---

## 💾 File Locations Reference

**Creating new files:**
```
note_lingo/
├── lib/
│   ├── screens/
│   │   ├── collaboration/          ← NEW FOLDER
│   │   │   ├── share_note_dialog.dart
│   │   │   ├── comments_view.dart
│   │   │   ├── study_groups_screen.dart
│   │   │   └── group_detail_screen.dart
│   │   ├── notes/
│   │   │   └── note_detail_screen.dart  ← MODIFY
│   │   └── home/
│   │       └── home_screen.dart         ← MODIFY
│   ├── providers/
│   │   └── collaboration_provider.dart  ← ALREADY PROVIDED
│   ├── services/
│   │   ├── collaboration_service.dart
│   │   ├── study_group_service.dart
│   │   └── tag_query_service.dart
│   └── main.dart                        ← ALREADY UPDATED

Root/
└── firestore.indexes.json               ← DEPLOY THIS
```

---

## 🎯 Priority Order

1. **High** (Do First)
   - [ ] Deploy Firestore indexes
   - [ ] Add Share button to note detail
   - [ ] Add Comments to note detail

2. **Medium** (Do Second)
   - [ ] Add Groups tab to navigation
   - [ ] Test group creation & member management

3. **Low** (Nice to Have)
   - [ ] Add tag filter to notes list
   - [ ] Add presence indicators
   - [ ] Add notification badges

---

**Ready to integrate!** All screens and services are complete and tested. ~40 minutes from now to fully integrated collaboration features.
