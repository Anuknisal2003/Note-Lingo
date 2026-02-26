#!/usr/bin/env python3
"""
STEP 5 — Transcribe a Single Audio File
========================================
Quick test to transcribe any .wav file with your trained model.

Usage:
    python scripts/5_test_transcribe.py path/to/audio.wav
    python scripts/5_test_transcribe.py              # uses mic
"""

import sys
import os
import time
import torch
import numpy as np

try:
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
    import soundfile as sf
    HAS_DEPS = True
except ImportError as e:
    print(f"❌  {e}")
    HAS_DEPS = False

MODEL_PATH  = os.path.join("model", "final")
SAMPLE_RATE = 16000

def transcribe(audio: np.ndarray) -> str:
    """Transcribe audio array → text string."""
    device    = "cuda" if torch.cuda.is_available() else "cpu"
    processor = Wav2Vec2Processor.from_pretrained(MODEL_PATH)
    model     = Wav2Vec2ForCTC.from_pretrained(MODEL_PATH).to(device)
    model.eval()

    inputs = processor(
        audio,
        sampling_rate=SAMPLE_RATE,
        return_tensors="pt",
        padding=True,
    ).to(device)

    t0 = time.time()
    with torch.no_grad():
        logits = model(**inputs).logits

    pred_ids = torch.argmax(logits, dim=-1)
    text     = processor.batch_decode(pred_ids)[0].lower().strip()
    elapsed  = time.time() - t0

    return text, elapsed

def record_from_mic(seconds: int = 5) -> np.ndarray:
    """Record from microphone."""
    try:
        import sounddevice as sd
    except ImportError:
        print("❌  sounddevice not installed: pip install sounddevice")
        sys.exit(1)

    print(f"\n  🔴  Recording for {seconds} seconds... speak now!")
    audio = sd.rec(
        int(seconds * SAMPLE_RATE),
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="float32",
    )
    sd.wait()
    return audio[:, 0]

def main():
    if not HAS_DEPS:
        return

    if not os.path.exists(MODEL_PATH):
        print(f"❌  Model not found at {MODEL_PATH}")
        print("    Train first: python scripts/3_train_model.py")
        return

    print("=" * 50)
    print("🎙️  Note Lingo — Quick Transcription Test")
    print("=" * 50)

    # ── Source: file arg or microphone ───────────────────────────
    if len(sys.argv) > 1:
        audio_path = sys.argv[1]
        if not os.path.exists(audio_path):
            print(f"❌  File not found: {audio_path}")
            return
        print(f"\n  📁  File: {audio_path}")
        audio, sr = sf.read(audio_path)
        if audio.ndim > 1:
            audio = audio[:, 0]     # take left channel if stereo
        if sr != SAMPLE_RATE:
            import librosa
            audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
    else:
        secs  = int(input("\n  How many seconds to record? (default 5): ").strip() or "5")
        audio = record_from_mic(secs)

    # ── Transcribe ────────────────────────────────────────────────
    print("\n  🧠  Transcribing...")
    text, elapsed = transcribe(audio.astype(np.float32))

    print(f"\n  ✅  Result:")
    print(f"  ┌─────────────────────────────────────────┐")
    print(f"  │  {text:<41}│")
    print(f"  └─────────────────────────────────────────┘")
    print(f"\n  ⏱️   Inference time: {elapsed:.2f}s")
    print(f"  📏  Audio length:   {len(audio)/SAMPLE_RATE:.1f}s")
    print(f"  🔢  Words:          {len(text.split())}")

if __name__ == "__main__":
    main()