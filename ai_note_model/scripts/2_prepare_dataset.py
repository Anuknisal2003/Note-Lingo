#!/usr/bin/env python3
"""
STEP 2 — Prepare & Validate Dataset
=====================================
Reads your dataset/metadata.csv, validates audio files,
normalizes them to 16kHz mono WAV, builds character vocabulary,
and creates train/test splits ready for training.

Usage:
    python scripts/2_prepare_dataset.py
"""

import os
import csv
import json
import shutil
import random
import re
from pathlib import Path
from collections import Counter

# ── Try imports ───────────────────────────────────────────────────
try:
    import numpy as np
    import librosa
    import soundfile as sf
    HAS_AUDIO_LIBS = True
except ImportError:
    HAS_AUDIO_LIBS = False
    print("⚠️  librosa / soundfile not installed.")
    print("   Run: pip install librosa soundfile\n")

# ── Paths ─────────────────────────────────────────────────────────
DATASET_DIR   = "dataset"
AUDIO_DIR     = os.path.join(DATASET_DIR, "audio")
PREPARED_DIR  = os.path.join(DATASET_DIR, "prepared")
METADATA_CSV  = os.path.join(DATASET_DIR, "metadata.csv")
TRAIN_JSON    = os.path.join(DATASET_DIR, "train.json")
TEST_JSON     = os.path.join(DATASET_DIR, "test.json")
VOCAB_JSON    = os.path.join(DATASET_DIR, "vocab.json")

os.makedirs(PREPARED_DIR, exist_ok=True)

SAMPLE_RATE = 16000
TEST_SPLIT  = 0.2   # 20% for testing
RANDOM_SEED = 42

# ── Text cleaning ─────────────────────────────────────────────────
def clean_text(text: str) -> str:
    """
    Normalize transcript text.
    Keeps only letters, spaces, apostrophes.
    Lowercases everything.
    """
    text = text.lower().strip()
    # Keep only a-z, spaces, apostrophes
    text = re.sub(r"[^a-z\s']", "", text)
    # Collapse multiple spaces
    text = re.sub(r"\s+", " ", text).strip()
    return text

# ── Audio normalization ───────────────────────────────────────────
def normalize_audio(src_path: str, dst_path: str) -> float:
    """
    Load any audio file, resample to 16kHz mono, save as WAV.
    Returns duration in seconds.
    """
    if not HAS_AUDIO_LIBS:
        shutil.copy(src_path, dst_path)
        return 0.0

    audio, sr = librosa.load(src_path, sr=SAMPLE_RATE, mono=True)
    sf.write(dst_path, audio, SAMPLE_RATE)
    return len(audio) / SAMPLE_RATE

# ── Build vocabulary ──────────────────────────────────────────────
def build_vocab(transcripts: list[str]) -> dict:
    """
    Build character-level vocabulary from all transcripts.
    Wav2Vec2 works at character level — each character gets an ID.
    """
    all_chars = set()
    for text in transcripts:
        all_chars.update(list(text))

    # Sort for consistency
    vocab = sorted(all_chars)

    # Build char → index mapping
    # Special tokens Wav2Vec2 needs:
    vocab_dict = {char: idx for idx, char in enumerate(vocab)}

    # Add special tokens
    vocab_dict["|"] = len(vocab_dict)   # word boundary (space replacement)
    vocab_dict["[UNK]"] = len(vocab_dict)
    vocab_dict["[PAD]"] = len(vocab_dict)

    # Replace space with | (standard Wav2Vec2 convention)
    if " " in vocab_dict:
        del vocab_dict[" "]

    return vocab_dict

# ── Main ──────────────────────────────────────────────────────────
def prepare_dataset():
    print("=" * 60)
    print("🔧  Note Lingo — Dataset Preparation")
    print("=" * 60)

    # ── 1. Load metadata ─────────────────────────────────────────
    if not os.path.exists(METADATA_CSV):
        print(f"❌  {METADATA_CSV} not found!")
        print("    Run step 1 first: python scripts/1_record_dataset.py")
        return

    samples = []
    with open(METADATA_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            samples.append(row)

    print(f"\n  📊  Found {len(samples)} samples in metadata.csv")

    if len(samples) < 10:
        print("  ⚠️   You need at least 10 samples to train.")
        print("       Record more with: python scripts/1_record_dataset.py")
        return

    # ── 2. Validate + normalize audio ────────────────────────────
    valid_samples = []
    skipped = 0

    print("\n  🔍  Validating and normalizing audio files...")
    for i, sample in enumerate(samples):
        src_path = os.path.join(AUDIO_DIR, sample["file"])

        if not os.path.exists(src_path):
            print(f"  ⚠️   Missing: {sample['file']} — skipping")
            skipped += 1
            continue

        # Normalize and save to prepared/
        dst_path = os.path.join(PREPARED_DIR, sample["file"])

        try:
            duration = normalize_audio(src_path, dst_path)
        except Exception as e:
            print(f"  ⚠️   Error processing {sample['file']}: {e}")
            skipped += 1
            continue

        # Clean transcript
        transcript = clean_text(sample["transcript"])
        if len(transcript) < 3:
            print(f"  ⚠️   Transcript too short: '{transcript}' — skipping")
            skipped += 1
            continue

        valid_samples.append({
            "file":       sample["file"],
            "path":       os.path.abspath(dst_path),
            "transcript": transcript,
            "duration":   duration,
        })

        if (i + 1) % 10 == 0:
            print(f"  ✅  Processed {i + 1}/{len(samples)}...")

    print(f"\n  📊  Valid: {len(valid_samples)}  |  Skipped: {skipped}")

    if len(valid_samples) < 5:
        print("  ❌  Not enough valid samples to continue.")
        return

    # ── 3. Statistics ─────────────────────────────────────────────
    if valid_samples and valid_samples[0]["duration"] > 0:
        durations = [s["duration"] for s in valid_samples]
        total_hours = sum(durations) / 3600
        print(f"\n  🕐  Total audio: {sum(durations):.0f}s ({total_hours:.3f} hours)")
        print(f"      Avg duration: {sum(durations)/len(durations):.1f}s")
        print(f"      Min: {min(durations):.1f}s  Max: {max(durations):.1f}s")

    # ── 4. Build vocabulary ───────────────────────────────────────
    all_transcripts = [s["transcript"] for s in valid_samples]
    vocab = build_vocab(all_transcripts)

    with open(VOCAB_JSON, "w", encoding="utf-8") as f:
        json.dump(vocab, f, indent=2, ensure_ascii=False)

    print(f"\n  🔤  Vocabulary: {len(vocab)} characters")
    readable_chars = [k for k in vocab.keys() if k not in ["[UNK]", "[PAD]", "|"]]
    print(f"      Characters: {''.join(sorted(readable_chars))}")

    # ── 5. Train / Test split ─────────────────────────────────────
    random.seed(RANDOM_SEED)
    random.shuffle(valid_samples)

    split_idx  = int(len(valid_samples) * (1 - TEST_SPLIT))
    train_data = valid_samples[:split_idx]
    test_data  = valid_samples[split_idx:]

    # Save JSON manifests
    with open(TRAIN_JSON, "w", encoding="utf-8") as f:
        json.dump(train_data, f, indent=2, ensure_ascii=False)

    with open(TEST_JSON, "w", encoding="utf-8") as f:
        json.dump(test_data, f, indent=2, ensure_ascii=False)

    print(f"\n  📂  Split:")
    print(f"      Train: {len(train_data)} samples → {TRAIN_JSON}")
    print(f"      Test:  {len(test_data)} samples  → {TEST_JSON}")

    # ── 6. Word frequency analysis ────────────────────────────────
    all_words = []
    for s in valid_samples:
        all_words.extend(s["transcript"].split())
    word_freq = Counter(all_words)
    print(f"\n  📝  Vocabulary stats:")
    print(f"      Unique words: {len(word_freq)}")
    print(f"      Most common: {', '.join([w for w, _ in word_freq.most_common(10)])}")

    # ── 7. Summary ────────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print("✅  Dataset prepared successfully!")
    print(f"\n  Files created:")
    print(f"    {TRAIN_JSON}")
    print(f"    {TEST_JSON}")
    print(f"    {VOCAB_JSON}")
    print(f"\n  Next step: python scripts/3_train_model.py")

    # ── 8. Quality check warnings ─────────────────────────────────
    print(f"\n  {'⚠️  Warnings' if len(valid_samples) < 50 else '💡  Tips'}:")
    if len(valid_samples) < 50:
        print(f"  ⚠️  Only {len(valid_samples)} samples — model accuracy will be limited.")
        print(f"      50+ samples recommended. 200+ for good accuracy.")
    else:
        print(f"  ✅  Good dataset size!")

    if len(valid_samples) < 100:
        print(f"  💡  For a university project, {len(valid_samples)} samples is acceptable.")
        print(f"      Mention dataset size as a limitation in your report.")

if __name__ == "__main__":
    prepare_dataset()