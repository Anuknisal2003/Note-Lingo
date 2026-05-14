# Note Lingo — Full Technical Report

> Generated: May 14, 2026

---

## 1. Overview

**Note Lingo** is a cross-platform, AI-powered note generation mobile application built with Flutter. It targets students, professionals, and researchers who need to convert voice recordings into structured, intelligent notes. The app supports multilingual speech, delivers on-device and cloud AI processing, and combines smart organization with usage analytics — all backed by Firebase.

---

## 2. Platform & Framework

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.x / Dart SDK ^3.11.0 |
| Target Platforms | Android, iOS (Windows / Linux / macOS / Web stubs present) |
| State Management | Provider ^6.1.2 — MultiProvider pattern |
| Backend / Database | Firebase (Firestore, Auth, Storage) |
| Local AI Server | Python 3.11 + Flask REST API |
| Orientation | Portrait-only; system UI overlay customized |

---

## 3. Architecture

### 3.1 App Entry Point (`main.dart`)

```
main()
 ├─ dotenv.load()           → loads API keys from assets/.env
 ├─ Firebase.initializeApp()
 ├─ SystemChrome styles     → transparent status bar, dark icons
 ├─ setPreferredOrientations → portrait only
 └─ runApp(NoteLingo)
      └─ MultiProvider (7 providers)
           └─ MaterialApp (dark theme, 3 locales)
                └─ SplashScreen → auth routing → HomeScreen
```

### 3.2 Providers (State Management Layer)

| Provider | Responsibility |
|---|---|
| `AuthProvider` | Firebase Auth + Google Sign-In, onboarding flag |
| `NotesProvider` | Firestore CRUD for notes, search, favorites |
| `RecordingProvider` | Record → transcribe → summarize pipeline, offline queue |
| `LanguageProvider` | App-wide language switching, SharedPreferences persistence |
| `AiEnhancementsProvider` | Sentiment, Q&A, speaker, entity state management |
| `SmartOrganizationProvider` | Auto-tag, smart folder, related note state |
| `AnalyticsProvider` | Daily stats, word frequency, usage heatmaps |

### 3.3 Services Layer

| Service | Role |
|---|---|
| `AiService` | OpenAI Whisper transcription + GPT-4o summarization |
| `LocalAiService` | HTTP client to Flask local server (Wav2Vec2 + BART) |
| `EnhancedAiService` | Sentiment, Q&A extraction, speaker detection, NER |
| `SmartOrganizationService` | Auto-tagging, smart folders, related note matching |
| `AnalyticsService` | Firestore write of daily stats and user totals |
| `OfflineQueueService` | Persistent JSON queue for offline recordings |
| `RetryBackoffService` | Exponential backoff logic (max 3 retries) |
| `DraftService` | In-progress recording drafts persisted to device |
| `ExportService` | PDF / TXT / DOCX generation and sharing |
| `FirestoreService` | Generic Firestore CRUD wrapper |
| `FirestoreBatchService` | Batched Firestore writes for performance |
| `StorageService` | Firebase Storage upload / download |
| `ModelPreloadService` | Triggers async model warm-up on Flask server |

---

## 4. AI Models

### 4.1 OpenAI Whisper — `whisper-1` (Cloud)

- **Purpose:** Speech-to-text transcription
- **Languages:** English (`en`), Sinhala (`si`), Tamil (`ta`)
- **Transport:** Multipart `POST` → `api.openai.com/v1/audio/transcriptions`
- **Timeout:** 120 seconds
- **Formats accepted:** mp3, mp4, m4a, wav, webm
- **Entry point:** `AiService.transcribe(File, language)`

### 4.2 OpenAI GPT-4o — `gpt-4o` (Cloud)

- **Purpose:** Structured note summarization
- **Output format:** OVERVIEW / KEY POINTS / ACTION ITEMS sections
- **Language-aware:** response language matches user's selected language
- **Max summary:** ~250 words / 600 tokens
- **Entry point:** `AiService.summarize(transcript, language)`

### 4.3 OpenAI GPT-3.5-turbo (Cloud — fallback)

- **Purpose:** Sentiment analysis when local server is unavailable
- **Output:** `positive` / `negative` / `neutral` label + 0–1 confidence score

### 4.4 Custom Fine-tuned `facebook/bart-base` (Local)

- **Purpose:** Offline-capable structured summarization
- **Fine-tuned on:** SAMSum + XSum datasets (8,000 train / 500 val samples)
- **Training configuration:**

| Hyperparameter | Value |
|---|---|
| Base model | `facebook/bart-base` |
| Max input tokens | 512 |
| Max target tokens | 128 |
| Batch size | 4 |
| Gradient accumulation | 4× (effective batch = 16) |
| Epochs | 3 |
| Learning rate | 3e-5 |
| Precision | FP16 (mixed precision) |
| Hardware | NVIDIA RTX 2050 4 GB VRAM |

- **Output:** Structured JSON — `title`, `overview`, `key_points`, `keywords`, `conclusion`, `category_heading`
- **Served via:** Flask `POST /summarise`
- **Checkpoints:** `summarizer_model/checkpoints/`, final model at `summarizer_model/final/`

### 4.5 Custom Fine-tuned `facebook/wav2vec2-base` (Local)

- **Purpose:** On-device speech recognition
- **Training configuration:**

| Hyperparameter | Value |
|---|---|
| Base model | `facebook/wav2vec2-base` |
| Sample rate | 16 kHz |
| Max audio duration | 10 seconds |
| Batch size | 2 |
| Gradient accumulation | 8× (effective batch = 16) |
| Epochs | 50 |
| Learning rate | 1e-4 |
| Hardware | NVIDIA RTX 2050 4 GB VRAM |

- **Served via:** Flask `POST /transcribe`
- **Checkpoints:** `model/checkpoints/checkpoint-1200`, `checkpoint-1250`
- **Final model:** `model/final/`

### 4.6 Helsinki-NLP MarianMT (Local Translation)

- **Purpose:** Bidirectional translation between 17 languages and English
- **Model family:** `Helsinki-NLP/opus-mt-{src}-{tgt}` — auto-downloaded from HuggingFace on first use
- **Supported languages:** Sinhala, Tamil, French, German, Spanish, Italian, Portuguese, Dutch, Russian, Chinese, Japanese, Korean, Arabic, Hindi, Turkish, Polish, Swedish
- **Chunking strategy:** Input split into ~80-word chunks to stay within the 512-token limit
- **Use case:** Non-English audio is translated → English → BART summarization → translated back to source language

---

## 5. Flask API Server (`ai_note_model/flask_api/app.py`)

### Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Server status + model load state |
| `/preload` | GET | Async model warm-up (returns 202 immediately) |
| `/transcribe` | POST | Audio file → text (Wav2Vec2) |
| `/summarise` | POST | Text → structured summary JSON (BART) |
| `/detect_sentiment` | POST | Text → sentiment + confidence score |
| `/cache/stats` | GET | Cache hit/miss statistics |

### Performance Features

- **Lazy loading** — Wav2Vec2 and BART load on first request, not at startup
- **In-memory result cache** — SHA-256 keyed entries, configurable TTL (default 1 hour)
- **Thread-safe** model loading via `threading.Lock`
- **Env auto-loading** — reads `KEY=VALUE` from `.env` files in project tree
- **CORS enabled** — accepts cross-origin requests from Flutter HTTP client

---

## 6. Core Features

### 6.1 Recording & Transcription Pipeline

```
User taps Record
  → audio captured (record package, platform-native)
  → RecordingProvider monitors connectivity
  ├─ [Online + local server reachable]
  │    → POST audio to Flask /transcribe (Wav2Vec2)
  │    → POST transcript to Flask /summarise (BART)
  ├─ [Online + local server unreachable]
  │    → POST audio to OpenAI Whisper
  │    → POST transcript to OpenAI GPT-4o
  └─ [Offline]
       → OfflineQueueService.enqueue() → persisted to disk
       → auto-retry on next network connection

  After transcription:
  → EnhancedAiService (sentiment, Q&A, speakers, entities)
  → SmartOrganizationService (tags, folder, related notes)
  → AnalyticsService.recordNoteCreated()
  → FirestoreService.saveNote() + StorageService.uploadAudio()
```

**Recording controls:** pause, resume, cancel, quality (low / medium / high), denoise method + strength

### 6.2 Note Detail — 3-Tab View

| Tab | Content |
|---|---|
| Summary | Category heading, overview, key points, keywords, conclusion (from BART/GPT) |
| Transcript | Full raw transcription — inline editable |
| Info | Duration, word count, date, language, category, sentiment score, speakers, entities, Q&A items |

### 6.3 Notes Library

- Full-text search across title and content
- Category filter: Lecture / Meeting / Interview / Personal / Other
- Favorites filter
- Date / word count sort
- Note cards with emoji category badges and metadata preview

### 6.4 Offline Queue & Sync

- `OfflineQueueService` serializes failed/offline recordings to `offline_queue.json` on device
- `RetryBackoffService` implements exponential backoff with max 3 retries
- Auto-sync fires on network reconnection (Connectivity stream) and on auth state change
- **UI indicators in Recording screen:**
  - `cloud_off` icon badge in app bar showing queue count (9+ for > 9)
  - Bottom sheet with two sections: **Ready to Sync** (blue) and **Waiting to Retry** (orange)
  - Per-item display: category emoji, language badge, duration, retry count (X/3), backoff countdown
  - Manual **Sync Now** button

### 6.5 AI Enhancements (`EnhancedAiService`)

| Feature | Description |
|---|---|
| Sentiment analysis | positive / negative / neutral + 0–1 score |
| Q&A extraction | Auto-generates question/answer pairs from transcript |
| Speaker detection | Identifies and labels multiple speakers in dialogue |
| Named entity recognition | Extracts persons, locations, organizations with frequency counts |

**Fallback chain:** Local Flask `/detect_sentiment` → OpenAI GPT-3.5-turbo → local heuristic

### 6.6 Smart Organization (`SmartOrganizationService`)

- **Auto-tagging:** keyword extraction, category detection, topic classification, technology detection
- **Smart folders:** notes auto-assigned to logical folder categories based on content
- **Related notes:** similarity-based cross-referencing stored in `relatedNoteIds`
- Tag metadata: `name`, `confidence` (0–1), `source` (`ai` / `user` / `system`)

### 6.7 Analytics (`AnalyticsService`)

- **Daily stats** written to Firestore `analytics/{uid}/daily/{YYYY-MM-DD}`:
  - `notesCreated`, `totalMinutesRecorded`, `wordsTranscribed`
- **User lifetime totals** on `users/{uid}`:
  - `totalNotesCreated`, `totalMinutesRecorded`, `totalWordsTranscribed`, `lastNoteDate`
- **Analytics screen features:** daily progress charts, category breakdown, word frequency cloud, WER (Word Error Rate) scoring, activity heatmap, favorites count

### 6.8 Export (`ExportService`)

| Format | Library | Notes |
|---|---|---|
| PDF | `pdf` ^3.11.1 | Styled sections, headers, keyword chips |
| TXT | dart:io | Plain text with section labels |
| DOCX | RTF-based | Opens in Word / Google Docs |

- Configurable sections: summary, transcript, keywords, metadata
- Delivered via `share_plus` (`Share.shareXFiles`)

### 6.9 Localization

- **3 languages:** English, Sinhala (`si`), Tamil (`ta`)
- 150+ translated UI strings via `AppLocalizations`
- Language selection persisted in `SharedPreferences`
- Flutter `flutter_localizations` delegates registered for Material, Widgets, and Cupertino

---

## 7. Authentication

- **Email/password** — `FirebaseAuth.signInWithEmailAndPassword`
- **Google Sign-In** — `google_sign_in` package + Firebase credential
- User profile stored in Firestore `users/{uid}`:
  - `name`, `email`, `role`, `photoUrl`, `createdAt`, `updatedAt`
- Onboarding flag stored in `SharedPreferences` key `seen_onboarding`

---

## 8. Firestore Data Schema

### `notes/{noteId}`

| Field | Type | Description |
|---|---|---|
| `userId` | String | Owner UID |
| `title` | String | Auto-generated from AI |
| `transcription` | String | Full speech-to-text output |
| `summary` | String | Structured AI summary |
| `language` | String | `en` / `si` / `ta` |
| `category` | String | `lecture` / `meeting` / `interview` / `personal` / `other` |
| `keywords` | Array\<String\> | Extracted keywords (max 8) |
| `audioUrl` | String? | Firebase Storage download URL |
| `wordCount` | int | Transcript word count |
| `duration` | int | Recording duration in seconds |
| `isFavorite` | bool | Favorite flag |
| `tags` | Array\<String\> | AI-assigned smart tags |
| `folder` | String? | Smart folder name |
| `relatedNoteIds` | Array\<String\> | IDs of related notes |
| `sentiment` | String? | `positive` / `negative` / `neutral` |
| `sentimentScore` | double | 0.0 – 1.0 |
| `speakers` | Array\<String\> | Speaker labels |
| `qaItems` | Array\<Map\> | `{ question: String, answer: String }` |
| `entities` | Array\<String\> | Named entities |
| `createdAt` | Timestamp | Creation time |
| `updatedAt` | Timestamp | Last modification time |

### `analytics/{uid}/daily/{YYYY-MM-DD}`

| Field | Type |
|---|---|
| `date` | Timestamp |
| `notesCreated` | int |
| `totalMinutesRecorded` | int |
| `wordsTranscribed` | int |

### `users/{uid}`

| Field | Type |
|---|---|
| `name` | String |
| `email` | String |
| `role` | String |
| `photoUrl` | String? |
| `createdAt` | Timestamp |
| `updatedAt` | Timestamp? |
| `totalNotesCreated` | int |
| `totalMinutesRecorded` | int |
| `totalWordsTranscribed` | int |
| `lastNoteDate` | Timestamp? |

---

## 9. Screens

| Screen | Path |
|---|---|
| Splash | `screens/splash_screen.dart` |
| Login | `screens/auth/login_screen.dart` |
| Register | `screens/auth/register_screen.dart` |
| Onboarding | `screens/onboarding/` |
| Home | `screens/home/home_screen.dart` |
| Notes Library | `screens/library/notes_library_screen.dart` |
| Recording | `screens/recording/recording_screen.dart` |
| Note Detail (3-tab) | `screens/note_detail/note_detail_screen.dart` |
| AI Enhancements | `screens/ai_enhancements/ai_enhancements_screen.dart` |
| Analytics Dashboard | `screens/analytics/analytics_screen.dart` |
| Smart Folders | `screens/smart_organization/smart_folders_screen.dart` |
| Export | `screens/export/export_screen.dart` |
| Profile | `screens/profile/profile_screen.dart` |

---

## 10. Flutter Package Dependencies

| Package | Version | Purpose |
|---|---|---|
| `firebase_core` | ^4.4.0 | Firebase initialization |
| `firebase_auth` | ^6.1.2 | Authentication |
| `cloud_firestore` | ^6.1.0 | NoSQL database |
| `firebase_storage` | ^13.0.3 | Audio file storage |
| `provider` | ^6.1.2 | State management |
| `record` | ^5.2.0 | Platform-native audio recording |
| `just_audio` | ^0.9.42 | Audio playback |
| `permission_handler` | ^11.4.0 | Mic / storage permissions |
| `http` | ^1.2.2 | REST calls to Flask + OpenAI |
| `connectivity_plus` | ^6.1.3 | Network state monitoring |
| `google_fonts` | ^6.2.1 | Typography |
| `flutter_animate` | ^4.5.2 | UI animations and transitions |
| `pdf` | ^3.11.1 | PDF generation |
| `share_plus` | ^10.1.4 | Native file sharing |
| `open_file` | ^3.5.10 | Open exported files |
| `path_provider` | ^2.1.5 | Device file path resolution |
| `shared_preferences` | ^2.3.4 | Local key-value storage |
| `flutter_dotenv` | ^5.2.1 | `.env` API key loading |
| `uuid` | ^4.5.1 | Unique ID generation |
| `intl` | ^0.20.2 | Date / number formatting |
| `google_sign_in` | ^6.2.2 | Google OAuth |
| `flutter_localizations` | SDK | i18n framework |

---

## 11. Python / AI Backend Stack

| Library | Purpose |
|---|---|
| `Flask` + `flask-cors` | REST API server with CORS |
| `transformers` (HuggingFace) | BART, Wav2Vec2, MarianMT model loading and inference |
| `torch` (PyTorch) | GPU / CPU device management and model inference |
| `datasets` | SAMSum + XSum training data loading |
| `evaluate` | ROUGE metric (BART), WER metric (Wav2Vec2) |
| `soundfile` | Audio file I/O for Wav2Vec2 preprocessing |
| `accelerate` | Training acceleration and device placement |
| `sentencepiece` | BART tokenizer support |
| `numpy` | Array operations |

---

## 12. UI Design System

| Property | Value |
|---|---|
| Theme mode | Dark |
| Background | `#0D0D14` (`AppColors.bgDark`) |
| Card surface | `#16161F` |
| Primary accent | `#6C63FF` (purple-blue) |
| Secondary accent | `#00D9B5` (teal) |
| Home gradient | `#6AABF8` → `#9AC8FB` → `#EFF5FF` |
| Typography | Google Fonts — Plus Jakarta Sans |
| Animation | `flutter_animate` for screen transitions and micro-interactions |
| System UI | Transparent status bar, dark icons, portrait lock |
| Decorative elements | Semi-transparent orbs on gradient backgrounds |

---

## 13. Security

- All API keys loaded from `assets/.env` — not committed to version control
- `AiService` throws `AiException` if `OPENAI_API_KEY` is missing or is a placeholder value
- Firebase Auth gates all Firestore operations
- Firestore Security Rules enforce per-user data isolation at the database level
- No secrets hardcoded anywhere in source

---

## 14. Key Differentiators

1. **Hybrid AI pipeline** — transparent fallback: Local Wav2Vec2/BART → OpenAI Whisper/GPT-4o. User never sees the difference.
2. **Fully offline-capable** — recordings persist on-device and auto-sync the moment connectivity returns, with exponential backoff retry.
3. **Custom-trained models** — BART fine-tuned on SAMSum+XSum; Wav2Vec2 fine-tuned on a custom recorded dataset. Both optimized for a consumer 4 GB GPU (RTX 2050).
4. **17-language local translation** via MarianMT — summaries delivered in the speaker's native language with zero external API calls.
5. **Sri Lankan language focus** — Sinhala and Tamil are first-class supported languages, uncommon in AI note-taking tools.
6. **Rich per-note AI insights** — sentiment scoring, named entity recognition, automatic Q&A extraction, and speaker diarization on every note.
7. **Smart organization** — auto-tagging and smart folder assignment driven by content analysis, requiring no manual effort from the user.
