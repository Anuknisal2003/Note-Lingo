"""
============================================================
  Note Lingo — Flask API Server
  Whisper transcription + Custom BART summarization
  With lazy loading, caching, and batch processing
============================================================
  Endpoints:
    GET  /health        → server status
    GET  /preload       → warmup models (async)
    POST /transcribe    → audio → text (Whisper)
    POST /summarise     → text  → structured summary (BART)
    GET  /cache/stats   → cache statistics

  Run: py -3.11 flask_api/app.py
============================================================
"""

import os, re, json, sys, time, logging, subprocess, tempfile, hashlib
import urllib.request
import urllib.error
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timedelta
import threading

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
WHISPER_MODEL_ID  = os.getenv("WHISPER_MODEL_ID", "medium")
BART_MODEL_DIR    = ROOT / "summarizer_model" / "final"


def _load_env_from_files():
    """Load KEY=VALUE entries from common project .env files."""
    candidates = [
        ROOT / '.env',
        ROOT.parent / 'note_lingo' / 'assets' / '.env',
    ]

    loaded_keys = set()
    for env_path in candidates:
        if not env_path.exists():
            continue
        try:
            for raw_line in env_path.read_text(encoding='utf-8').splitlines():
                line = raw_line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if not key:
                    continue
                # Respect already-exported environment values.
                if key not in os.environ:
                    os.environ[key] = value
                    loaded_keys.add(key)
        except Exception as e:
            log.warning(f"Could not read env file {env_path}: {e}")

    if loaded_keys:
        log.info(f"Loaded env keys: {', '.join(sorted(loaded_keys))}")


_load_env_from_files()

# ── Global model holders (lazy-loaded) ───────────────────
whisper_model     = None
bart_model        = None
bart_tokenizer    = None
device_str        = "cpu"
_models_loading   = False
_load_lock        = threading.Lock()

# ── Result caching (in-memory with TTL) ──────────────────
class ResultCache:
    def __init__(self, ttl_seconds: int = 3600):
        self.ttl = ttl_seconds
        self.cache = {}
        self.stats = {'hits': 0, 'misses': 0, 'size': 0}
    
    def _make_key(self, endpoint: str, data: str) -> str:
        """Generate cache key from endpoint + data hash."""
        return f"{endpoint}:{hashlib.sha256(data.encode()).hexdigest()[:16]}"
    
    def get(self, endpoint: str, data: str):
        """Get cached result if not expired."""
        key = self._make_key(endpoint, data)
        if key in self.cache:
            result, expiry = self.cache[key]
            if datetime.now() < expiry:
                self.stats['hits'] += 1
                log.info(f"Cache HIT for {endpoint} ({self.stats['hits']} hits)")
                return result
            else:
                del self.cache[key]
                self.stats['size'] = len(self.cache)
        self.stats['misses'] += 1
        return None
    
    def set(self, endpoint: str, data: str, result):
        """Store result with expiry."""
        key = self._make_key(endpoint, data)
        self.cache[key] = (result, datetime.now() + timedelta(seconds=self.ttl))
        self.stats['size'] = len(self.cache)
        log.info(f"Cache SET for {endpoint} (size={self.stats['size']})")
    
    def clear(self):
        """Clear expired entries."""
        now = datetime.now()
        expired = [k for k, (_, exp) in self.cache.items() if now >= exp]
        for k in expired:
            del self.cache[k]
        self.stats['size'] = len(self.cache)
        if expired:
            log.info(f"Cache cleanup: removed {len(expired)} expired entries")

_result_cache = ResultCache(ttl_seconds=3600)  # 1 hour TTL

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
#   LAZY MODEL LOADING
# ════════════════════════════════════════════════════════

def load_whisper():
    """Lazy-load Whisper model on first use."""
    global whisper_model, device_str
    if whisper_model is not None:
        return True  # Already loaded
    
    with _load_lock:
        if whisper_model is not None:  # Double-check after lock
            return True
        
        try:
            import torch, whisper
            device_str = "cuda" if torch.cuda.is_available() else "cpu"
            log.info(f"Lazy-loading Whisper-{WHISPER_MODEL_ID} on {device_str.upper()}...")
            whisper_model = whisper.load_model(WHISPER_MODEL_ID, device=device_str)
            log.info("✅  Whisper ready")
            return True
        except Exception as e:
            log.error(f"❌  Whisper failed: {e}")
            log.error("    pip install openai-whisper")
            return False


def load_bart():
    """Lazy-load BART model on first use."""
    global bart_model, bart_tokenizer
    if bart_model is not None:
        return True  # Already loaded
    
    with _load_lock:
        if bart_model is not None:  # Double-check after lock
            return True
        
        if not BART_MODEL_DIR.exists():
            log.warning(f"⚠️   BART model not found at {BART_MODEL_DIR}")
            log.warning("     Run: py -3.11 scripts/1_train_summarizer.py")
            log.warning("     Using rule-based fallback for summarisation")
            return False
        
        try:
            import torch
            from transformers import BartTokenizer, BartForConditionalGeneration
            log.info(f"Lazy-loading custom BART from {BART_MODEL_DIR}...")
            bart_tokenizer = BartTokenizer.from_pretrained(str(BART_MODEL_DIR))
            bart_model = BartForConditionalGeneration.from_pretrained(
                str(BART_MODEL_DIR)
            ).to(device_str)
            bart_model.eval()
            log.info("✅  Custom BART summarizer ready")
            return True
        except Exception as e:
            log.error(f"❌  BART failed: {e}")
            return False


def preload_models_async():
    """Background thread to preload models."""
    def _preload():
        log.info("🔄 Starting async model preload...")
        start = time.time()
        ok_whisper = load_whisper()
        ok_bart = load_bart()
        elapsed = time.time() - start
        if ok_whisper and ok_bart:
            log.info(f"✅  Both models preloaded in {elapsed:.1f}s")
        elif ok_whisper:
            log.info(f"⚠️   Whisper ready, BART fallback ({elapsed:.1f}s)")
        else:
            log.error(f"❌  Model preload failed ({elapsed:.1f}s)")
    
    thread = threading.Thread(target=_preload, daemon=True)
    thread.start()


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


def check_ffmpeg_filters() -> dict:
    """Check which advanced audio filters are available in ffmpeg."""
    filters = {'rnnoise': False, 'anlmdn': False, 'afftdn': False}
    try:
        result = subprocess.run(
            [FFMPEG_PATH, '-filters'], capture_output=True, text=True, timeout=5
        )
        output = result.stdout.lower()
        filters['rnnoise'] = 'rnnoise' in output
        filters['anlmdn'] = 'anlmdn' in output
        filters['afftdn'] = 'afftdn' in output
        log.info(f"Available ffmpeg filters: {filters}")
    except Exception:
        pass
    return filters


_AVAILABLE_FILTERS = check_ffmpeg_filters()

_LANGUAGE_HINT_ALIASES = {
    'english': 'en',
    'en-us': 'en',
    'en-gb': 'en',
    'sinhala': 'si',
    'sinhalese': 'si',
    'tamil': 'ta',
}


def normalize_language_hint(value: str | None) -> str | None:
    """Map user/UI language hints to Whisper language codes."""
    if not value:
        return None
    lang = value.strip().lower()
    if not lang or lang in {'auto', 'detect', 'default', 'none', 'null'}:
        return None
    lang = _LANGUAGE_HINT_ALIASES.get(lang, lang)
    return lang if re.fullmatch(r'[a-z]{2}', lang) else None


def denoise_audio(
    input_path: str,
    output_path: str,
    method: str = 'auto',
    strength: float = 1.0,
) -> bool:
    """Apply advanced noise reduction using ffmpeg.
    
    Methods:
      auto: Try rnnoise, fall back to spectral
      rnnoise: RNN-based denoising (best if available)
      spectral: FFT spectral subtraction (afftdn)
      aggressive: Multiple passes + gating
      light: Minimal filtering (highpass + lowpass)
    """
    try:
        strength = max(0.5, min(2.0, strength))
        filter_chain = ["highpass=f=200", "lowpass=f=3400"]
        
        if method == 'auto':
            method = 'rnnoise' if _AVAILABLE_FILTERS['rnnoise'] else 'spectral'
        
        if method == 'rnnoise' and _AVAILABLE_FILTERS['rnnoise']:
            log.info("Using RNNoise denoising")
            filter_chain.append("rnnoise=1")
        
        elif method == 'aggressive':
            log.info(f"Using aggressive spectral denoising (strength={strength:.1f})")
            if _AVAILABLE_FILTERS['anlmdn']:
                strength_param = int(min(200, 50 + strength * 100))
                filter_chain.append(f"anlmdn=s={strength_param}:f={strength_param}:t={strength_param}")
            if _AVAILABLE_FILTERS['afftdn']:
                filter_chain.append("afftdn=tn=1:tr=1:om=o")
        
        elif method == 'spectral':
            log.info(f"Using spectral denoising (strength={strength:.1f})")
            if _AVAILABLE_FILTERS['afftdn']:
                filter_chain.append("afftdn=tn=0:tr=1:om=o")
            elif _AVAILABLE_FILTERS['anlmdn']:
                filter_chain.append("anlmdn=s=100:f=100:t=100")
        
        elif method == 'light':
            log.info("Using light filtering")
            pass
        
        if method != 'light':
            filter_chain.append("loudnorm=I=-16:TP=-1.5:LRA=11")
        
        filter_str = ", ".join(filter_chain)
        
        cmd = [
            FFMPEG_PATH, "-y",
            "-i", input_path,
            "-af", filter_str,
            "-ar", "16000",
            "-ac", "1",
            "-c:a", "pcm_s16le",
            output_path,
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            log.warning(f"denoise failed: {result.stderr[:200]}")
            return False
        
        log.info(f"✅ Denoised with {method}")
        return True
    
    except Exception as e:
        log.warning(f"denoise error: {e}")
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
    # Lazy load BART on first use
    load_bart()  # Try to load, use fallback if fails
    
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
        "denoise_filters": _AVAILABLE_FILTERS,
        "cache_stats":     _result_cache.stats,
    })


@app.route("/preload", methods=["GET"])
def preload():
    """Trigger async model preloading (warm-up)."""
    preload_models_async()
    return jsonify({
        "status": "preload started",
        "message": "Models loading in background. Check /health to monitor progress."
    }), 202


@app.route("/cache/stats", methods=["GET"])
def cache_stats():
    """Get current cache statistics."""
    return jsonify({
        "cache": _result_cache.stats,
        "timestamp": datetime.now().isoformat(),
    })


@app.route("/cache/clear", methods=["POST"])
def cache_clear():
    """Clear cache and cleanup expired entries."""
    old_size = _result_cache.stats['size']
    _result_cache.clear()
    return jsonify({
        "message": f"Cache cleared (was {old_size} entries)",
        "current_size": _result_cache.stats['size'],
    })


@app.route("/transcribe", methods=["POST"])
def transcribe():
    # Lazy load Whisper on first use
    if not load_whisper():
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
    temp_paths = {input_path}
    pre_denoise_path = None
    language_hint = normalize_language_hint(
        request.form.get('language') or request.args.get('language')
    )

    try:
        # Convert to WAV
        if suffix.lower() != ".wav":
            ok = convert_to_wav(input_path, wav_path)
            if not ok:
                wav_path = input_path
            else:
                temp_paths.add(wav_path)
        pre_denoise_path = wav_path

        # Configurable denoising
        denoise_flag = request.form.get('denoise', '1').strip()
        if denoise_flag != '0':
            method = 'auto' if denoise_flag == '1' else denoise_flag
            strength = float(request.form.get('denoise_strength', '1.0'))
            
            denoised = wav_path.replace('.wav', '.denoised.wav')
            ok = denoise_audio(wav_path, denoised, method=method, strength=strength)
            if ok:
                wav_path = denoised
                temp_paths.add(wav_path)

        # Transcribe
        t0 = time.time()
        transcribe_kwargs = {
            "fp16": (device_str == "cuda"),
            "task": "transcribe",
            "condition_on_previous_text": False,
        }
        if language_hint:
            transcribe_kwargs["language"] = language_hint

        result = whisper_model.transcribe(wav_path, **transcribe_kwargs)
        elapsed = time.time() - t0

        text = result["text"].strip()

        if not text:
            log.warning("⚠️   Empty transcript on first pass; retrying with auto language")
            retry_kwargs = dict(transcribe_kwargs)
            retry_kwargs.pop("language", None)
            retry_source = pre_denoise_path or wav_path
            retry_result = whisper_model.transcribe(retry_source, **retry_kwargs)
            retry_text = (retry_result.get("text") or "").strip()
            if retry_text:
                result = retry_result
                text = retry_text
                log.info("✅  Retry transcription produced non-empty text")

        if len(text) < 3 and language_hint in {"si", "ta"}:
            log.warning(
                f"⚠️   Very short transcript for {language_hint}; retrying with robust decode"
            )
            robust_kwargs = {
                "fp16": (device_str == "cuda"),
                "task": "transcribe",
                "condition_on_previous_text": False,
                "language": language_hint,
                "temperature": (0.0, 0.2, 0.4, 0.6, 0.8, 1.0),
                "beam_size": 5,
                "best_of": 5,
            }
            robust_source = pre_denoise_path or wav_path
            robust_result = whisper_model.transcribe(robust_source, **robust_kwargs)
            robust_text = (robust_result.get("text") or "").strip()
            if robust_text:
                result = robust_result
                text = robust_text
                log.info("✅  Robust decode produced non-empty text")

        log.info(f"✅  [{elapsed:.1f}s] → \"{text[:60]}...\"")

        return jsonify({
            "text":     text,
            "language": result.get("language", "en"),
            "duration": elapsed,
            "cached": False,
        })

    except Exception as e:
        log.error(f"❌  Transcription error: {e}")
        return jsonify({"error": str(e)}), 400

    finally:
        for p in temp_paths:
            try:
                os.unlink(p)
            except Exception:
                pass


@app.route("/summarise", methods=["POST"])
def summarise():
    data = request.get_json(silent=True) or {}
    text     = (data.get("text") or "").strip()
    category = (data.get("category") or "general").strip().lower()
    use_cache = data.get("cache", True)  # Cache by default

    if not text:
        return jsonify({"error": "No text provided"}), 400

    log.info(f"📝  Summarising [{category}]: {len(text)} chars")
    
    # Try cache first
    cache_key = f"{text}_{category}"
    if use_cache:
        cached = _result_cache.get('summarise', cache_key)
        if cached:
            log.info(f"✅  Using cached summary")
            return jsonify({**cached, "cached": True, "processing_time": 0.0})
    
    t0 = time.time()
    try:
        result  = build_structured_summary(text, category)
        elapsed = time.time() - t0
        log.info(f"✅  Summarised in {elapsed:.1f}s using {result['method']}")
        result["processing_time"] = round(elapsed, 2)
        result["cached"] = False
        
        # Cache the result
        if use_cache:
            _result_cache.set('summarise', cache_key, result)
        
        return jsonify(result)

    except Exception as e:
        log.error(f"❌  Summarisation error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/extract_qa', methods=['POST'])
def extract_qa():
    data = request.get_json(silent=True) or {}
    text = (data.get('text') or '').strip()
    if not text:
        return jsonify({'error': 'No text provided'}), 400
    # Simple local Q&A extraction
    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if len(s.strip())>5]
    qa = []
    for i,s in enumerate(sentences[:-1]):
        if s.endswith('?') or s.lower().startswith(('what ','why ','how ','when ','where ','who ')):
            ans = sentences[i+1] if i+1 < len(sentences) else ''
            if len(ans) > 10:
                qa.append({'question': s, 'answer': ans})
    if not qa:
        # fallback quick items
        qa = [
            {'question': 'What is the main topic?', 'answer': sentences[0] if sentences else ''}
        ]
    return jsonify({'qa': qa, 'count': len(qa)})


@app.route('/detect_sentiment', methods=['POST'])
def detect_sentiment():
    data = request.get_json(silent=True) or {}
    text = (data.get('text') or '').strip().lower()
    if not text:
        return jsonify({'error': 'No text provided'}), 400
    positive = ['good','great','excellent','happy','love','awesome','positive']
    negative = ['bad','terrible','awful','hate','sad','problem','issue']
    p = sum(text.count(w) for w in positive)
    n = sum(text.count(w) for w in negative)
    score = 0.5
    sentiment = 'neutral'
    if p + n > 0:
        score = p / (p + n)
        if score > 0.6:
            sentiment = 'positive'
        elif score < 0.4:
            sentiment = 'negative'
    return jsonify({'sentiment': sentiment, 'score': round(score, 3)})


@app.route('/speaker_diarization', methods=['POST'])
def speaker_diarization():
    data = request.get_json(silent=True) or {}
    text = (data.get('text') or '').strip()
    if not text:
        return jsonify({'error': 'No text provided'}), 400
    speakers = set()
    for m in re.finditer(r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*:', text):
        speakers.add(m.group(1))
    # simple fallback: label segments as Speaker 1..N by splitting on line breaks
    if not speakers:
        parts = [p.strip() for p in re.split(r'\n+', text) if len(p.strip())>20]
        spk_labels = [f"Speaker {i+1}" for i in range(min(4, len(parts)))]
        return jsonify({'speakers': spk_labels, 'segments': len(parts)})
    return jsonify({'speakers': list(speakers), 'count': len(speakers)})


@app.route('/related_notes', methods=['POST'])
def related_notes():
    data = request.get_json(silent=True) or {}
    text = (data.get('text') or '').strip()
    if not text:
        return jsonify({'error': 'No text provided'}), 400
    # Return keywords as related signals; real implementation would query DB
    keywords = extract_keywords(text, top_n=6)
    return jsonify({'keywords': keywords, 'related': []})


@app.route('/denoise_info', methods=['GET'])
def denoise_info():
    """Get available denoising methods and current configuration."""
    return jsonify({
        'available_methods': ['auto', 'light', 'spectral', 'aggressive', 'rnnoise'],
        'available_filters': _AVAILABLE_FILTERS,
        'default_method': 'auto',
        'default_strength': 1.0,
        'help': {
            'auto': 'Automatically choose best available method',
            'light': 'Minimal filtering (highpass + lowpass only)',
            'spectral': 'FFT-based spectral subtraction',
            'aggressive': 'Multiple passes with noise gating',
            'rnnoise': 'RNN-based denoising (best if available)',
        }
    })


@app.route('/denoise_test', methods=['POST'])
def denoise_test():
    """Test denoising on a sample audio file (returns the denoised path)."""
    if 'audio' not in request.files:
        return jsonify({'error': 'No audio file provided'}), 400
    
    method = request.form.get('method', 'auto')
    strength = float(request.form.get('strength', '1.0'))
    
    audio_file = request.files['audio']
    suffix = Path(audio_file.filename or 'audio.m4a').suffix or '.m4a'
    
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp_in:
        audio_file.save(tmp_in.name)
        input_path = tmp_in.name
    
    wav_path = input_path.replace(suffix, '.wav')
    denoised_path = wav_path.replace('.wav', '.denoised.wav')
    
    try:
        if suffix.lower() != '.wav':
            ok = convert_to_wav(input_path, wav_path)
            if not ok:
                wav_path = input_path
        
        ok = denoise_audio(wav_path, denoised_path, method=method, strength=strength)
        if ok:
            return jsonify({
                'success': True,
                'method': method,
                'strength': strength,
                'message': f'Denoised using {method} method'
            })
        else:
            return jsonify({'error': 'Denoising failed'}), 500
    
    except Exception as e:
        log.error(f"denoise_test error: {e}")
        return jsonify({'error': str(e)}), 400
    
    finally:
        try:
            os.unlink(input_path)
        except:
            pass


# ════════════════════════════════════════════════════════
#   STARTUP
# ════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════
#   STARTUP
# ════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 60)
    print("  Note Lingo — AI Server")
    print("=" * 60)
    print("\n  🚀  Lazy-loading enabled:")
    print("      - Models load on first request (faster startup)")
    print("      - Use GET /preload to warm up models in background")
    print("      - Use GET /cache/stats to monitor cache performance")
    print("=" * 60)

    # Optional: Start async preload in background
    # Uncomment to warm models while server starts:
    # preload_models_async()

    print("\n  🌐  Server running on http://0.0.0.0:5000")
    print("  📱  Make sure phone and PC are on the same WiFi")
    print("=" * 60)

    app.run(host="0.0.0.0", port=5000, debug=False)