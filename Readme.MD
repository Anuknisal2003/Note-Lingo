#  Note Lingo — AI Note Generator App

> Voice-to-text AI note generator with smart summarization, built with Flutter + Firebase + Whisper AI

---

##  Table of Contents

- [Project Overview](#project-overview)
- [Requirements](#requirements)
- [Part 1 — Python AI Server Setup](#part-1--python-ai-server-setup)
- [Part 2 — Flutter App Setup](#part-2--flutter-app-setup)
- [Part 3 — Firebase Setup](#part-3--firebase-setup)
- [Part 4 — Connect App to AI Server](#part-4--connect-app-to-ai-server)
- [Part 5 — Run the App](#part-5--run-the-app)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

##  Project Overview

| Layer | Technology | Purpose |
|---|---|---|
| Mobile App | Flutter + Dart | UI, recording, display |
| Backend DB | Firebase Firestore | Store notes and user data |
| Auth | Firebase Authentication | Login / Register |
| AI Transcription | OpenAI Whisper (local) | Voice → Text |
| AI Summarization | Facebook BART (local) | Text → Smart Summary |
| AI Server | Python Flask | Serve AI models to the app |
| Tunnel | ngrok | Connect phone to PC server |

---

##  Requirements

### PC Requirements
- Windows 10 / 11 (64-bit)
- NVIDIA GPU recommended (RTX 2050 or better)
- At least 8 GB RAM
- At least 10 GB free disk space (for AI models)
- Internet connection (first run only, to download models)

### Software to Install
| Software | Version | Download |
|---|---|---|
| Python | 3.11 | https://www.python.org/downloads/release/python-3119/ |
| Flutter | Latest | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio |
| Git | Latest | https://git-scm.com/downloads |
| ngrok | Latest | https://ngrok.com/download |

---

##  Part 1 — Python AI Server Setup

### Step 1 — Install Python 3.11

1. Download from: https://www.python.org/downloads/release/python-3119/
2. Click **Windows installer (64-bit)**
3. Check **"Add python.exe to PATH"**
4. Check **"Install for all users"**
5. Click **Install Now**
6. Restart your PC after installing

Verify installation:
```cmd
py -3.11 --version
```
Should print: `Python 3.11.x`

---

### Step 2 — Install PyTorch with GPU Support

Open **CMD as Administrator** and run:

```cmd
py -3.11 -m pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu118
```

 This downloads ~2 GB — wait until fully complete.

Verify GPU is detected:
```cmd
py -3.11 -c "import torch; print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0))"
```

Expected output:
```
CUDA: True
GPU: NVIDIA GeForce RTX 2050
```

---

### Step 3 — Install All Python Libraries

```cmd
py -3.11 -m pip install transformers sentencepiece datasets
py -3.11 -m pip install soundfile librosa sounddevice scipy
py -3.11 -m pip install flask flask-cors
py -3.11 -m pip install openai-whisper
py -3.11 -m pip install pydub imageio-ffmpeg
py -3.11 -m pip install evaluate jiwer accelerate
py -3.11 -m pip install numpy pandas pyttsx3
```

---

### Step 4 — Navigate to AI Project Folder

```cmd
cd C:\Users\YourName\Documents\GitHub\Note-Lingo\ai_note_model
```

>  Replace `YourName` with your actual Windows username

---

### Step 5 — Start the Flask AI Server

```cmd
py -3.11 flask_api/app.py
```

First run will automatically download:
- **Whisper-medium** (~1.5 GB) — for transcription
- **BART-large-cnn** (~1.6 GB) — for summarization

This only happens once. After download, models are cached.

When ready, you will see:
```
 Whisper-medium ready
 BART ready
 * Running on http://0.0.0.0:5000
```

---

### Step 6 — Setup ngrok Tunnel

Open a **second CMD window** (keep Flask running in first):

```cmd
cd C:\Users\YourName\Documents\GitHub\Note-Lingo\ai_note_model
.\ngrok http 5000
```

You will see:
```
Forwarding   https://abc123.ngrok-free.app -> http://localhost:5000
```

 **Copy the `https://abc123.ngrok-free.app` URL** — you will need it in Step 10.

>  If ngrok says "not recognized", use `.\ngrok http 5000` (with `.\` prefix in PowerShell)

---

##  Part 2 — Flutter App Setup

### Step 7 — Install Flutter

1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your system PATH
4. Verify:
```cmd
flutter --version
flutter doctor
```

Fix any issues shown by `flutter doctor` before continuing.

---

### Step 8 — Install Dependencies

Navigate to the Flutter project folder:

```cmd
cd C:\Users\YourName\Documents\GitHub\Note-Lingo\note_lingo
```

Run:
```cmd
flutter pub get
```

---

##  Part 3 — Firebase Setup

### Step 9 — Configure Firebase

>  If `firebase_options.dart` and `google-services.json` already exist in your project — **skip this step**, Firebase is already configured.

If starting fresh:

```cmd
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

Select your Firebase project `note-lingo-54cc2` when prompted.

This generates:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

---

##  Part 4 — Connect App to AI Server

### Step 10 — Update the Server URL

Open this file in VS Code:
```
note_lingo/lib/services/local_ai_service.dart
```

Find this line (around line 33):
```dart
static const String _baseUrl = 'https://abc123.ngrok-free.app';
```

Replace `abc123.ngrok-free.app` with **your actual ngrok URL** from Step 6.

Example:
```dart
static const String _baseUrl = 'https://a1b2c3d4.ngrok-free.app';
```

> ⚠️ The ngrok URL changes every time you restart ngrok. Update this line each session.

---

##  Part 5 — Run the App

### Step 11 — Connect Your Android Phone

1. On your phone: **Settings → About Phone**
2. Tap **Build Number** 7 times → "You are now a developer!"
3. **Settings → Developer Options** → turn on **USB Debugging**
4. Connect phone to PC via USB cable
5. Tap **Allow** on the popup on your phone

Verify Flutter sees your phone:
```cmd
flutter devices
```

You should see your phone listed.

---

### Step 12 — Run the App

Make sure both are running:
-  Flask server (`py -3.11 flask_api/app.py`) — in CMD window 1
-  ngrok tunnel (`.\ngrok http 5000`) — in CMD window 2

Then run the Flutter app:
```cmd
cd note_lingo
flutter run
```

The app will install and open on your phone automatically.

---

##  Project Structure

```
Note-Lingo/
│
├── note_lingo/                         ← Flutter App
│   ├── lib/
│   │   ├── main.dart                   ← Entry point
│   │   ├── core/
│   │   │   └── theme/app_theme.dart    ← App colors & fonts
│   │   ├── models/
│   │   │   ├── note_model.dart         ← Note data model
│   │   │   └── user_model.dart         ← User data model
│   │   ├── providers/
│   │   │   ├── auth_provider.dart      ← Login / Register state
│   │   │   ├── recording_provider.dart ← Recording & AI pipeline
│   │   │   ├── notes_provider.dart     ← Notes list state
│   │   │   └── language_provider.dart  ← Language selection
│   │   ├── services/
│   │   │   ├── local_ai_service.dart   ← Calls Flask AI server
│   │   │   ├── firestore_service.dart  ← Firebase database
│   │   │   ├── storage_service.dart    ← Firebase file storage
│   │   │   └── export_service.dart     ← PDF/DOCX/TXT export
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding/
│   │   │   ├── auth/                   ← Login & Register
│   │   │   ├── home/
│   │   │   ├── recording/
│   │   │   ├── note_detail/
│   │   │   ├── export/
│   │   │   ├── library/
│   │   │   └── profile/
│   │   └── widgets/                    ← Shared UI components
│   ├── assets/
│   │   ├── images/                     ← Onboarding images
│   │   └── .env                        ← Environment variables
│   ├── android/app/
│   │   └── google-services.json        ← Firebase Android config
│   └── pubspec.yaml                    ← Flutter dependencies
│
└── ai_note_model/                      ← Python AI Project
    ├── scripts/
    │   ├── 1_record_dataset.py         ← Record voice samples
    │   ├── 2_prepare_dataset.py        ← Prepare training data
    │   ├── 3_train_model.py            ← Train Wav2Vec2 model
    │   ├── 4_evaluate_model.py         ← Check WER accuracy
    │   ├── 5_test_transcribe.py        ← Quick transcription test
    │   ├── 6_test_gui.py               ← GUI test tool
    │   └── 7_generate_tts_samples.py   ← Generate TTS training data
    ├── flask_api/
    │   └── app.py                      ← AI server (Whisper + BART)
    ├── dataset/
    │   └── audio/                      ← Voice recordings (gitignored)
    ├── model/                          ← Trained model files (gitignored)
    └── ngrok.exe                       ← ngrok tunnel tool
```

---

##  How the App Works

```
📱 User speaks
      ↓
🎙️  Flutter records audio (.m4a)
      ↓
📡  Sends to Flask server via ngrok
      ↓
🤖  Whisper-medium transcribes speech → text
      ↓
📝  BART-large-cnn summarizes text
      ↓
🏷️  Keywords + Title auto-generated
      ↓
☁️  Note saved to Firebase Firestore
      ↓
📱  App shows transcript + summary + keywords
```

---

##  Every Time You Start (Daily Checklist)

Each new session, run these in order:

```
CMD Window 1:
  cd ai_note_model
  py -3.11 flask_api/app.py          ← Start AI server

CMD Window 2:
  cd ai_note_model
  .\ngrok http 5000                  ← Start tunnel

VS Code:
  Update _baseUrl in local_ai_service.dart with new ngrok URL

Terminal:
  cd note_lingo
  flutter run                        ← Run Flutter app
```

---

##  Troubleshooting

| Problem | Fix |
|---|---|
| `ngrok not recognized` | Use `.\ngrok http 5000` in PowerShell |
| `CUDA: False` | Install CUDA PyTorch: `pip install torch --index-url https://download.pytorch.org/whl/cu118` |
| App shows blank screen | Run `flutterfire configure` to regenerate firebase_options.dart |
| `Transcription failed 400` | ffmpeg not found — install imageio-ffmpeg: `pip install imageio-ffmpeg` |
| `Cannot connect to AI server` | Update ngrok URL in local_ai_service.dart |
| Notes not saving | Check Firebase rules — make sure Firestore is in test mode |
| `flutter pub get` fails | Check pubspec.yaml — firebase_core must be ^4.4.0 |
| Recording shows "thanks for watching" | Use real Android phone, not emulator |
| Port 5000 already in use | Kill old Flask: `taskkill /f /im python.exe` then restart |

---

##  Firebase Firestore Rules

Go to **Firebase Console → Firestore → Rules** and set:

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

##  Developer Info

| Field | Details |
|---|---|
| App Name | Note Lingo |
| Platform | Android (Flutter) |
| Firebase Project | note-lingo-54cc2 |
| AI Models | Whisper-medium + BART-large-cnn |
| University Module | PUSL3190 |
| Language Support | English, Sinhala, Tamil |

---

>  **Tip:** Star this repo and keep this README open while developing.  
> If anything breaks, check the Troubleshooting table first!