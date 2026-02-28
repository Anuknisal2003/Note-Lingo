#!/usr/bin/env python3
"""
Flask API — Note Lingo Local AI Server
========================================
FIXED: Avoids regex DLL Windows security block by
       importing only what is strictly needed.

Install:
    py -3.11 -m pip install flask flask-cors torch torchaudio
    py -3.11 -m pip install soundfile pydub imageio-ffmpeg numpy

Usage:
    py -3.11 flask_api/app.py
"""

import os
import sys
import time
import json
import tempfile
import logging
import numpy as np

# ── Flask ─────────────────────────────────────────────────────────
try:
    from flask import Flask, request, jsonify
    from flask_cors import CORS
except ImportError as e:
    print(f"❌  Flask missing: {e}")
    print("    py -3.11 -m pip install flask flask-cors")
    sys.exit(1)

# ── Torch ─────────────────────────────────────────────────────────
try:
    import torch
    import torchaudio
except ImportError as e:
    print(f"❌  PyTorch missing: {e}")
    print("    py -3.11 -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────────
MODEL_PATH   = os.path.join(os.path.dirname(__file__), "..", "model", "final")
SAMPLE_RATE  = 16000
PORT         = 5000
HOST         = "0.0.0.0"
MAX_DURATION = 120

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ── Set ffmpeg path at startup ────────────────────────────────────
try:
    import imageio_ffmpeg
    import pydub.utils
    from pydub import AudioSegment as _AS
    _ff = imageio_ffmpeg.get_ffmpeg_exe()
    _AS.converter = _ff
    _AS.ffmpeg    = _ff
    _AS.ffprobe   = _ff
    pydub.utils.get_encoder_name = lambda: _ff
    pydub.utils.get_prober_name  = lambda: _ff
    print(f"ffmpeg path: {_ff}")
except Exception as _e:
    print(f"ffmpeg warning: {_e}")


# ── Global model state ────────────────────────────────────────────
processor    = None
model        = None
device       = "cpu"
model_loaded = False

# ── Load model using torchaudio (avoids regex/transformers) ───────
def load_model():
    global processor, model, device, model_loaded

    model_path = os.path.abspath(MODEL_PATH)
    log.info(f"📥  Loading model from: {model_path}")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    log.info(f"🖥️   Device: {device.upper()}")

    # ── Load using transformers but catch regex error ─────────────
    try:
        # Try importing transformers — works if regex DLL allowed
        from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC

        if not os.path.exists(model_path):
            log.warning(f"⚠️  Custom model not found, using base model")
            model_path = "facebook/wav2vec2-base-960h"

        processor = Wav2Vec2Processor.from_pretrained(model_path)
        model     = Wav2Vec2ForCTC.from_pretrained(model_path).to(device)
        model.eval()
        model_loaded = True
        log.info("✅  Model loaded with transformers")
        return

    except Exception as e:
        log.warning(f"⚠️  transformers failed: {e}")
        log.info("🔄  Trying torchaudio pipeline instead...")

    # ── Fallback: use torchaudio wav2vec2 (no regex needed) ───────
    try:
        bundle = torchaudio.pipelines.WAV2VEC2_ASR_BASE_960H
        model  = bundle.get_model().to(device)
        model.eval()

        # Store labels for decoding
        model._labels    = bundle.get_labels()
        model._use_torch = True
        model_loaded     = True
        log.info("✅  Model loaded with torchaudio (no regex needed)")

    except Exception as e:
        log.error(f"❌  Both loading methods failed: {e}")
        sys.exit(1)

# ── Convert audio file to numpy array ────────────────────────────
def load_audio(file_path: str) -> np.ndarray:
    """
    Load any audio format → float32 numpy at 16kHz mono.
    Uses ffmpeg directly via subprocess — most reliable method.
    """
    import subprocess
    import imageio_ffmpeg
    import soundfile as sf

    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    log.info(f"  🔧  ffmpeg: {ffmpeg_exe}")

    # ── Method 1: ffmpeg directly via subprocess ──────────────────
    # Convert m4a/mp3/any → wav using ffmpeg command line
    wav_path = file_path + "_converted.wav"
    try:
        cmd = [
            ffmpeg_exe,
            "-y",                    # overwrite output
            "-i", file_path,         # input file (any format)
            "-ar", str(SAMPLE_RATE), # sample rate 16000
            "-ac", "1",              # mono
            "-f", "wav",             # output format
            wav_path,                # output file
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=30,
        )

        if result.returncode != 0:
            raise Exception(f"ffmpeg error: {result.stderr.decode()}")

        # Read the converted wav file
        audio, sr = sf.read(wav_path)
        if audio.ndim > 1:
            audio = audio[:, 0]
        audio = audio.astype(np.float32)
        log.info(f"  ✅  ffmpeg converted: {len(audio)/SAMPLE_RATE:.1f}s")
        return audio

    except Exception as e:
        log.warning(f"  ⚠️  ffmpeg direct failed: {e}")
    finally:
        # Clean up temp wav file
        try:
            if os.path.exists(wav_path):
                os.unlink(wav_path)
        except Exception:
            pass

    # ── Method 2: torchaudio (wav, flac, mp3) ─────────────────────
    try:
        waveform, sr = torchaudio.load(file_path)
        if waveform.shape[0] > 1:
            waveform = waveform.mean(dim=0, keepdim=True)
        if sr != SAMPLE_RATE:
            resampler = torchaudio.transforms.Resample(sr, SAMPLE_RATE)
            waveform  = resampler(waveform)
        audio = waveform.squeeze().numpy().astype(np.float32)
        log.info(f"  ✅  Loaded via torchaudio: {len(audio)/SAMPLE_RATE:.1f}s")
        return audio
    except Exception as e:
        log.warning(f"  ⚠️  torchaudio failed: {e}")

    # ── Method 3: soundfile (wav only fallback) ────────────────────
    try:
        audio, sr = sf.read(file_path)
        if audio.ndim > 1:
            audio = audio[:, 0]
        audio = audio.astype(np.float32)
        log.info(f"  ✅  Loaded via soundfile: {len(audio)/SAMPLE_RATE:.1f}s")
        return audio
    except Exception as e:
        raise ValueError(
            f"Cannot read audio file. All methods failed.\n"
            f"Last error: {e}"
        )

# ── Transcription ─────────────────────────────────────────────────
def do_transcribe(audio: np.ndarray) -> dict:
    if not model_loaded:
        raise RuntimeError("Model not loaded")

    duration = len(audio) / SAMPLE_RATE
    if duration < 0.1:
        raise ValueError("Audio too short")
    if duration > MAX_DURATION:
        raise ValueError(f"Audio too long (max {MAX_DURATION}s)")

    t0 = time.time()

    # ── Path A: transformers processor ───────────────────────────
    if processor is not None:
        inputs = processor(
            audio,
            sampling_rate=SAMPLE_RATE,
            return_tensors="pt",
            padding=True,
        ).to(device)

        with torch.no_grad():
            logits = model(**inputs).logits

        pred_ids = torch.argmax(logits, dim=-1)
        text     = processor.batch_decode(pred_ids)[0].strip().lower()

    # ── Path B: torchaudio pipeline ───────────────────────────────
    else:
        waveform = torch.tensor(audio).unsqueeze(0).to(device)

        with torch.no_grad():
            emissions, _ = model(waveform)

        # Greedy decode
        labels   = model._labels
        pred_ids = torch.argmax(emissions[0], dim=-1)
        tokens   = [labels[i] for i in pred_ids]

        # Collapse repeated tokens and remove blank (-)
        text_chars = []
        prev = None
        for t in tokens:
            if t != prev and t != "-":
                text_chars.append(t)
            prev = t

        text = "".join(text_chars).replace("|", " ").lower().strip()

    inference_time = time.time() - t0

    return {
        "text":           text,
        "duration":       round(duration, 2),
        "inference_time": round(inference_time, 3),
        "word_count":     len(text.split()) if text else 0,
    }

# ── Routes ────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":       "ok",
        "model_loaded": model_loaded,
        "device":       device,
    })

@app.route("/info", methods=["GET"])
def info():
    return jsonify({
        "model":       os.path.abspath(MODEL_PATH),
        "sample_rate": SAMPLE_RATE,
        "device":      device,
    })

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if "audio" not in request.files:
        return jsonify({"error": "No audio file. Field name must be 'audio'"}), 400

    audio_file = request.files["audio"]
    if audio_file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    ext = os.path.splitext(audio_file.filename)[-1].lower() or ".m4a"

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    log.info(f"📥  Received: {audio_file.filename}")

    try:
        audio  = load_audio(tmp_path)
        result = do_transcribe(audio)
        log.info(f'✅  [{result["duration"]}s] → "{result["text"][:60]}"')
        return jsonify(result)

    except ValueError as e:
        log.error(f"❌  {e}")
        return jsonify({"error": str(e)}), 400
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        log.error(f"❌  Unexpected: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not found", "routes": [
        "GET  /health",
        "GET  /info",
        "POST /transcribe",
    ]}), 404

# ── Main ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════╗")
    print("║   Note Lingo — Local AI Transcription API   ║")
    print("╚══════════════════════════════════════════════╝")
    print()

    load_model()

    import socket
    try:
        local_ip = socket.gethostbyname(socket.gethostname())
    except Exception:
        local_ip = "check ipconfig"

    print()
    print(f"  🌐  Server:  http://localhost:{PORT}")
    print(f"  📱  Mobile:  http://{local_ip}:{PORT}")
    print()
    print(f"  🛑  Ctrl+C to stop")
    print()

    app.run(host=HOST, port=PORT, debug=False, threaded=True)