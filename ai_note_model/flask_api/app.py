"""
============================================================
  Note Lingo — Flask API Server
  Whisper transcription + Custom BART summarization
============================================================
  Endpoints:
    GET  /health        → server status
    POST /transcribe    → audio → text (Whisper)
    POST /summarise     → text  → structured summary (BART)

  Run: py -3.11 flask_api/app.py
============================================================
"""

import os, re, json, sys, time, logging, subprocess, tempfile
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Logging ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-5s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

app  = Flask(__name__)
CORS(app)

# ── Paths ────────────────────────────────────────────────
ROOT              = Path(__file__).parent.parent
WHISPER_MODEL_ID  = "medium"
BART_MODEL_DIR    = ROOT / "summarizer_model" / "final"

# ── Global model holders ─────────────────────────────────
whisper_model     = None
bart_model        = None
bart_tokenizer    = None
device_str        = "cpu"

# ── ffmpeg path (imageio_ffmpeg) ─────────────────────────
FFMPEG_PATH = None
try:
    import imageio_ffmpeg
    FFMPEG_PATH = imageio_ffmpeg.get_ffmpeg_exe()
    log.info(f"ffmpeg: {FFMPEG_PATH}")
except Exception:
    log.warning("imageio_ffmpeg not found — trying system ffmpeg")
    FFMPEG_PATH = "ffmpeg"

# ════════════════════════════════════════════════════════
#   LOAD MODELS
# ════════════════════════════════════════════════════════

def load_whisper():
    global whisper_model, device_str
    try:
        import torch, whisper
        device_str   = "cuda" if torch.cuda.is_available() else "cpu"
        log.info(f"Loading Whisper-{WHISPER_MODEL_ID} on {device_str.upper()}...")
        whisper_model = whisper.load_model(WHISPER_MODEL_ID, device=device_str)
        log.info("✅  Whisper ready")
        return True
    except Exception as e:
        log.error(f"❌  Whisper failed: {e}")
        log.error("    pip install openai-whisper")
        return False


def load_bart():
    global bart_model, bart_tokenizer
    if not BART_MODEL_DIR.exists():
        log.warning(f"⚠️   BART model not found at {BART_MODEL_DIR}")
        log.warning("     Run: py -3.11 scripts/1_train_summarizer.py")
        log.warning("     Using rule-based fallback for summarisation")
        return False
    try:
        import torch
        from transformers import BartTokenizer, BartForConditionalGeneration
        log.info(f"Loading custom BART from {BART_MODEL_DIR}...")
        bart_tokenizer = BartTokenizer.from_pretrained(str(BART_MODEL_DIR))
        bart_model     = BartForConditionalGeneration.from_pretrained(
            str(BART_MODEL_DIR)
        ).to(device_str)
        bart_model.eval()
        log.info("✅  Custom BART summarizer ready")
        return True
    except Exception as e:
        log.error(f"❌  BART failed: {e}")
        return False


# ════════════════════════════════════════════════════════
#   AUDIO UTILITIES
# ════════════════════════════════════════════════════════

def convert_to_wav(input_path: str, output_path: str) -> bool:
    """Convert any audio format to 16kHz mono WAV using ffmpeg."""
    try:
        cmd = [
            FFMPEG_PATH, "-y",
            "-i", input_path,
            "-ar", "16000",
            "-ac", "1",
            "-c:a", "pcm_s16le",
            output_path
        ]
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30
        )
        return result.returncode == 0
    except Exception as e:
        log.warning(f"ffmpeg failed: {e}")
        return False


# ════════════════════════════════════════════════════════
#   SUMMARISATION UTILITIES
# ════════════════════════════════════════════════════════

STOPWORDS = {
    "the","a","an","is","are","was","were","be","been","being",
    "have","has","had","do","does","did","will","would","could",
    "should","may","might","shall","can","to","of","in","on",
    "at","by","for","with","about","and","but","or","nor","so",
    "yet","this","that","these","those","i","you","he","she",
    "it","we","they","what","which","who","when","where","how",
    "all","each","just","very","also","then","than","too","its",
    "our","your","their","my","his","her","not","only","same",
}

def extract_keywords(text: str, top_n: int = 8) -> list:
    words  = re.findall(r'\b[a-zA-Z]{4,}\b', text.lower())
    freq   = {}
    for w in words:
        if w not in STOPWORDS:
            freq[w] = freq.get(w, 0) + 1
    return [k for k, _ in sorted(freq.items(), key=lambda x: -x[1])[:top_n]]


def bart_summarize(text: str) -> str:
    """Run fine-tuned BART inference."""
    import torch
    inputs = bart_tokenizer(
        text, return_tensors="pt", max_length=512, truncation=True
    ).to(device_str)
    with torch.no_grad():
        ids = bart_model.generate(
            **inputs,
            max_new_tokens=130,
            min_length=30,
            num_beams=4,
            length_penalty=1.2,
            no_repeat_ngram_size=3,
            early_stopping=True,
        )
    return bart_tokenizer.decode(ids[0], skip_special_tokens=True).strip()


def rule_based_summarize(text: str) -> str:
    """Simple extractive fallback when BART is not available."""
    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if len(s.strip()) > 15]
    if not sentences:
        return text[:300]
    # Score by keyword density
    keywords = set(extract_keywords(text, top_n=15))
    def score(s):
        return sum(1 for w in s.lower().split() if w in keywords)
    ranked = sorted(sentences, key=score, reverse=True)
    top    = ranked[:min(4, len(ranked))]
    # Re-order by original position
    result = [s for s in sentences if s in top]
    return " ".join(result[:3])


CATEGORY_STYLES = {
    "lecture":   {"heading": "📚 Lecture Notes",   "points_label": "Key Concepts"},
    "meeting":   {"heading": "🗓️ Meeting Minutes",  "points_label": "Action Items"},
    "interview": {"heading": "🎙️ Interview Notes",  "points_label": "Key Responses"},
    "personal":  {"heading": "📝 Personal Note",    "points_label": "Key Points"},
    "general":   {"heading": "📄 Note Summary",     "points_label": "Key Points"},
}

def build_structured_summary(text: str, category: str = "general") -> dict:
    """Build structured summary using BART (or rule-based fallback)."""
    if bart_model is not None:
        raw = bart_summarize(text)
        method = "bart"
    else:
        raw = rule_based_summarize(text)
        method = "rule-based"

    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', raw) if len(s.strip()) > 10]
    overview   = sentences[0] if sentences else raw
    key_points = sentences[1:5] if len(sentences) > 1 else []

    # Top up key_points from original text if short
    if len(key_points) < 3:
        orig = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if len(s.strip()) > 20]
        key_points += orig[:max(0, 4 - len(key_points))]
    key_points = key_points[:5]

    keywords   = extract_keywords(text + " " + raw, top_n=8)
    conclusion = sentences[-1] if len(sentences) > 1 else raw

    style = CATEGORY_STYLES.get(category.lower(), CATEGORY_STYLES["general"])

    # Auto-generate title
    words = text.split()[:12]
    title = " ".join(words).rstrip(".,!?") + ("..." if len(text.split()) > 12 else "")

    return {
        "title":            title,
        "category_heading": style["heading"],
        "overview":         overview,
        "key_points":       key_points,
        "points_label":     style["points_label"],
        "keywords":         keywords,
        "conclusion":       conclusion,
        "raw_summary":      raw,
        "method":           method,
    }


# ════════════════════════════════════════════════════════
#   ENDPOINTS
# ════════════════════════════════════════════════════════

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":          "ok",
        "whisper_loaded":  whisper_model is not None,
        "bart_loaded":     bart_model is not None,
        "device":          device_str,
    })


@app.route("/transcribe", methods=["POST"])
def transcribe():
    if whisper_model is None:
        return jsonify({"error": "Whisper model not loaded"}), 503

    if "audio" not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files["audio"]
    suffix     = Path(audio_file.filename or "audio.m4a").suffix or ".m4a"
    log.info(f"📥  Received: {audio_file.filename}")

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp_in:
        audio_file.save(tmp_in.name)
        input_path = tmp_in.name

    wav_path = input_path.replace(suffix, ".wav")

    try:
        # Convert to WAV
        if suffix.lower() != ".wav":
            ok = convert_to_wav(input_path, wav_path)
            if not ok:
                wav_path = input_path   # try original

        # Transcribe
        t0     = time.time()
        result = whisper_model.transcribe(wav_path, fp16=(device_str == "cuda"))
        elapsed = time.time() - t0

        text = result["text"].strip()
        log.info(f"✅  [{elapsed:.1f}s] → \"{text[:60]}...\"")

        return jsonify({
            "text":     text,
            "language": result.get("language", "en"),
            "duration": elapsed,
        })

    except Exception as e:
        log.error(f"❌  Transcription error: {e}")
        return jsonify({"error": str(e)}), 400

    finally:
        for p in [input_path, wav_path]:
            try:
                os.unlink(p)
            except Exception:
                pass


@app.route("/summarise", methods=["POST"])
def summarise():
    data = request.get_json(silent=True) or {}
    text     = (data.get("text") or "").strip()
    category = (data.get("category") or "general").strip().lower()

    if not text:
        return jsonify({"error": "No text provided"}), 400

    log.info(f"📝  Summarising [{category}]: {len(text)} chars")
    t0 = time.time()

    try:
        result  = build_structured_summary(text, category)
        elapsed = time.time() - t0
        log.info(f"✅  Summarised in {elapsed:.1f}s using {result['method']}")
        result["processing_time"] = round(elapsed, 2)
        return jsonify(result)

    except Exception as e:
        log.error(f"❌  Summarisation error: {e}")
        return jsonify({"error": str(e)}), 500


# ════════════════════════════════════════════════════════
#   STARTUP
# ════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 60)
    print("  Note Lingo — AI Server")
    print("=" * 60)

    whisper_ok = load_whisper()
    bart_ok    = load_bart()

    if not whisper_ok:
        print("\n  ❌  Whisper failed to load.")
        print("       pip install openai-whisper")

    if not bart_ok:
        print("\n  ⚠️   BART not loaded — using rule-based fallback.")
        print("       Train it: py -3.11 scripts/1_train_summarizer.py")

    print("\n  🌐  Server running on http://0.0.0.0:5000")
    print("  📱  Make sure phone and PC are on the same WiFi")
    print("=" * 60)

    app.run(host="0.0.0.0", port=5000, debug=False)