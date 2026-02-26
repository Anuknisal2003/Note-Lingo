#!/usr/bin/env python3
"""
Flask API — Serve Your Wav2Vec2 Model
======================================
Exposes your trained model as a REST API.
Your Flutter app sends audio → gets transcription back.

Usage:
    python flask_api/app.py

Endpoints:
    POST /transcribe   → transcribe audio file
    GET  /health       → check server is running
    GET  /info         → model information

Install:
    pip install flask flask-cors
"""

import os
import sys
import time
import tempfile
import logging
import torch
import numpy as np

# Add parent dir to path so we can import from scripts/
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
    import soundfile as sf
    HAS_DEPS = True
except ImportError as e:
    print(f"❌  Missing dependency: {e}")
    print("    pip install flask flask-cors transformers soundfile")
    HAS_DEPS = False

# ── Config ────────────────────────────────────────────────────────
MODEL_PATH  = os.path.join(os.path.dirname(__file__), "..", "model", "final")
SAMPLE_RATE = 16000
PORT        = 5000
HOST        = "0.0.0.0"    # accessible from phone on same WiFi
MAX_DURATION = 120          # reject audio longer than 2 minutes

# ── Logging ───────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Flask app ─────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)   # allow cross-origin requests from Flutter

# ── Load model at startup ─────────────────────────────────────────
processor = None
model     = None
device    = "cpu"
model_loaded = False

def load_model():
    global processor, model, device, model_loaded

    model_path = os.path.abspath(MODEL_PATH)

    if not os.path.exists(model_path):
        log.warning(f"⚠️   Model not found at {model_path}")
        log.warning("     Falling back to base Wav2Vec2 (untrained)")
        model_path = "facebook/wav2vec2-base-960h"  # fallback

    log.info(f"📥  Loading model: {model_path}")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    log.info(f"🖥️   Device: {device.upper()}")

    processor = Wav2Vec2Processor.from_pretrained(model_path)
    model     = Wav2Vec2ForCTC.from_pretrained(model_path).to(device)
    model.eval()

    model_loaded = True
    log.info("✅  Model loaded and ready!")

# ── Transcription function ────────────────────────────────────────
def do_transcribe(audio: np.ndarray) -> dict:
    """Run inference and return result dict."""
    if not model_loaded:
        raise RuntimeError("Model not loaded")

    # Validate audio
    duration = len(audio) / SAMPLE_RATE
    if duration < 0.1:
        raise ValueError("Audio too short (minimum 0.1 seconds)")
    if duration > MAX_DURATION:
        raise ValueError(f"Audio too long (maximum {MAX_DURATION} seconds)")

    # Feature extraction
    inputs = processor(
        audio,
        sampling_rate=SAMPLE_RATE,
        return_tensors="pt",
        padding=True,
    ).to(device)

    # Inference
    t0 = time.time()
    with torch.no_grad():
        logits = model(**inputs).logits
    inference_time = time.time() - t0

    # Decode
    pred_ids = torch.argmax(logits, dim=-1)
    text     = processor.batch_decode(pred_ids)[0].strip().lower()

    return {
        "text":           text,
        "duration":       round(duration, 2),
        "inference_time": round(inference_time, 3),
        "word_count":     len(text.split()) if text else 0,
    }

# ── Routes ────────────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({
        "status":       "ok",
        "model_loaded": model_loaded,
        "device":       device,
    })

@app.route("/info", methods=["GET"])
def info():
    """Model information endpoint."""
    return jsonify({
        "model":        os.path.abspath(MODEL_PATH),
        "sample_rate":  SAMPLE_RATE,
        "max_duration": MAX_DURATION,
        "device":       device,
        "project":      "Note Lingo — University AI Project",
    })

@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Transcribe audio file.

    Request:  multipart/form-data with field 'audio' (WAV/M4A/MP3)
    Response: { "text": "...", "duration": 3.2, "inference_time": 0.5 }
    """
    # ── Validate request ──────────────────────────────────────────
    if "audio" not in request.files:
        return jsonify({"error": "No audio file in request. Use field name 'audio'"}), 400

    audio_file = request.files["audio"]
    if audio_file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    # ── Save to temp file ─────────────────────────────────────────
    suffix = os.path.splitext(audio_file.filename)[-1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    try:
        # ── Load audio ────────────────────────────────────────────
        try:
            audio, sr = sf.read(tmp_path)
        except Exception:
            # Try librosa as fallback (handles m4a, mp3, etc.)
            try:
                import librosa
                audio, sr = librosa.load(tmp_path, sr=SAMPLE_RATE, mono=True)
            except Exception as e:
                return jsonify({"error": f"Cannot read audio: {str(e)}"}), 400

        # Convert to mono float32
        if audio.ndim > 1:
            audio = audio[:, 0]
        audio = audio.astype(np.float32)

        # Resample if needed
        if sr != SAMPLE_RATE:
            import librosa
            audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)

        # ── Transcribe ────────────────────────────────────────────
        result = do_transcribe(audio)

        log.info(f"✅  [{result['duration']}s] → \"{result['text'][:60]}\"")
        return jsonify(result)

    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        log.error(f"❌  Transcription error: {e}")
        return jsonify({"error": f"Transcription failed: {str(e)}"}), 500
    finally:
        # Clean up temp file
        try:
            os.unlink(tmp_path)
        except Exception:
            pass

# ── Error handlers ────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Endpoint not found", "routes": [
        "GET  /health",
        "GET  /info",
        "POST /transcribe",
    ]}), 404

@app.errorhandler(405)
def method_not_allowed(e):
    return jsonify({"error": "Method not allowed"}), 405

# ── Main ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    if not HAS_DEPS:
        sys.exit(1)

    print()
    print("╔══════════════════════════════════════════════╗")
    print("║   Note Lingo — Local AI Transcription API   ║")
    print("╚══════════════════════════════════════════════╝")
    print()

    # Load model before starting server
    load_model()

    print()
    print(f"  🌐  Server: http://localhost:{PORT}")
    print(f"  📱  For mobile testing, use your PC's local IP:")
    import socket
    try:
        local_ip = socket.gethostbyname(socket.gethostname())
        print(f"       http://{local_ip}:{PORT}")
    except Exception:
        print(f"       Check ipconfig / ifconfig for your IP")
    print()
    print(f"  🧪  Test with curl:")
    print(f"       curl -X POST http://localhost:{PORT}/transcribe \\")
    print(f"            -F 'audio=@path/to/test.wav'")
    print()
    print(f"  🛑  Press Ctrl+C to stop")
    print()

    app.run(host=HOST, port=PORT, debug=False, threaded=True)