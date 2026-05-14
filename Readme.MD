# Note Lingo - AI Note Generator App

Voice-to-text note generator with summarization and Firebase sync, built with Flutter + Firebase + local Python AI services.

---

## Table Of Contents

- [Project Overview](#project-overview)
- [Current Tech Stack](#current-tech-stack)
- [Quick Start (Windows)](#quick-start-windows)
- [AI Server Setup (Python)](#ai-server-setup-python)
- [Flutter App Setup](#flutter-app-setup)
- [Connect App To AI Server](#connect-app-to-ai-server)
- [Run The App](#run-the-app)
- [Daily Startup Checklist](#daily-startup-checklist)
- [API Endpoints](#api-endpoints)
- [Project Structure (Current)](#project-structure-current)
- [Troubleshooting](#troubleshooting)
- [Firebase Firestore Rules](#firebase-firestore-rules)

---

## Project Overview

| Layer | Technology | Purpose |
|---|---|---|
| Mobile App | Flutter + Dart | UI, recording flow, note screens |
| Auth | Firebase Authentication | Login and user identity |
| Database | Cloud Firestore | Save notes and user profile data |
| Storage | Firebase Storage | Store exported note files |
| Transcription | OpenAI Whisper (local) | Audio to text |
| Summarization | Custom BART (local) | Transcript to structured summary |
| API | Flask + Flask-CORS | Local AI server for Flutter |
| Device Connection | USB / local network / ngrok | Connect phone app to PC AI server |

---

## Current Tech Stack

### Flutter
- Dart SDK: `^3.11.0`
- Flutter dependencies include: `firebase_core ^4.4.0`, `firebase_auth ^6.1.2`, `cloud_firestore ^6.1.0`, `firebase_storage ^13.0.3`, `provider`, `record`, `just_audio`, `http`, `google_sign_in`, `flutter_dotenv`, and others in `note_lingo/pubspec.yaml`.

### Python AI Service
- Python `3.11`
- Base requirements in `ai_note_model/requirements.txt`:
  - `flask>=3.0.0`
  - `flask-cors>=4.0.0`
  - `flake8>=7.0.0`
- Additional runtime ML dependencies are required for transcription/summarization (Whisper, Transformers, Torch, ffmpeg helper).

---

## Quick Start (Windows)

From repository root, run each command in order:

```powershell
# Terminal 1: AI server
cd ai_note_model
py -3.11 flask_api/app.py

# Terminal 2: ngrok tunnel (optional for physical phone off local LAN)
cd ai_note_model
.\ngrok.exe http 5000

# Terminal 3: Flutter app
cd note_lingo
flutter pub get
flutter run
```

Then set `LOCAL_AI_BASE_URL` as described below.

---

## AI Server Setup (Python)

### 1) Install Python

Install Python 3.11 and verify:

```cmd
py -3.11 --version
```

### 2) Install PyTorch (CUDA example)

```cmd
py -3.11 -m pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu118
```

Optional GPU check:

```cmd
py -3.11 -c "import torch; print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"
```

### 3) Install AI Runtime Libraries

```cmd
py -3.11 -m pip install -r requirements.txt
py -3.11 -m pip install openai-whisper transformers sentencepiece datasets
py -3.11 -m pip install soundfile librosa sounddevice scipy imageio-ffmpeg
py -3.11 -m pip install evaluate jiwer accelerate numpy pandas pydub pyttsx3
```

### 4) Start Flask API

```cmd
cd ai_note_model
py -3.11 flask_api/app.py
```

When running, API default address is:

`http://127.0.0.1:5000`

---

## Flutter App Setup

### 1) Install Flutter SDK

Follow official guide: https://docs.flutter.dev/get-started/install/windows

Verify:

```cmd
flutter --version
flutter doctor
```

### 2) Install Dependencies

```cmd
cd note_lingo
flutter pub get
```

### 3) Firebase (skip if already configured)

If this project is not yet connected:

```cmd
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

This generates:
- `note_lingo/lib/firebase_options.dart`
- `note_lingo/android/app/google-services.json`
- `note_lingo/ios/Runner/GoogleService-Info.plist`

---

## Connect App To AI Server

The app now resolves API URLs from:
1. `--dart-define=LOCAL_AI_BASE_URL=...`
2. `note_lingo/assets/.env` (`LOCAL_AI_BASE_URL=...`)
3. Auto fallbacks (`10.0.2.2`, `127.0.0.1`, `localhost`)

You do not need to edit `local_ai_service.dart` every session anymore.

### Option A: Set In `.env` (recommended)

Edit `note_lingo/assets/.env`:

```env
LOCAL_AI_BASE_URL=https://your-ngrok-url.ngrok-free.app
```

For same-LAN testing you can use:

```env
LOCAL_AI_BASE_URL=http://192.168.x.x:5000
```

### Option B: Use Dart Define

```cmd
flutter run --dart-define=LOCAL_AI_BASE_URL=https://your-ngrok-url.ngrok-free.app
```

---

## Run The App

### On Android Phone (USB Debugging)

1. Enable Developer Options.
2. Enable USB Debugging.
3. Connect phone and accept trust prompt.
4. Verify device:

```cmd
flutter devices
```

5. Run:

```cmd
cd note_lingo
flutter run
```

---

## Daily Startup Checklist

```text
1) Start AI server
   cd ai_note_model
   py -3.11 flask_api/app.py

2) Start tunnel (if needed)
   cd ai_note_model
   .\ngrok.exe http 5000

3) Update LOCAL_AI_BASE_URL in note_lingo/assets/.env (if ngrok URL changed)

4) Start app
   cd note_lingo
   flutter run
```

---

## API Endpoints

Available Flask endpoints:

- `GET /health` - Server and model status
- `GET /preload` - Trigger async model preload
- `POST /transcribe` - Audio file to transcript
- `POST /summarise` - Text to structured summary
- `GET /cache/stats` - Cache stats
- `POST /cache/clear` - Clear cache

Quick health check:

```cmd
curl http://127.0.0.1:5000/health
```

---

## Project Structure (Current)

```text
Note-Lingo/
├── note_lingo/                      # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── assets/
│   ├── android/
│   ├── ios/
│   ├── web/
│   └── pubspec.yaml
│
└── ai_note_model/                   # Python AI project
    ├── flask_api/
    │   ├── app.py
    │   └── translation_service.py
    ├── scripts/
    │   ├── 0_download_dataset.py
    │   ├── 0_generate_tts_dataset.ps1
    │   ├── 1_record_dataset.py
    │   ├── 1_train_summarizer.py
    │   ├── 2_prepare_dataset.py
    │   ├── 2_test_summarizer.py
    │   ├── 3_train_model.py
    │   ├── 4_evaluate_model.py
    │   └── 5_test_transcribe.py
    ├── dataset/
    ├── summarizer_dataset/
    ├── model/
    ├── summarizer_model/
    └── requirements.txt
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| ngrok not recognized | Use `.\ngrok.exe http 5000` from folder containing `ngrok.exe`, or install ngrok globally |
| Cannot connect to AI server | Confirm Flask is running and set `LOCAL_AI_BASE_URL` correctly in `assets/.env` |
| AI server starts but app times out | Check `GET /health` first and call `GET /preload` to warm up models |
| `Transcription failed 400` | Install ffmpeg helper: `py -3.11 -m pip install imageio-ffmpeg` |
| `CUDA: False` | Reinstall CUDA build of torch with correct index URL |
| Flutter dependency conflicts | Run `flutter clean` then `flutter pub get` |
| Port 5000 already in use | `taskkill /f /im python.exe` then restart Flask |

---

## Firebase Firestore Rules

Set rules in Firebase Console > Firestore > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notes/{noteId} {
      allow read, write: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
    }

    match /users/{userId} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

---

## Notes

- Keep secrets out of source control. Store API keys in secure local config only.
- ngrok URLs rotate often; update `LOCAL_AI_BASE_URL` whenever a new tunnel starts.
- For emulator-only local testing, `http://10.0.2.2:5000` is supported automatically.