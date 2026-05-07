# Note-Lingo Project — Comprehensive Feature Analysis

**Analysis Date:** May 7, 2026  
**Overall Project Completion:** ~65% (Core features working, many advanced features missing)

---

## 1. Core Architecture: 85% COMPLETE ✅

### Main Entry Point
- **File:** [lib/main.dart](lib/main.dart)
- **Status:** ✅ COMPLETE
  - Firebase initialization with DefaultFirebaseOptions
  - Provider setup (auth, notes, recording, language)
  - Localization support (en, si, ta)
  - System UI styling configured
  - Portrait-only orientation enforced

### Providers (State Management)
- **Directory:** [lib/providers/](lib/providers/)
- **Status:** ✅ 85% COMPLETE
  - **auth_provider.dart** (✅ COMPLETE)
    - Email/password sign-in, register
    - Google Sign-In integration
    - Password reset & change
    - Profile management
    - Onboarding flag tracking
  - **notes_provider.dart** (✅ 90% COMPLETE)
    - CRUD operations (create, read, update, delete)
    - Real-time Firestore stream listening
    - Search/filter functionality
    - Favorite toggling
    - Export functionality
    - ⚠️ Missing: Analytics (word frequency stats, note heatmaps, progress tracking)
  - **recording_provider.dart** (✅ 85% COMPLETE)
    - Audio recording (start, pause, stop)
    - Transcription & summarization pipeline
    - Local AI service integration
    - Category & language selection
    - Upload progress tracking
    - ⚠️ Missing: Batch processing, draft saving, recording resumption
  - **language_provider.dart** (✅ COMPLETE)
    - Language persistence (shared preferences)
    - Support for en, si, ta

### Models
- **Directory:** [lib/models/](lib/models/)
- **Status:** ✅ 90% COMPLETE
  - **note_model.dart** (✅ 90% COMPLETE)
    - Full Firestore serialization
    - 5 categories (lecture, meeting, interview, personal, other)
    - Fields: id, userId, title, transcription, summary, language, keywords, audioUrl, timestamps, wordCount, duration, isFavorite
    - ⚠️ Missing: sentiment score, speaker labels, question-answer pairs, related_note_ids, tags, collaboration fields
  - **user_model.dart** (✅ COMPLETE)
    - uid, name, email, role, photoUrl, timestamps
    - Full Firestore serialization & copyWith

### Services
- **Directory:** [lib/services/](lib/services/)
- **Status:** ✅ 80% COMPLETE
  - **firestore_service.dart** (✅ 90% COMPLETE)
    - User profile CRUD
    - Notes CRUD
    - Real-time streams
    - Favorite toggle
    - ⚠️ Missing: Batch operations, transaction support, advanced querying (tags, collaboration)
  - **ai_service.dart** (✅ 75% COMPLETE)
    - Whisper transcription (OpenAI API)
    - GPT-4o summarization
    - Language-aware prompting
    - ⚠️ Missing: Fallback mechanisms, retry logic, offline support
  - **local_ai_service.dart** (✅ 85% COMPLETE)
    - Local Whisper transcription via Flask
    - Custom BART summarization
    - Structured SummaryResult parsing
    - Base URL discovery (emulator + LAN candidates)
    - ⚠️ Missing: Error recovery, model downgrade for low-resource scenarios
  - **storage_service.dart** (✅ 90% COMPLETE)
    - Audio file upload to Firebase Storage
    - Progress callbacks
    - URL generation & deletion
    - Metadata tagging
  - **export_service.dart** (✅ 90% COMPLETE)
    - PDF export with styled formatting
    - DOCX export (Word-compatible)
    - TXT export (plain text)
    - ⚠️ Missing: HTML export, batch export, cloud sync

---

## 2. Authentication: 90% COMPLETE ✅

### Sign-In Methods
- **Email/Password:** ✅ Fully implemented
- **Google Sign-In:** ✅ Fully implemented
- **OAuth Providers:** ❌ MISSING (Apple, Facebook, Microsoft)

### Auth Features
- ✅ Registration with role selection (Student, Professional, Researcher, Other)
- ✅ Password reset
- ✅ Password change with re-authentication
- ✅ Profile editing
- ✅ Sign-out with provider cleanup
- ✅ Auth state persistence
- ✅ Onboarding tracking
- ❌ MISSING: 2FA, social login providers, SSO

### Firebase Setup
- **Files:** [lib/firebase_options.dart](lib/firebase_options.dart) (Auto-generated)
- ✅ Android, iOS, Web, macOS, Windows configured
- ✅ All Firebase SDKs initialized (Auth, Firestore, Storage)

---

## 3. Recording & AI: 85% COMPLETE ✅

### Recording UI & Logic
- **File:** [lib/screens/recording/recording_screen.dart](lib/screens/recording/recording_screen.dart)
- **Status:** ✅ 90% COMPLETE
  - ✅ Visual pulse & wave animations
  - ✅ Category selection (lecture, meeting, interview, personal, other)
  - ✅ Real-time timer display
  - ✅ Pause/resume with confirmation dialogs
  - ✅ Processing progress visualization
  - ✅ Error handling with user-friendly messages
  - ✅ Language selection integration
  - ⚠️ Missing: Voice activity detection (VAD), ambient noise cancellation, recording quality selector

### Recording Provider Processing
- **File:** [lib/providers/recording_provider.dart](lib/providers/recording_provider.dart)
- **Pipeline:** Record → Transcribe → Summarize → Save
- ✅ All 4 steps with progress tracking
- ✅ Local AI fallback summary if API fails
- ✅ Title extraction from transcript
- ✅ Keyword extraction
- ✅ Category-aware summarization
- ⚠️ Missing: Draft saving, offline recording queue, batch processing

### AI Services
- **Local AI:** [lib/services/local_ai_service.dart](lib/services/local_ai_service.dart)
  - ✅ Whisper transcription (via Flask)
  - ✅ Custom BART summarization (structured output)
  - ✅ Base URL auto-discovery (10.0.2.2, 127.0.0.1, LAN IP)
  - ⚠️ Issues: Single hardcoded LAN IP (172.20.10.4), no persistent caching

- **OpenAI Service:** [lib/services/ai_service.dart](lib/services/ai_service.dart)
  - ✅ Whisper API integration
  - ✅ GPT-4o summarization
  - ✅ Language-specific prompts
  - ⚠️ Missing: Streaming responses, cost tracking, quota management

### Python Backend
- **Flask API:** [ai_note_model/flask_api/app.py](ai_note_model/flask_api/app.py)
- **Status:** ✅ 85% COMPLETE (Core endpoints working)
  - ✅ `/health` — server status
  - ✅ `/transcribe` — Whisper audio → text
  - ✅ `/summarise` — BART text → structured summary
  - ⚠️ Missing: `/extract_qa`, `/detect_sentiment`, `/speaker_diarization`, `/related_notes`
  - ⚠️ Performance: No caching, model loading on startup (slow)

---

## 4. Database: 85% COMPLETE ✅

### Firestore Structure
- **Collections:**
  - ✅ `users` — User profiles (uid, name, email, role, photoUrl, timestamps)
  - ✅ `notes` — Notes (id, userId, title, transcription, summary, language, category, keywords, audioUrl, wordCount, duration, isFavorite, timestamps)
  - ❌ `shared_notes` — MISSING (for collaboration)
  - ❌ `comments` — MISSING (for discussions)
  - ❌ `study_groups` — MISSING (for collaboration)
  - ❌ `tags` — MISSING (for smart organization)

### Firestore Operations
- [lib/services/firestore_service.dart](lib/services/firestore_service.dart) — ✅ 85% COMPLETE
  - ✅ User CRUD + streams
  - ✅ Notes CRUD + real-time stream
  - ✅ Favorite toggle
  - ⚠️ Missing: Batch writes, transactions, compound queries (e.g., notes by tag + category)
  - ⚠️ Issue: Requires composite index for `userId + createdAt` orderBy queries

### Firebase Storage
- [lib/services/storage_service.dart](lib/services/storage_service.dart) — ✅ 90% COMPLETE
  - ✅ Audio upload with progress tracking
  - ✅ Audio deletion
  - ✅ Custom metadata (userId, noteId, uploadedAt)
  - ⚠️ Missing: Compression, transcoding, lifecycle policies

---

## 5. Existing Screens: 80% COMPLETE ✅

### Screen Inventory

| Screen | File | Status | Notes |
|--------|------|--------|-------|
| **Splash** | [splash_screen.dart](lib/screens/splash_screen.dart) | ✅ COMPLETE | Auth routing, onboarding check |
| **Onboarding** | [screens/onboarding/onboarding_screen.dart](lib/screens/onboarding/onboarding_screen.dart) | ✅ COMPLETE | 3-page carousel with animations |
| **Login** | [screens/auth/login_screen.dart](lib/screens/auth/login_screen.dart) | ✅ 90% COMPLETE | Email + Google sign-in, password reset link |
| **Register** | [screens/auth/register_screen.dart](lib/screens/auth/register_screen.dart) | ✅ 90% COMPLETE | Email registration with role selection |
| **Home** | [screens/home/home_screen.dart](lib/screens/home/home_screen.dart) | ✅ 85% COMPLETE | Recent notes grid, search, bottom nav (Home/Library/Profile), FAB recording |
| **Recording** | [screens/recording/recording_screen.dart](lib/screens/recording/recording_screen.dart) | ✅ 90% COMPLETE | Visual recording with animations, category/language selection, pause/stop |
| **Note Detail** | [screens/note_detail/note_detail_screen.dart](lib/screens/note_detail/note_detail_screen.dart) | ✅ 85% COMPLETE | 3 tabs (Summary/Transcript/Details), edit mode, favorite, delete |
| **Notes Library** | [screens/library/notes_library_screen.dart](lib/screens/library/notes_library_screen.dart) | ⚠️ 70% COMPLETE | List view with filters, missing: sort options, folder view, batch operations |
| **Profile** | [screens/profile/profile_screen.dart](lib/screens/profile/profile_screen.dart) | ✅ 85% COMPLETE | User info, stats (total notes, favorites, study time), settings, sign-out |
| **Export** | [screens/export/export_screen.dart](lib/screens/export/export_screen.dart) | ✅ 85% COMPLETE | PDF/DOCX/TXT format selection, section toggles, progress indicator |

---

## 6. Existing Features: 75% COMPLETE ✅

### ✅ IMPLEMENTED FEATURES

**Recording & Processing:**
- ✅ Real-time audio recording with timer
- ✅ Pause/resume with confirmation
- ✅ Automatic transcription (Whisper)
- ✅ Automatic summarization (BART)
- ✅ Category assignment
- ✅ Language selection (en, si, ta)
- ✅ Title auto-generation from transcript
- ✅ Keyword extraction

**Note Management:**
- ✅ View all notes with real-time sync
- ✅ Search notes (title, summary, transcript, keywords)
- ✅ Mark as favorite
- ✅ Edit title & transcript
- ✅ Delete notes + audio cleanup
- ✅ Sort by date
- ✅ View creation/update timestamps

**Export:**
- ✅ PDF export with styled formatting (logo, colors, sections)
- ✅ DOCX export (Word-compatible)
- ✅ TXT export (plain text)
- ✅ Share via system share sheet

**User Management:**
- ✅ Email/password authentication
- ✅ Google Sign-In
- ✅ User profile editing
- ✅ Password reset & change
- ✅ Sign-out

**UI/UX:**
- ✅ Dark theme with gradient backgrounds
- ✅ Animations (pulse, wave, orbs)
- ✅ Bottom tab navigation
- ✅ Tab-based note detail view
- ✅ Responsive design
- ✅ Loading states & progress indicators
- ✅ Error messages & retry

### ⚠️ INCOMPLETE/STUBBED FEATURES

- ⚠️ **Local AI server connectivity**: Base URL hardcoded to 172.20.10.4, should use environment variable
- ⚠️ **Batch note operations**: No multi-select delete, bulk export
- ⚠️ **Draft saving**: No ability to save partial recordings
- ⚠️ **Recording resumption**: Cannot pause recording longer than current session
- ⚠️ **Offline mode**: No offline recording queue or sync
- ⚠️ **Note privacy levels**: No public/private/shared toggles
- ⚠️ **Advanced filtering**: Only title/content search, no category/date range filters

---

## 7. AI Features: 50% COMPLETE ❌

### ✅ IMPLEMENTED
- ✅ **Transcription** — Whisper (OpenAI or local Flask)
- ✅ **Summarization** — BART (structured: title, overview, key points, conclusion, keywords)
- ✅ **Keyword extraction** — Simple regex + BART output parsing
- ✅ **Title generation** — From first sentence or summary

### ❌ MISSING (NOT IMPLEMENTED)

| Feature | API Available? | Status |
|---------|---|---|
| **Sentiment Analysis** | ❌ | Not in Flask API, no model trained |
| **Speaker Diarization** | ❌ | No speaker separation |
| **Q&A Extraction** | ❌ | No endpoint, no dataset |
| **Entity Recognition** | ❌ | No NER model |
| **Topic Detection** | ❌ | Only basic category assignment |
| **Automatic Tagging** | ❌ | No tag generation |
| **Related Notes** | ❌ | No similarity search, no embeddings |
| **Fact Checking** | ❌ | No external fact verification |
| **Lecture/Meeting Detection** | ⚠️ Partial | Category must be manual selected |

### Python Models Available
- **Files:** [ai_note_model/](ai_note_model/)
  - ✅ Wav2Vec2 fine-tuning script ([scripts/3_train_model.py](ai_note_model/scripts/3_train_model.py))
  - ✅ BART summarizer training ([scripts/1_train_summarizer.py](ai_note_model/scripts/1_train_summarizer.py))
  - ⚠️ Missing: Sentiment, diarization, QA models
  - ⚠️ Missing: Evaluation metrics, model versioning

---

## 8. Multilingual Support: 75% COMPLETE ✅

### ✅ IMPLEMENTED
- ✅ **Language Codes:** English (en), Sinhala (si), Tamil (ta)
- ✅ **Whisper Support:** All three languages mapped in AppConstants
- ✅ **User Selection:** LanguageProvider with persistence
- ✅ **Recording Language:** Passed to transcription API
- ✅ **Localization Delegates:** Flutter material/widget/cupertino localizations
- ✅ **BART Prompts:** Language-aware summaries ("Respond in Tamil", etc.)

### ⚠️ INCOMPLETE
- ⚠️ **App UI Translation:** No i18n file structure (no .arb files), only hardcoded English UI
- ⚠️ **Date Formatting:** Uses IntlFormat but no locale-specific patterns
- ⚠️ **Keyboard Layout:** No per-language input switching
- ⚠️ **RTL Support:** No right-to-left language support

---

## 9. Smart Organization: 20% COMPLETE ❌

### ❌ COMPLETELY MISSING
- ❌ **Smart Folders** — No automatic folder creation based on topic/time/source
- ❌ **Auto-Tagging** — No AI-generated tags
- ❌ **Related Notes Suggestions** — No semantic similarity or clustering
- ❌ **Pinning** — No pin/unpin feature
- ❌ **Nested Folders** — Flat structure only
- ❌ **Label/Tag System** — No custom tag model
- ❌ **Smart Views** — No "By Tag", "By Date Range", "By Source" views

### ✅ PARTIALLY IMPLEMENTED
- ⚠️ **Categories** — 5 fixed categories (lecture, meeting, interview, personal, other), not editable
- ⚠️ **Search** — Basic text search only, no advanced filters

---

## 10. Collaboration: 0% COMPLETE ❌

### COMPLETELY MISSING
- ❌ **Shared Notes** — No sharing mechanism
- ❌ **Comments/Discussions** — No comment threads
- ❌ **Study Groups** — No group creation or management
- ❌ **Permissions** — No access control (read, write, admin)
- ❌ **Activity Feed** — No "who did what when" logging
- ❌ **Real-time Collaboration** — No live editing
- ❌ **Invite System** — No user invitations

### Database Missing
- ❌ `shared_notes` collection
- ❌ `comments` collection
- ❌ `study_groups` collection
- ❌ Sharing permissions fields

---

## 11. Analytics: 25% COMPLETE ⚠️

### ✅ PARTIALLY IMPLEMENTED
- ⚠️ **Basic Stats** — [screens/profile/profile_screen.dart](lib/screens/profile/profile_screen.dart) shows:
  - Total notes count
  - Favorite notes count
  - Total minutes calculated
  - ⚠️ Code exists but data not fully populated

### ❌ MISSING
- ❌ **Word Frequency** — No word cloud, no term frequency analysis
- ❌ **Recording Heatmap** — No time-of-day activity chart
- ❌ **Progress Tracking** — No charts showing notes/day, study time trends
- ❌ **Category Distribution** — No pie/bar chart by category
- ❌ **Engagement Metrics** — No most-reviewed notes, session duration
- ❌ **Export Analytics** — No analytics report export
- ❌ **Dashboard** — No analytics dashboard screen

### Analytics Infrastructure Missing
- ❌ No analytics database schema
- ❌ No aggregation queries
- ❌ No charting library (could use `fl_chart`, `charts_flutter`)

---

## 12. Export: 85% COMPLETE ✅

### ✅ IMPLEMENTED
- ✅ **PDF Export** — Styled with colors, metadata, all sections
  - [lib/services/export_service.dart](lib/services/export_service.dart) — Full implementation
  - Includes logo, borders, summaries, transcripts, keywords, metadata
- ✅ **DOCX Export** — Word-compatible RTF format
- ✅ **TXT Export** — Plain text with structured sections
- ✅ **Share Sheet** — System share integration
- ✅ **Section Toggles** — User can include/exclude summary, transcript, keywords, metadata

### ⚠️ INCOMPLETE
- ⚠️ **HTML Export** — No HTML option
- ⚠️ **Markdown Export** — No .md format
- ⚠️ **Batch Export** — Can't export multiple notes at once
- ⚠️ **Cloud Export** — No Google Drive, OneDrive sync
- ⚠️ **Email Export** — No direct email option
- ⚠️ **Custom Templates** — Fixed template only

---

## 13. Missing Dependencies: 0% ISSUES ✅

### All Required Dependencies Installed ✅
- [pubspec.yaml](note_lingo/pubspec.yaml) has all needed packages:
  - Firebase (core, auth, firestore, storage)
  - Provider (state management)
  - Audio (record, just_audio)
  - HTTP (http package)
  - Localization (flutter_localizations, intl)
  - Export (pdf, share_plus)
  - UI (google_fonts, flutter_animate)
  - Utilities (uuid, path_provider, shared_preferences, connectivity_plus)
  - Google Sign-In (google_sign_in)
  - Environment (flutter_dotenv)

### Suggested Optional Additions (For Missing Features)
- ❌ `fl_chart` — For analytics charts (word frequency, heatmap, progress)
- ❌ `connectivity_plus` — Already installed, good for offline detection
- ❌ `sqflite` — For offline note caching
- ❌ `hive` — For local AI settings persistence
- ❌ `get_it` — For service locator (optional, but cleaner than singletons)
- ❌ `audio_waveforms` — For waveform visualization during recording
- ❌ `vector_math` — For advanced animations

---

## 14. Connectivity Issues: 60% FUNCTIONAL ⚠️

### Current Status

**Local AI Service Base URL Discovery:**
- **File:** [lib/services/local_ai_service.dart](lib/services/local_ai_service.dart)
- **Status:** ⚠️ Partially working, fragile

### ✅ WORKING
- ✅ Emulator fallback: `10.0.2.2:5000` for Android emulator
- ✅ Localhost candidates: `127.0.0.1:5000`, `localhost:5000`
- ✅ Auto-detection: Pings `/health` endpoint to validate connectivity
- ✅ Configurable via `--dart-define=LOCAL_AI_BASE_URL=http://<ip>:5000`

### ⚠️ ISSUES
- ⚠️ **Hardcoded LAN IP:** `172.20.10.4:5000` is hardcoded in the candidate list
  - **Impact:** Works only on that specific network
  - **Fix needed:** Use dynamic network discovery or .env file

- ⚠️ **No Fallback to OpenAI:** If local server fails, app fails entirely
  - **Expected:** Should fall back to OpenAI API via `ai_service.dart`
  - **Fix needed:** Add fallback logic in recording_provider

- ⚠️ **No Connection Caching:** Rediscovers server on each request
  - **Impact:** Slower performance, repeated HTTP pings
  - **Fix needed:** Cache `_activeBaseUrl` across app sessions

- ⚠️ **No Offline Queueing:** If server is down, notes are lost
  - **Expected:** Queue should save to local storage for later sync
  - **Fix needed:** Implement local recording queue (SQLite/Hive)

- ⚠️ **Flask Server Not Always Running:**
  - **Current Status:** Requires manual `py -3.11 flask_api/app.py`
  - **Expected:** Should start automatically or via Docker
  - **Fix needed:** Docker containerization or background service

### Network Architecture Issues

```
Current Flow (Works when everything is running):
  Phone (Recording) 
    → Local WiFi 
    → PC:5000 (Flask)
    → Whisper + BART

Issues:
1. Flask server must be manually started
2. Base URL must match network IP (currently hardcoded)
3. No fallback if local server down (should use OpenAI)
4. No offline queue if connectivity lost
5. No connection persistence/caching
```

---

## Feature Completion Summary

| Category | Completion | Status |
|----------|-----------|--------|
| Core Architecture | 85% | ✅ Working well |
| Authentication | 90% | ✅ Complete |
| Recording & AI | 85% | ✅ Core features working |
| Database | 85% | ✅ CRUD + streams working |
| Screens | 80% | ✅ 9/10 screens implemented |
| Basic Features | 75% | ✅ Recording, export, auth working |
| AI Features | 50% | ⚠️ Only transcription + summarization |
| Multilingual | 75% | ✅ Languages supported, UI not translated |
| Smart Organization | 20% | ❌ Only basic categories |
| Collaboration | 0% | ❌ Not implemented |
| Analytics | 25% | ⚠️ Stub code only |
| Export | 85% | ✅ PDF, DOCX, TXT working |
| Dependencies | 100% | ✅ All installed |
| Connectivity | 60% | ⚠️ Works but fragile |
| **OVERALL** | **~65%** | **✅ Core functional, needs polish** |

---

## Critical Next Steps (Priority Order)

### 🔴 P1 — CRITICAL (Blocks Usage)
1. **Fix Local AI Base URL** — Replace hardcoded `172.20.10.4` with environment variable
2. **Add Fallback to OpenAI** — If local server unavailable, use OpenAI API
3. **Offline Recording Queue** — Queue notes when connectivity lost

### 🟠 P2 — HIGH (Major Features Missing)
1. **Smart Tagging System** — Add auto-tags from summary keywords
2. **Advanced Search** — Filter by date, category, tags
3. **Related Notes** — Show semantic similarity suggestions
4. **Analytics Dashboard** — Word frequency, study time heatmap, progress charts
5. **App UI Localization** — Translate UI to Sinhala & Tamil

### 🟡 P3 — MEDIUM (Nice-to-Have)
1. **Collaboration** — Share notes, comments, study groups
2. **Sentiment Analysis** — Mood detection from audio
3. **Speaker Diarization** — Identify multiple speakers
4. **Q&A Extraction** — Extract questions & answers from lectures
5. **Batch Operations** — Multi-select delete, bulk export
6. **Offline Mode** — Full app functionality without internet

### 🟢 P4 — LOW (Polish)
1. **Voice Activity Detection** — Skip silence in recordings
2. **Recording Quality Selector** — Bitrate/sample rate options
3. **Custom Export Templates** — User-defined PDF/DOCX layouts
4. **Docker containerization** — Easy Flask server deployment
5. **Performance optimization** — Model caching, lazy loading

---

## File Location Index

### Core
- Main: [lib/main.dart](lib/main.dart)
- Theme: [lib/core/theme/](lib/core/theme/)
- Constants: [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart)

### Providers
- Auth: [lib/providers/auth_provider.dart](lib/providers/auth_provider.dart)
- Notes: [lib/providers/notes_provider.dart](lib/providers/notes_provider.dart)
- Recording: [lib/providers/recording_provider.dart](lib/providers/recording_provider.dart)
- Language: [lib/providers/language_provider.dart](lib/providers/language_provider.dart)

### Services
- Firestore: [lib/services/firestore_service.dart](lib/services/firestore_service.dart)
- Local AI: [lib/services/local_ai_service.dart](lib/services/local_ai_service.dart)
- OpenAI: [lib/services/ai_service.dart](lib/services/ai_service.dart)
- Storage: [lib/services/storage_service.dart](lib/services/storage_service.dart)
- Export: [lib/services/export_service.dart](lib/services/export_service.dart)

### Models
- Note: [lib/models/note_model.dart](lib/models/note_model.dart)
- User: [lib/models/user_model.dart](lib/models/user_model.dart)

### Screens
- Splash: [lib/screens/splash_screen.dart](lib/screens/splash_screen.dart)
- Onboarding: [lib/screens/onboarding/onboarding_screen.dart](lib/screens/onboarding/onboarding_screen.dart)
- Auth: [lib/screens/auth/](lib/screens/auth/)
- Home: [lib/screens/home/home_screen.dart](lib/screens/home/home_screen.dart)
- Recording: [lib/screens/recording/recording_screen.dart](lib/screens/recording/recording_screen.dart)
- Note Detail: [lib/screens/note_detail/note_detail_screen.dart](lib/screens/note_detail/note_detail_screen.dart)
- Library: [lib/screens/library/notes_library_screen.dart](lib/screens/library/notes_library_screen.dart)
- Profile: [lib/screens/profile/profile_screen.dart](lib/screens/profile/profile_screen.dart)
- Export: [lib/screens/export/export_screen.dart](lib/screens/export/export_screen.dart)

### Python Backend
- Flask API: [ai_note_model/flask_api/app.py](ai_note_model/flask_api/app.py)
- Training Scripts: [ai_note_model/scripts/](ai_note_model/scripts/)

