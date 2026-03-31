#!/usr/bin/env python3
"""
Note Lingo — Audio Debug Tool
==============================
Saves the last received audio file from Flask so you can 
listen to what Whisper is actually hearing.

Run this INSTEAD of app.py temporarily to debug.

Usage:
    py -3.11 flask_api/debug_audio.py
    
Then record in your app — it saves the audio as debug_audio.wav
Open debug_audio.wav and listen to it.
"""

import os
import sys
import time
import tempfile
import shutil
import logging

try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
except ImportError:
    print("py -3.11 -m pip install flask flask-cors")
    sys.exit(1)

try:
    import torch
    import whisper
except ImportError:
    print("py -3.11 -m pip install openai-whisper")
    sys.exit(1)

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s  %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ── Load Whisper ───────────────────────────────────────────────────
device = "cuda" if torch.cuda.is_available() else "cpu"
log.info(f"Loading Whisper medium on {device}...")
model = whisper.load_model("medium", device=device)
log.info("✅  Whisper ready")

DEBUG_DIR = "debug_recordings"
os.makedirs(DEBUG_DIR, exist_ok=True)

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "whisper": True, "bart": False,
                    "device": device, "model": "whisper-medium"})

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if "audio" not in request.files:
        return jsonify({"error": "No audio"}), 400

    audio_file = request.files["audio"]
    language   = request.form.get("language", "auto")
    ext        = os.path.splitext(audio_file.filename)[-1].lower() or ".m4a"

    # Save temp file
    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    # ── Save a copy for debugging ──────────────────────────────────
    debug_copy = os.path.join(DEBUG_DIR,
        f"recording_{int(time.time())}{ext}")
    shutil.copy2(tmp_path, debug_copy)

    log.info(f"")
    log.info(f"══════════════════════════════════════")
    log.info(f"📥  Audio received: {audio_file.filename}")
    log.info(f"📁  Saved copy  : {os.path.abspath(debug_copy)}")
    log.info(f"    Size        : {os.path.getsize(tmp_path):,} bytes")
    log.info(f"    Language    : {language}")
    log.info(f"══════════════════════════════════════")
    log.info(f"")
    log.info(f"👂  Open this file and LISTEN to check if mic is working:")
    log.info(f"    {os.path.abspath(debug_copy)}")
    log.info(f"")

    try:
        # Run Whisper
        opts = {"fp16": device == "cuda", "task": "transcribe"}
        if language not in ("auto", None, ""):
            lang_map = {"en": "english", "si": "sinhala", "ta": "tamil"}
            if language in lang_map:
                opts["language"] = lang_map[language]

        t0     = time.time()
        result = model.transcribe(tmp_path, **opts)
        text   = result["text"].strip()
        dur    = result.get("segments", [{}])[-1].get("end", 0) \
                 if result.get("segments") else 0

        log.info(f"🤖  Whisper heard  : \"{text}\"")
        log.info(f"⏱️   Duration       : {dur:.1f}s")
        log.info(f"🌐  Detected lang  : {result.get('language','?')}")
        log.info(f"")

        if not text:
            log.warning("⚠️  Whisper returned EMPTY — mic recorded silence!")
            log.warning("    Check your microphone settings in Windows.")
        elif "thanks for watching" in text.lower():
            log.warning("⚠️  'Thanks for watching' detected!")
            log.warning("    This means the mic is picking up system audio,")
            log.warning("    NOT your voice. Check Windows sound settings:")
            log.warning("    → Right-click speaker → Sound settings")
            log.warning("    → Input → make sure 'Microphone' is selected")
            log.warning("    → NOT 'Stereo Mix' or 'What U Hear'")

        return jsonify({
            "text":           text,
            "language":       result.get("language", "unknown"),
            "duration":       round(dur, 2),
            "inference_time": round(time.time() - t0, 3),
            "word_count":     len(text.split()) if text else 0,
            "model":          "whisper-medium",
            "debug_file":     debug_copy,
        })

    except Exception as e:
        log.error(f"❌  {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        try: os.unlink(tmp_path)
        except: pass

@app.route("/summarise", methods=["POST"])
def summarise():
    data = request.get_json(force=True, silent=True) or {}
    text = data.get("text", "").strip()
    if not text:
        return jsonify({"error": "No text"}), 400
    # Simple extractive for debug mode
    sentences = text.split('. ')
    summary   = '. '.join(sentences[:2]) if len(sentences) > 2 else text
    words     = [w for w in text.lower().split() if len(w) > 4]
    from collections import Counter
    keywords  = [w for w, _ in Counter(words).most_common(5)]
    return jsonify({
        "summary": summary, "keywords": keywords,
        "title":   ' '.join(text.split()[:6]),
        "method":  "extractive_debug", "inference_time": 0.0,
    })

if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════╗")
    print("║   Note Lingo — Audio Debug Server       ║")
    print("║   Saves every recording to:             ║")
    print(f"║   {os.path.abspath(DEBUG_DIR)[:38]}  ║")
    print("╚══════════════════════════════════════════╝")
    print()
    print("  1. Start this server")
    print("  2. Record in your Flutter app")
    print("  3. Find the saved .m4a file in debug_recordings/")
    print("  4. Open it and LISTEN — is it your voice?")
    print()
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)