#!/usr/bin/env python3
"""
STEP 4 — Evaluate Model Accuracy (WER Score)
=============================================
Tests your trained model on the test set and reports
Word Error Rate (WER) — the standard metric for speech models.

WER = (Substitutions + Deletions + Insertions) / Total Words
  0.0 = perfect  |  0.2 = 80% accurate  |  0.5 = 50% accurate

Usage:
    python scripts/4_evaluate_model.py
"""

import os
import json
import torch
import numpy as np
import soundfile as sf

try:
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
    import evaluate
    HAS_DEPS = True
except ImportError as e:
    print(f"❌  Missing: {e}")
    print("    pip install transformers evaluate")
    HAS_DEPS = False

MODEL_PATH = os.path.join("model", "final")
TEST_JSON  = os.path.join("dataset", "test.json")
SAMPLE_RATE = 16000

def main():
    if not HAS_DEPS:
        return

    print("=" * 60)
    print("📊  Note Lingo — Model Evaluation")
    print("=" * 60)

    # ── Check model exists ────────────────────────────────────────
    if not os.path.exists(MODEL_PATH):
        print(f"\n❌  Model not found at {MODEL_PATH}")
        print("    Train first: python scripts/3_train_model.py")
        return

    if not os.path.exists(TEST_JSON):
        print(f"\n❌  {TEST_JSON} not found")
        print("    Prepare data: python scripts/2_prepare_dataset.py")
        return

    # ── Load model ────────────────────────────────────────────────
    print(f"\n  📥  Loading model from {MODEL_PATH}...")
    device    = "cuda" if torch.cuda.is_available() else "cpu"
    processor = Wav2Vec2Processor.from_pretrained(MODEL_PATH)
    model     = Wav2Vec2ForCTC.from_pretrained(MODEL_PATH).to(device)
    model.eval()
    print(f"  ✅  Model loaded on {device.upper()}")

    # ── Load test data ────────────────────────────────────────────
    with open(TEST_JSON) as f:
        test_data = json.load(f)

    print(f"  📋  Test samples: {len(test_data)}")

    wer_metric = evaluate.load("wer")

    # ── Transcribe each test sample ───────────────────────────────
    print("\n  🔊  Transcribing test samples...\n")
    predictions = []
    references  = []
    errors      = []

    for i, item in enumerate(test_data):
        try:
            # Load audio
            audio, sr = sf.read(item["path"])
            if sr != SAMPLE_RATE:
                print(f"  ⚠️   Wrong sample rate {sr} for {item['file']}")
                continue

            # Process
            inputs = processor(
                audio,
                sampling_rate=SAMPLE_RATE,
                return_tensors="pt",
                padding=True,
            ).to(device)

            # Inference
            with torch.no_grad():
                logits = model(**inputs).logits

            # Decode
            pred_ids  = torch.argmax(logits, dim=-1)
            pred_text = processor.batch_decode(pred_ids)[0].lower().strip()
            ref_text  = item["transcript"].lower().strip()

            predictions.append(pred_text)
            references.append(ref_text)

            # Show first 5 examples
            if i < 5:
                match = "✅" if pred_text == ref_text else "❌"
                print(f"  Sample {i+1}:")
                print(f"    Reference:  {ref_text}")
                print(f"    Prediction: {pred_text}  {match}")
                print()

        except Exception as e:
            errors.append(str(e))

    if not predictions:
        print("❌  No predictions generated. Check your audio files.")
        return

    # ── Calculate WER ─────────────────────────────────────────────
    wer = wer_metric.compute(predictions=predictions, references=references)

    print("=" * 60)
    print(f"  📈  RESULTS")
    print("=" * 60)
    print(f"  Samples evaluated:  {len(predictions)}")
    print(f"  Errors skipped:     {len(errors)}")
    print()
    print(f"  WER (Word Error Rate): {wer:.4f}  ({(1-wer)*100:.1f}% accurate)")
    print()

    # Interpret WER
    if wer <= 0.05:
        grade = "🏆  Excellent — production quality"
    elif wer <= 0.15:
        grade = "🥇  Very Good — near-perfect for a project"
    elif wer <= 0.30:
        grade = "🥈  Good — clearly usable, mention in report"
    elif wer <= 0.50:
        grade = "🥉  Acceptable — needs more training data"
    else:
        grade = "⚠️   Poor — record more samples (50+ recommended)"

    print(f"  Rating: {grade}")
    print()

    # ── Per-sample WER breakdown ──────────────────────────────────
    print(f"  📝  Sample-by-sample breakdown:")
    for i, (pred, ref) in enumerate(zip(predictions, references)):
        sample_wer = wer_metric.compute(predictions=[pred], references=[ref])
        status = "✅" if sample_wer == 0 else ("🟡" if sample_wer < 0.3 else "❌")
        print(f"    {status}  [{i+1:02d}] WER={sample_wer:.2f}  |  {ref[:50]}")

    print()
    print(f"  💡  Tips to improve WER:")
    print(f"      • Record more samples (aim for 100+)")
    print(f"      • Speak clearly at consistent volume")
    print(f"      • Record in a quiet environment")
    print(f"      • Increase NUM_EPOCHS in train script")
    print(f"      • Use a bigger base model (wav2vec2-large)")

    print(f"\n  Next step: python flask_api/app.py")

if __name__ == "__main__":
    main()