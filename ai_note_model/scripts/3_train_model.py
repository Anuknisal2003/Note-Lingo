#!/usr/bin/env python3
"""
STEP 3 — Fine-tune Wav2Vec2 for Speech-to-Text
================================================
FIXED: Removed deprecated as_target_processor() — works with
       latest transformers library versions.

GPU: Optimized for RTX 2050 4GB VRAM.

Usage:
    python scripts/3_train_model.py
"""

import os
import json
import torch
import numpy as np
from dataclasses import dataclass
from typing import Dict, List, Optional, Union

try:
    from transformers import (
        Wav2Vec2CTCTokenizer,
        Wav2Vec2FeatureExtractor,
        Wav2Vec2Processor,
        Wav2Vec2ForCTC,
        TrainingArguments,
        Trainer,
    )
    from datasets import Dataset
    import soundfile as sf
    HAS_DEPS = True
except ImportError as e:
    HAS_DEPS = False
    print(f"❌  Missing dependency: {e}")
    print("    pip install transformers datasets soundfile accelerate evaluate")

# ── Paths ─────────────────────────────────────────────────────────
DATASET_DIR    = "dataset"
TRAIN_JSON     = os.path.join(DATASET_DIR, "train.json")
TEST_JSON      = os.path.join(DATASET_DIR, "test.json")
VOCAB_JSON     = os.path.join(DATASET_DIR, "vocab.json")
MODEL_DIR      = "model"
CHECKPOINT_DIR = os.path.join(MODEL_DIR, "checkpoints")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(CHECKPOINT_DIR, exist_ok=True)

# ── Config ────────────────────────────────────────────────────────
BASE_MODEL   = "facebook/wav2vec2-base"
SAMPLE_RATE  = 16000
MAX_DURATION = 10.0   # skip audio longer than this (seconds)

# ── Training hyperparameters ──────────────────────────────────────
# Tuned for RTX 2050 4GB VRAM
LEARNING_RATE  = 1e-4
BATCH_SIZE     = 2     # 2 is safe for 4GB VRAM — increase to 4 if no OOM error
GRADIENT_ACCUM = 8     # effective batch = 2 × 8 = 16
NUM_EPOCHS     = 50    # more epochs to compensate for small dataset
WARMUP_STEPS   = 50
SAVE_STEPS     = 100
EVAL_STEPS     = 100
LOGGING_STEPS  = 10

# ─────────────────────────────────────────────────────────────────
def main():
    if not HAS_DEPS:
        return

    print("=" * 60)
    print("🧠  Note Lingo — Wav2Vec2 Fine-tuning  (FIXED)")
    print("=" * 60)

    # ── Device ───────────────────────────────────────────────────
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"\n  🖥️   Device: {device.upper()}")
    if device == "cuda":
        gpu_name = torch.cuda.get_device_name(0)
        vram     = torch.cuda.get_device_properties(0).total_memory / 1024**3
        print(f"  🚀  GPU: {gpu_name}")
        print(f"  💾  VRAM: {vram:.1f} GB")
        print(f"  ⚡  fp16 (half precision) enabled — faster + less VRAM")
    else:
        print("  ⏱️   Training on CPU — this will take 1-5 hours")
        print("       You have an RTX 2050 — install CUDA PyTorch:")
        print("       pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118")

    # ── Load data ─────────────────────────────────────────────────
    for path in [TRAIN_JSON, TEST_JSON, VOCAB_JSON]:
        if not os.path.exists(path):
            print(f"\n❌  {path} not found!")
            print("    Run: python scripts/2_prepare_dataset.py")
            return

    with open(TRAIN_JSON) as f:
        train_data = json.load(f)
    with open(TEST_JSON) as f:
        test_data = json.load(f)
    with open(VOCAB_JSON) as f:
        vocab = json.load(f)

    print(f"\n  📊  Train: {len(train_data)} | Test: {len(test_data)}")

    # ── Build tokenizer ───────────────────────────────────────────
    print("\n  🔤  Building tokenizer...")
    vocab_path = os.path.join(MODEL_DIR, "vocab.json")
    with open(vocab_path, "w") as f:
        json.dump(vocab, f)

    tokenizer = Wav2Vec2CTCTokenizer(
        vocab_path,
        unk_token="[UNK]",
        pad_token="[PAD]",
        word_delimiter_token="|",
    )

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
    processor.save_pretrained(MODEL_DIR)
    print(f"  ✅  Processor saved to {MODEL_DIR}/")

    # ── Load audio files ──────────────────────────────────────────
    print("\n  🎵  Loading audio files...")

    def load_sample(item: dict) -> Optional[dict]:
        try:
            audio, sr = sf.read(item["path"])
            if sr != SAMPLE_RATE:
                import librosa
                audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
            if len(audio) / SAMPLE_RATE > MAX_DURATION:
                return None
            return {
                "input_values": audio.astype(np.float32),
                "transcript":   item["transcript"],
            }
        except Exception as e:
            print(f"  ⚠️   Error loading {item.get('file', '?')}: {e}")
            return None

    train_samples = [s for item in train_data if (s := load_sample(item)) is not None]
    test_samples  = [s for item in test_data  if (s := load_sample(item)) is not None]
    print(f"  ✅  Loaded: {len(train_samples)} train, {len(test_samples)} test")

    # ── Prepare labels ────────────────────────────────────────────
    # FIX: Use tokenizer directly instead of deprecated as_target_processor()
    def prepare_labels(samples: list) -> list:
        for s in samples:
            text = s["transcript"].replace(" ", "|")
            # ✅ FIXED — call tokenizer directly, no as_target_processor()
            s["labels"] = tokenizer(text).input_ids
        return samples

    train_samples = prepare_labels(train_samples)
    test_samples  = prepare_labels(test_samples)

    # ── HuggingFace Dataset ───────────────────────────────────────
    train_dataset = Dataset.from_list(train_samples)
    test_dataset  = Dataset.from_list(test_samples)

    # ── Feature extraction ────────────────────────────────────────
    def preprocess_audio(batch):
        inputs = processor(
            batch["input_values"],
            sampling_rate=SAMPLE_RATE,
            return_tensors="pt",
            padding=True,
        )
        batch["input_values"]   = inputs.input_values[0]
        batch["attention_mask"] = inputs.attention_mask[0]
        return batch

    print("\n  ⚙️   Preprocessing audio features...")
    train_dataset = train_dataset.map(preprocess_audio, remove_columns=["transcript"])
    test_dataset  = test_dataset.map(preprocess_audio,  remove_columns=["transcript"])

    # ── Data collator ─────────────────────────────────────────────
    # FIX: Use tokenizer.pad() directly instead of as_target_processor()
    @dataclass
    class DataCollatorCTCWithPadding:
        processor: Wav2Vec2Processor
        padding:   Union[bool, str] = True

        def __call__(self, features: List[Dict]) -> Dict[str, torch.Tensor]:
            input_features = [{"input_values": f["input_values"]} for f in features]
            label_features = [{"input_ids":    f["labels"]}       for f in features]

            # Pad audio inputs
            batch = self.processor.pad(
                input_features,
                padding=self.padding,
                return_tensors="pt",
            )

            # ✅ FIXED — pad labels using tokenizer directly
            labels_batch = self.processor.tokenizer.pad(
                label_features,
                padding=self.padding,
                return_tensors="pt",
            )

            # Replace padding token id with -100 so it's ignored in loss
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
        print("  ✅  WER metric loaded")
    except Exception:
        wer_metric = None
        print("  ⚠️   WER metric not available (pip install evaluate)")

    def compute_metrics(pred):
        pred_ids  = np.argmax(pred.predictions, axis=-1)
        pred_str  = processor.batch_decode(pred_ids)
        label_ids = pred.label_ids
        label_ids[label_ids == -100] = processor.tokenizer.pad_token_id
        label_str = processor.batch_decode(label_ids, group_tokens=False)
        if wer_metric:
            wer = wer_metric.compute(predictions=pred_str, references=label_str)
            return {"wer": round(wer, 4)}
        return {}

    # ── Load model ────────────────────────────────────────────────
    print(f"\n  📥  Loading base model: {BASE_MODEL}")
    print("      (First run downloads ~360MB — be patient)")

    model = Wav2Vec2ForCTC.from_pretrained(
        BASE_MODEL,
        ctc_loss_reduction="mean",
        pad_token_id=processor.tokenizer.pad_token_id,
        vocab_size=len(processor.tokenizer),
        ignore_mismatched_sizes=True,
    )

    # Freeze CNN feature extractor — only train transformer layers
    # This is critical for small datasets — prevents overfitting
    model.freeze_feature_encoder()   # newer API name
    print("  ✅  Feature encoder frozen")

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total     = sum(p.numel() for p in model.parameters())
    print(f"  📐  Trainable: {trainable:,} / {total:,} parameters")

    # ── Training arguments ────────────────────────────────────────
    use_fp16 = device == "cuda"   # half precision on GPU only

    training_args = TrainingArguments(
        output_dir=CHECKPOINT_DIR,
        per_device_train_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=GRADIENT_ACCUM,
        eval_strategy="steps",          # newer API (was evaluation_strategy)
        num_train_epochs=NUM_EPOCHS,
        fp16=use_fp16,
        save_steps=SAVE_STEPS,
        eval_steps=EVAL_STEPS,
        logging_steps=LOGGING_STEPS,
        learning_rate=LEARNING_RATE,
        warmup_steps=WARMUP_STEPS,
        save_total_limit=2,
        load_best_model_at_end=True,
        metric_for_best_model="wer" if wer_metric else "loss",
        greater_is_better=False,
        dataloader_num_workers=0,       # 0 = required on Windows
        report_to="none",
        # RTX 2050 optimizations
        gradient_checkpointing=True,    # saves VRAM at cost of small speed hit
        optim="adamw_torch",
    )

    # ── Trainer ───────────────────────────────────────────────────
    trainer = Trainer(
        model=model,
        data_collator=data_collator,
        args=training_args,
        compute_metrics=compute_metrics,
        train_dataset=train_dataset,
        eval_dataset=test_dataset,
        processing_class=processor.feature_extractor,  # newer API
    )

    # ── Train ─────────────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print(f"🚀  Starting training...")
    print(f"    Epochs:     {NUM_EPOCHS}")
    print(f"    Batch:      {BATCH_SIZE} × {GRADIENT_ACCUM} = {BATCH_SIZE * GRADIENT_ACCUM} effective")
    print(f"    fp16:       {use_fp16}")
    print(f"    Device:     {device.upper()}")
    print(f"{'=' * 60}\n")

    trainer.train()

    # ── Save final model ──────────────────────────────────────────
    final_path = os.path.join(MODEL_DIR, "final")
    trainer.save_model(final_path)
    processor.save_pretrained(final_path)

    print(f"\n{'=' * 60}")
    print("🎉  Training complete!")
    print(f"    Model saved: {final_path}/")
    print(f"\n    Next steps:")
    print(f"    1. Evaluate: python scripts/4_evaluate_model.py")
    print(f"    2. Test:     python scripts/5_test_transcribe.py")
    print(f"    3. Serve:    python flask_api/app.py")

if __name__ == "__main__":
    main()