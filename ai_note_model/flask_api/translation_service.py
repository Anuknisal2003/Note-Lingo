"""
============================================================
  Note Lingo — Translation Service
  Helsinki-NLP MarianMT local translation
  No API keys required — models auto-download from HuggingFace

  Supported languages:
    si=Sinhala, ta=Tamil, fr=French, de=German, es=Spanish,
    it=Italian, pt=Portuguese, nl=Dutch, ru=Russian, zh=Chinese,
    ja=Japanese, ko=Korean, ar=Arabic, hi=Hindi, tr=Turkish,
    pl=Polish, sv=Swedish
============================================================
"""

import re
import threading
import logging

log = logging.getLogger(__name__)

# ── Supported language display names ────────────────────
SUPPORTED_LANGUAGES: dict[str, str] = {
    'si': 'Sinhala',
    'ta': 'Tamil',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'it': 'Italian',
    'pt': 'Portuguese',
    'nl': 'Dutch',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'tr': 'Turkish',
    'pl': 'Polish',
    'sv': 'Swedish',
}

# ── Helsinki-NLP OPUS-MT model names ────────────────────
# Format: Helsinki-NLP/opus-mt-{src}-{tgt}
# Models are downloaded automatically on first use from HuggingFace.

_TO_EN_MODELS: dict[str, str] = {
    'si': 'Helsinki-NLP/opus-mt-si-en',
    'ta': 'Helsinki-NLP/opus-mt-dra-en',   # Dravidian group (includes Tamil)
    'fr': 'Helsinki-NLP/opus-mt-fr-en',
    'de': 'Helsinki-NLP/opus-mt-de-en',
    'es': 'Helsinki-NLP/opus-mt-es-en',
    'it': 'Helsinki-NLP/opus-mt-it-en',
    'pt': 'Helsinki-NLP/opus-mt-pt-en',
    'nl': 'Helsinki-NLP/opus-mt-nl-en',
    'ru': 'Helsinki-NLP/opus-mt-ru-en',
    'zh': 'Helsinki-NLP/opus-mt-zh-en',
    'ja': 'Helsinki-NLP/opus-mt-ja-en',
    'ko': 'Helsinki-NLP/opus-mt-ko-en',
    'ar': 'Helsinki-NLP/opus-mt-ar-en',
    'hi': 'Helsinki-NLP/opus-mt-hi-en',
    'tr': 'Helsinki-NLP/opus-mt-tr-en',
    'pl': 'Helsinki-NLP/opus-mt-pl-en',
    'sv': 'Helsinki-NLP/opus-mt-sv-en',
}

_FROM_EN_MODELS: dict[str, str] = {
    'si': 'Helsinki-NLP/opus-mt-en-si',
    'ta': 'Helsinki-NLP/opus-mt-en-dra',   # Dravidian group
    'fr': 'Helsinki-NLP/opus-mt-en-fr',
    'de': 'Helsinki-NLP/opus-mt-en-de',
    'es': 'Helsinki-NLP/opus-mt-en-es',
    'it': 'Helsinki-NLP/opus-mt-en-it',
    'pt': 'Helsinki-NLP/opus-mt-en-pt',
    'nl': 'Helsinki-NLP/opus-mt-en-nl',
    'ru': 'Helsinki-NLP/opus-mt-en-ru',
    'zh': 'Helsinki-NLP/opus-mt-en-zh',
    'ja': 'Helsinki-NLP/opus-mt-en-jap',   # Japanese uses 'jap' for target
    'ko': 'Helsinki-NLP/opus-mt-en-ko',
    'ar': 'Helsinki-NLP/opus-mt-en-ar',
    'hi': 'Helsinki-NLP/opus-mt-en-hi',
    'tr': 'Helsinki-NLP/opus-mt-en-tr',
    'pl': 'Helsinki-NLP/opus-mt-en-pl',
    'sv': 'Helsinki-NLP/opus-mt-en-sv',
}

# ── Model cache ──────────────────────────────────────────
_model_cache: dict = {}
_lock = threading.Lock()

# Split texts into ~80-word chunks so we stay well under the 512-token limit
_MAX_CHUNK_WORDS = 80


def _load_model(model_name: str):
    """Lazy-load and cache a MarianMT model + tokenizer pair."""
    if model_name in _model_cache:
        return _model_cache[model_name]

    with _lock:
        if model_name in _model_cache:
            return _model_cache[model_name]

        log.info(f"Loading translation model: {model_name}  (first use — may download)")
        try:
            from transformers import MarianMTModel, MarianTokenizer
            tokenizer = MarianTokenizer.from_pretrained(model_name)
            model = MarianMTModel.from_pretrained(model_name)
            model.eval()
            _model_cache[model_name] = (tokenizer, model)
            log.info(f"✅  Translation model ready: {model_name}")
            return tokenizer, model
        except Exception as e:
            log.error(f"❌  Failed to load {model_name}: {e}")
            raise


def _translate_chunk(text: str, model_name: str) -> str:
    """Translate a single chunk of text with the given model."""
    tokenizer, model = _load_model(model_name)
    import torch
    with torch.no_grad():
        inputs = tokenizer(
            [text],
            return_tensors='pt',
            padding=True,
            truncation=True,
            max_length=512,
        )
        translated_ids = model.generate(**inputs, max_new_tokens=512)
    return tokenizer.decode(translated_ids[0], skip_special_tokens=True)


def _split_into_chunks(text: str) -> list[str]:
    """Split text into sentence-boundary chunks within the word limit."""
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    chunks: list[str] = []
    current: list[str] = []
    current_words = 0

    for sent in sentences:
        words = len(sent.split())
        if current_words + words > _MAX_CHUNK_WORDS and current:
            chunks.append(' '.join(current))
            current = [sent]
            current_words = words
        else:
            current.append(sent)
            current_words += words

    if current:
        chunks.append(' '.join(current))

    return chunks if chunks else [text]


# ── Public API ───────────────────────────────────────────

def translate_to_english(text: str, source_lang: str) -> str:
    """
    Translate *text* from *source_lang* to English.

    Raises ValueError for unsupported languages.
    Raises RuntimeError if the model cannot be loaded.
    """
    if not text or not text.strip():
        return text

    if source_lang == 'en':
        return text

    model_name = _TO_EN_MODELS.get(source_lang)
    if not model_name:
        raise ValueError(
            f"Language '{source_lang}' is not supported for translation. "
            f"Supported: {', '.join(sorted(_TO_EN_MODELS))}"
        )

    log.info(f"Translating {source_lang}→en  ({len(text)} chars)  model={model_name}")
    chunks = _split_into_chunks(text)
    translated = [_translate_chunk(chunk, model_name) for chunk in chunks]
    result = ' '.join(translated)
    log.info(f"Translation {source_lang}→en done  ({len(result)} chars)")
    return result


def translate_from_english(text: str, target_lang: str) -> str:
    """
    Translate *text* from English to *target_lang*.

    Raises ValueError for unsupported languages.
    Raises RuntimeError if the model cannot be loaded.
    """
    if not text or not text.strip():
        return text

    if target_lang == 'en':
        return text

    model_name = _FROM_EN_MODELS.get(target_lang)
    if not model_name:
        raise ValueError(
            f"Language '{target_lang}' is not supported for translation. "
            f"Supported: {', '.join(sorted(_FROM_EN_MODELS))}"
        )

    log.info(f"Translating en→{target_lang}  ({len(text)} chars)  model={model_name}")
    chunks = _split_into_chunks(text)
    translated = [_translate_chunk(chunk, model_name) for chunk in chunks]
    result = ' '.join(translated)
    log.info(f"Translation en→{target_lang} done  ({len(result)} chars)")
    return result


def is_language_supported(lang: str) -> bool:
    """Return True if *lang* is a supported non-English language code."""
    return lang in SUPPORTED_LANGUAGES
