#!/usr/bin/env python3
"""
STEP 3 — Fine-tune Wav2Vec2 for Speech-to-Text
================================================
Fine-tunes facebook/wav2vec2-base on YOUR recorded dataset.

This is transfer learning:
  - Start with a powerful pre-trained model (knows phonetics)
  - Fine-tune it on YOUR voice + YOUR vocabulary
  - Result: a model that recognizes YOUR domain language

Usage:
    python scripts/3_train_model.py

Time estimates:
    50 samples,  CPU: ~1-2 hours
    50 samples,  GPU: ~15 minutes
    200 samples, CPU: ~5 hours
"""

import os
import json
import torch
import numpy as np
from dataclasses import dataclass
from typing import Dict, List, Optional, Union

# ── Check imports ─────────────────────────────────────────────────
try:
    from transformers import (
        Wav2Vec2CTCTokenizer,
        Wav2Vec2FeatureExtractor,
        Wav2Vec2Processor,
        Wav2Vec2ForCTC,
        TrainingArguments,
        Trainer,
    )
    from datasets import Dataset, Audio
    import soundfile as sf
    HAS_DEPS = True
except ImportError as e:
    HAS_DEPS = False
    print(f"❌  Missing dependency: {e}")
    print("\nInstall all dependencies:")
    print("  pip install transformers datasets soundfile accelerate evaluate")

# ── Paths ─────────────────────────────────────────────────────────
DATASET_DIR = "dataset"
TRAIN_JSON  = os.path.join(DATASET_DIR, "train.json")
TEST_JSON   = os.path.join(DATASET_DIR, "test.json")
VOCAB_JSON  = os.path.join(DATASET_DIR, "vocab.json")
MODEL_DIR   = "model"
CHECKPOINT_DIR = os.path.join(MODEL_DIR, "checkpoints")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(CHECKPOINT_DIR, exist_ok=True)

# ── Config ────────────────────────────────────────────────────────
BASE_MODEL  = "facebook/wav2vec2-base"   # ~360MB download, good for English
# For Sinhala/Tamil, use multilingual base:
# BASE_MODEL = "facebook/wav2vec2-large-xlsr-53"  # larger, more languages

SAMPLE_RATE = 16000
MAX_DURATION = 10.0   # seconds — skip samples longer than this

# Training hyperparameters
LEARNING_RATE     = 1e-4
BATCH_SIZE        = 4     # lower if you get out-of-memory errors (try 2 or 1)
GRADIENT_ACCUM    = 4     # effective batch = BATCH_SIZE * GRADIENT_ACCUM = 16
NUM_EPOCHS        = 30    # increase to 50-100 for more data
WARMUP_STEPS      = 50
SAVE_STEPS        = 100
EVAL_STEPS        = 100
LOGGING_STEPS     = 20

def main():
    if not HAS_DEPS:
        return

    print("=" * 60)
    print("🧠  Note Lingo — Wav2Vec2 Fine-tuning")
    print("=" * 60)

    # ── Device check ─────────────────────────────────────────────
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"\n  🖥️   Device: {device.upper()}")
    if device == "cpu":
        print("  ⏱️   Training on CPU — this will take 1-5 hours")
        print("       Consider using Google Colab for GPU (free):")
        print("       https://colab.research.google.com")
    else:
        gpu_name = torch.cuda.get_device_name(0)
        print(f"  🚀  GPU: {gpu_name} — training will be fast!")

    # ── Load data ─────────────────────────────────────────────────
    for path in [TRAIN_JSON, TEST_JSON, VOCAB_JSON]:
        if not os.path.exists(path):
            print(f"\n❌  {path} not found!")
            print("    Run step 2: python scripts/2_prepare_dataset.py")
            return

    with open(TRAIN_JSON) as f:
        train_data = json.load(f)
    with open(TEST_JSON) as f:
        test_data = json.load(f)
    with open(VOCAB_JSON) as f:
        vocab = json.load(f)

    print(f"\n  📊  Train: {len(train_data)} | Test: {len(test_data)}")

    # ── Build tokenizer from vocabulary ──────────────────────────
    print("\n  🔤  Building tokenizer...")
    # Save vocab to file for tokenizer
    vocab_path = os.path.join(MODEL_DIR, "vocab.json")
    with open(vocab_path, "w") as f:
        json.dump(vocab, f)

    tokenizer = Wav2Vec2CTCTokenizer(
        vocab_path,
        unk_token="[UNK]",
        pad_token="[PAD]",
        word_delimiter_token="|",
    )

    # ── Feature extractor ─────────────────────────────────────────
    feature_extractor = Wav2Vec2FeatureExtractor(
        feature_size=1,
        sampling_rate=SAMPLE_RATE,
        padding_value=0.0,
        do_normalize=True,
        return_attention_mask=True,
    )

    processor = Wav2Vec2Processor(
        feature_extractor=feature_extractor,
        tokenizer=tokenizer,
    )

    # Save processor
    processor.save_pretrained(MODEL_DIR)
    print(f"  ✅  Processor saved to {MODEL_DIR}/")

    # ── Load audio data ───────────────────────────────────────────
    print("\n  🎵  Loading audio files...")

    def load_sample(item: dict) -> Optional[dict]:
        """Load one audio file and prepare for training."""
        try:
            audio, sr = sf.read(item["path"])
            if sr != SAMPLE_RATE:
                # Should already be 16kHz from step 2, but just in case
                import librosa
                audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)

            # Skip if too long
            duration = len(audio) / SAMPLE_RATE
            if duration > MAX_DURATION:
                return None

            return {
                "input_values":  audio.astype(np.float32),
                "transcript":    item["transcript"],
            }
        except Exception as e:
            print(f"  ⚠️   Error loading {item.get('file', '?')}: {e}")
            return None

    train_samples = [s for item in train_data
                     if (s := load_sample(item)) is not None]
    test_samples  = [s for item in test_data
                     if (s := load_sample(item)) is not None]

    print(f"  ✅  Loaded: {len(train_samples)} train, {len(test_samples)} test")

    # ── Prepare labels ────────────────────────────────────────────
    def prepare_labels(samples: list) -> list:
        """Convert transcripts to token IDs."""
        for s in samples:
            # Replace spaces with | (Wav2Vec2 convention)
            text = s["transcript"].replace(" ", "|")
            # Encode
            with processor.as_target_processor():
                s["labels"] = processor(text).input_ids
        return samples

    train_samples = prepare_labels(train_samples)
    test_samples  = prepare_labels(test_samples)

    # ── Create HuggingFace datasets ───────────────────────────────
    train_dataset = Dataset.from_list(train_samples)
    test_dataset  = Dataset.from_list(test_samples)

    # ── Feature extraction ────────────────────────────────────────
    def preprocess_audio(batch):
        """Apply feature extraction to audio samples."""
        inputs = processor(
            batch["input_values"],
            sampling_rate=SAMPLE_RATE,
            return_tensors="pt",
            padding=True,
        )
        batch["input_values"]     = inputs.input_values[0]
        batch["attention_mask"]   = inputs.attention_mask[0]
        return batch

    print("\n  ⚙️   Preprocessing audio features...")
    train_dataset = train_dataset.map(
        preprocess_audio,
        remove_columns=["transcript"],
    )
    test_dataset = test_dataset.map(
        preprocess_audio,
        remove_columns=["transcript"],
    )

    # ── Data collator ─────────────────────────────────────────────
    @dataclass
    class DataCollatorCTCWithPadding:
        processor:  Wav2Vec2Processor
        padding:    Union[bool, str] = True

        def __call__(self, features: List[Dict]) -> Dict[str, torch.Tensor]:
            # Separate input values and labels
            input_features = [
                {"input_values": f["input_values"]} for f in features
            ]
            label_features = [{"input_ids": f["labels"]} for f in features]

            # Pad inputs
            batch = self.processor.pad(
                input_features,
                padding=self.padding,
                return_tensors="pt",
            )

            # Pad labels (-100 = ignore in loss)
            with self.processor.as_target_processor():
                labels_batch = self.processor.pad(
                    label_features,
                    padding=self.padding,
                    return_tensors="pt",
                )

            labels = labels_batch["input_ids"].masked_fill(
                labels_batch.attention_mask.ne(1), -100
            )
            batch["labels"] = labels
            return batch

    data_collator = DataCollatorCTCWithPadding(processor=processor)

    # ── WER metric ────────────────────────────────────────────────
    try:
        import evaluate
        wer_metric = evaluate.load("wer")
    except Exception:
        wer_metric = None
        print("  ⚠️   WER metric not available (install: pip install evaluate)")

    def compute_metrics(pred):
        pred_ids    = np.argmax(pred.predictions, axis=-1)
        pred_str    = processor.batch_decode(pred_ids)
        label_ids   = pred.label_ids
        label_ids[label_ids == -100] = processor.tokenizer.pad_token_id
        label_str   = processor.batch_decode(label_ids, group_tokens=False)

        if wer_metric:
            wer = wer_metric.compute(predictions=pred_str, references=label_str)
            return {"wer": wer}
        return {}

    # ── Load pre-trained model ────────────────────────────────────
    print(f"\n  📥  Loading base model: {BASE_MODEL}")
    print("      (First run downloads ~360MB — be patient)")

    model = Wav2Vec2ForCTC.from_pretrained(
        BASE_MODEL,
        ctc_loss_reduction="mean",
        pad_token_id=processor.tokenizer.pad_token_id,
        vocab_size=len(processor.tokenizer),
        ignore_mismatched_sizes=True,
    )

    # Freeze feature extractor — only train the transformer layers
    # This speeds up training significantly for small datasets
    model.freeze_feature_extractor()
    print("  ✅  Feature extractor frozen (training transformer layers only)")

    param_count = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"  📐  Trainable parameters: {param_count:,}")

    # ── Training arguments ────────────────────────────────────────
    training_args = TrainingArguments(
        output_dir=CHECKPOINT_DIR,
        group_by_length=True,           # group similar-length samples → faster
        per_device_train_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=GRADIENT_ACCUM,
        evaluation_strategy="steps",
        num_train_epochs=NUM_EPOCHS,
        fp16=device == "cuda",          # half precision on GPU for speed
        save_steps=SAVE_STEPS,
        eval_steps=EVAL_STEPS,
        logging_steps=LOGGING_STEPS,
        learning_rate=LEARNING_RATE,
        warmup_steps=WARMUP_STEPS,
        save_total_limit=2,             # keep only 2 checkpoints (saves disk)
        load_best_model_at_end=True,
        metric_for_best_model="wer" if wer_metric else "loss",
        greater_is_better=False,
        dataloader_num_workers=0,       # 0 = no multiprocessing (safer on Windows)
        report_to="none",               # disable wandb
    )

    # ── Trainer ───────────────────────────────────────────────────
    trainer = Trainer(
        model=model,
        data_collator=data_collator,
        args=training_args,
        compute_metrics=compute_metrics,
        train_dataset=train_dataset,
        eval_dataset=test_dataset,
        tokenizer=processor.feature_extractor,
    )

    # ── Start training ────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print(f"🚀  Starting training...")
    print(f"    Epochs: {NUM_EPOCHS}")
    print(f"    Batch size: {BATCH_SIZE} × {GRADIENT_ACCUM} accumulation")
    print(f"    Checkpoints: {CHECKPOINT_DIR}")
    print(f"{'=' * 60}\n")

    trainer.train()

    # ── Save final model ──────────────────────────────────────────
    final_model_path = os.path.join(MODEL_DIR, "final")
    trainer.save_model(final_model_path)
    processor.save_pretrained(final_model_path)

    print(f"\n{'=' * 60}")
    print("🎉  Training complete!")
    print(f"    Model saved: {final_model_path}/")
    print(f"\n    Next steps:")
    print(f"    1. Evaluate: python scripts/4_evaluate_model.py")
    print(f"    2. Test:     python scripts/5_test_transcribe.py")
    print(f"    3. Serve:    python flask_api/app.py")

if __name__ == "__main__":
    main()