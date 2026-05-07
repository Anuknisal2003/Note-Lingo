# 🚀 Note Lingo - Quick Start & Deployment Guide

## Prerequisites

- **Flutter 3.11+** ([Install](https://docs.flutter.dev/get-started/install))
- **Python 3.11+** ([Install](https://www.python.org/downloads/))
- **Firebase Project** ([Create](https://firebase.google.com/))
- **Android Studio** or **Xcode** (for emulator)
- **8GB RAM minimum**, **SSD recommended**

---

## Part 1: Firebase Setup (5 minutes)

### 1.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: "note-lingo"
3. Enable these services:
   - ✅ Authentication (Email + Google)
   - ✅ Firestore Database
   - ✅ Storage (optional, for audio)

### 1.2 Generate Google Services Files
1. In Firebase Console, go to **Project Settings**
2. Download `google-services.json` (Android)
3. Place in: `note_lingo/android/app/`
4. Download `GoogleService-Info.plist` (iOS)
5. Place in: `note_lingo/ios/Runner/`

### 1.3 Update Firebase Config
Edit `lib/firebase_options.dart` with your Firebase project IDs.

---

## Part 2: Local AI Server Setup (10 minutes)

### 2.1 Python Dependencies
```bash
cd ai_note_model/flask_api

# Create virtual environment
python -m venv venv

# Activate
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install packages
pip install -r requirements.txt
# (See ai_note_model/requirements.txt if not exist)
```

### 2.2 Download AI Models
First run will auto-download models (~4GB):
```bash
python app.py
```
Then press `Ctrl+C` to stop after download completes.

### 2.3 Start Flask Server
```bash
python app.py
# Server starts at http://127.0.0.1:5000
```

Keep this terminal open while testing Flutter app!

---

## Part 3: Flutter App Setup (10 minutes)

### 3.1 Clone & Dependencies
```bash
cd note_lingo

# Get dependencies
flutter pub get

# Check setup
flutter doctor
# Should show ✓ for Flutter, Dart, Android Studio/Xcode
```

### 3.2 Create Environment File
Create `assets/.env`:
```
OPENAI_API_KEY=sk-your-key-here
LOCAL_AI_BASE_URL=http://192.168.1.YOUR_PC_IP:5000
```

### 3.3 Find Your PC's IP Address
```bash
# Windows (PowerShell)
ipconfig | findstr /i "ipv4"

# macOS/Linux
ifconfig | grep "inet "
```
Update `.env` with your PC's IP (e.g., `192.168.1.100`)

### 3.4 Run App
```bash
# List devices
flutter devices

# Run on device/emulator
flutter run -d <device_id>

# With custom AI server URL
flutter run --dart-define=LOCAL_AI_BASE_URL=http://192.168.1.100:5000
```

---

## Part 4: Firebase Firestore Indexes (2 minutes)

Create these composite indexes in Firebase Console:

**Index 1:**
- Collection: `notes`
- Fields: `userId` (Asc), `createdAt` (Desc)

**Index 2:**
- Collection: `notes`
- Fields: `userId` (Asc), `category` (Asc)

**Index 3:**
- Collection: `notes`
- Fields: `userId` (Asc), `isFavorite` (Asc)

---

## Part 5: Firestore Security Rules

Replace default rules with:
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User-scoped data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Notes - user can read/write own notes
    match /notes/{noteId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth.uid == resource.data.userId;
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if request.auth.uid != null;
        allow create: if request.auth.uid == request.resource.data.userId;
        allow update: if request.auth.uid == resource.data.userId;
        allow delete: if request.auth.uid == resource.data.userId;
      }
    }

    // Study groups
    match /study_groups/{groupId} {
      allow read: if request.auth.uid in resource.data.members;
      allow create: if request.auth.uid == request.resource.data.createdBy;
      allow update, delete: if request.auth.uid == resource.data.createdBy;
    }

    // Analytics (user's own only)
    match /analytics/{userId}/daily/{dateId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## Part 6: Android Setup (if needed)

### 6.1 Android SDK
```bash
# In Android Studio:
# Tools → SDK Manager
# Install SDK 33+ and latest SDK tools
```

### 6.2 Create Emulator
```bash
flutter emulators --create --name pixel6
flutter emulators --launch pixel6
```

### 6.3 Build APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

---

## Part 7: iOS Setup (if needed)

### 7.1 Install Pods
```bash
cd ios
pod repo update
pod install
cd ..
```

### 7.2 Build iOS App
```bash
flutter build ios --release
# Open in Xcode: ios/Runner.xcworkspace
```

---

## Testing Checklist

### Basic Recording
- [ ] Open app, grant microphone permission
- [ ] Tap record button
- [ ] Speak clearly for 30 seconds
- [ ] Tap stop
- [ ] Verify transcription appears
- [ ] Check AI enhancements show

### Offline Testing (Android)
```bash
# In Android Studio Device Manager:
# 1. Open Emulator
# 2. View → Extended controls → Location
# 3. Change to "Airplane mode"
# 4. Record note (should queue offline)
# 5. Disable airplane mode
# 6. Restart app
# 7. Verify note syncs
```

### Database Testing
```bash
# In Firebase Console:
# Firestore Database → Collections → notes
# Verify:
# - Your recorded note appears
# - All fields populated (title, transcription, summary)
# - New fields present (tags, sentiment, entities)
```

---

## Troubleshooting Guide

### "AI server not reachable"
```
✓ Flask server running? Check terminal: "Running on http://127.0.0.1:5000"
✓ Correct IP in .env? Compare `ipconfig` output
✓ Same network? Phone & PC on same WiFi?
✓ Firewall? Port 5000 open on PC?
✓ Correct URL? Should be http:// not https://
```

### "No speech detected"
```
✓ Microphone working? Test in phone settings
✓ Speaking loudly enough? Try increasing volume
✓ Audio format correct? Using M4A/WAV
✓ Check Flask logs for audio issues
```

### "Transcription too slow/fails"
```
✓ GPU available? (Flask uses CPU by default, add CUDA for speed)
✓ Audio quality good? Reduce background noise
✓ Audio too long? Keep <5 minutes
✓ RAM sufficient? Flask needs ~4GB for models
```

### "Firebase authentication fails"
```
✓ google-services.json in android/app/?
✓ GoogleService-Info.plist in ios/Runner/?
✓ Firebase console shows this Firebase project?
✓ Authentication enabled in Firebase?
✓ Google Sign-In credentials added?
```

### "Firestore queries slow"
```
✓ Composite indexes created?
✓ Firestore in read-only recovery? (Check console)
✓ Query filtering on indexed fields?
✓ Pagination implemented for large datasets?
```

### "App crashes on start"
```
✓ Flutter doctor all green? flutter doctor -v
✓ Dependencies updated? flutter pub get
✓ Build cache clean? flutter clean
✓ Try: flutter run --verbose (for stack trace)
```

---

## Performance Optimization

### For Faster AI Processing
**On PC with NVIDIA GPU:**
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install cuda
```

**Then in flask_api/app.py:**
```python
device = 'cuda'  # Instead of 'cpu'
```

### For Better Battery Life
- Reduce recording quality: Change to 16kHz sample rate
- Disable analytics logging
- Increase offline queue batch size

### For Larger Datasets
- Implement pagination in home_screen.dart
- Add search filters
- Archive old notes

---

## Deployment Checklist

### Before Publishing
- [ ] Remove all debug prints
- [ ] Update version in pubspec.yaml
- [ ] Test on real device (not just emulator)
- [ ] Test all 3 languages (en, si, ta)
- [ ] Test offline mode
- [ ] Test Firebase production database
- [ ] Verify OpenAI API key not in code
- [ ] Update privacy policy
- [ ] Create app store screenshots

### App Store Deployment
```bash
# iOS
flutter build ios --release
# Then distribute via App Store Connect

# Android
flutter build appbundle --release
# Upload to Google Play Console
# File: build/app/outputs/bundle/release/app-release.aab
```

### Backend Deployment
**Option 1: Google Cloud Run**
```bash
gcloud app deploy ai_note_model/app.yaml
```

**Option 2: AWS Lambda + Container**
```bash
docker build -t note-lingo-ai .
docker push <ecr-uri>/note-lingo-ai
```

**Option 3: Self-hosted VPS**
```bash
# SSH to server
ssh user@server.ip
cd /home/note-lingo
python app.py &
# Use systemd for auto-restart
```

---

## Monitoring & Maintenance

### Firebase Console Monitoring
- **Authentication** → Active sessions
- **Firestore** → Realtime usage
- **Storage** → Quota and usage
- **Functions** → Logs (if using)

### Flask Server Monitoring
```bash
# Add to flask_api/app.py
from flask_cors import CORS
@app.route('/health')
def health():
    return {'status': 'ok', 'models_loaded': True}
```

### Regular Backups
```bash
# Export Firestore
gcloud firestore export gs://note-lingo-backups/backup-date

# Backup local models
tar -czf models-backup.tar.gz ai_note_model/model/
```

---

## Support & Resources

- **Flutter Docs**: https://docs.flutter.dev
- **Firebase Docs**: https://firebase.google.com/docs
- **OpenAI API**: https://platform.openai.com/docs
- **Whisper Model**: https://github.com/openai/whisper
- **BART Model**: https://huggingface.co/facebook/bart-large-cnn

---

## License

This project is built with:
- Flutter/Dart (Google)
- Firebase (Google)
- OpenAI APIs
- Open-source ML models

See LICENSE file for details.

---

**🎉 You're all set! Start recording notes with AI! 🎉**
