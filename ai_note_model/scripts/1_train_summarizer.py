"""
============================================================
  Note Lingo — Step 1: Fine-tune BART for Summarization
============================================================
  Model:   facebook/bart-large-cnn  (pretrained on news)
  Dataset: SAMSum + XSum (combined)
  GPU:     RTX 2050 4GB (fp16 enabled)
  Output:  summarizer_model/final/

  Run: py -3.11 scripts/1_train_summarizer.py
============================================================
"""

import os, json, time, random
from pathlib import Path

# ── Config ──────────────────────────────────────────────
MODEL_NAME    = "facebook/bart-base"        # smaller than bart-large → fits 4GB VRAM
MAX_INPUT     = 512                          # max tokens for input dialogue
MAX_TARGET    = 128                          # max tokens for summary output
BATCH_SIZE    = 4                            # fits RTX 2050 4GB with fp16
GRAD_ACCUM    = 4                            # effective batch = 4×4 = 16
EPOCHS        = 3                            # 3 epochs is enough for fine-tuning
LR            = 3e-5                         # learning rate
WARMUP_STEPS  = 200
MAX_TRAIN     = 8000                         # cap training samples (speed vs quality)
MAX_VAL       = 500                          # cap validation samples

ROOT          = Path(__file__).parent.parent
PROCESSED     = ROOT / "summarizer_dataset" / "processed"
MODEL_OUT     = ROOT / "summarizer_model" / "final"
CHECKPOINT    = ROOT / "summarizer_model" / "checkpoints"

MODEL_OUT.mkdir(parents=True, exist_ok=True)
CHECKPOINT.mkdir(parents=True, exist_ok=True)

# ── Banner ──────────────────────────────────────────────
print("=" * 60)
print("  Note Lingo — BART Summarization Fine-tuning")
print("=" * 60)

# ── Check dependencies ───────────────────────────────────
import subprocess, sys
for pkg in ["transformers", "datasets", "torch", "evaluate", "sentencepiece", "accelerate"]:
    try:
        __import__(pkg)
    except ImportError:
        print(f"  📥  Installing {pkg}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", pkg, "-q"])

import torch
from transformers import (
    BartTokenizer, BartForConditionalGeneration,
    Seq2SeqTrainer, Seq2SeqTrainingArguments,
    DataCollatorForSeq2Seq, EarlyStoppingCallback
)
from datasets import Dataset
import evaluate

# ── Device check ────────────────────────────────────────
device = "cuda" if torch.cuda.is_available() else "cpu"
use_fp16 = device == "cuda"

print(f"\n  🖥️   Device: {device.upper()}")
if device == "cuda":
    gpu_name = torch.cuda.get_device_name(0)
    vram_gb  = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"  🚀  GPU: {gpu_name}")
    print(f"  💾  VRAM: {vram_gb:.1f} GB")
    print(f"  ⚡  fp16 enabled — faster + less VRAM")
else:
    print("  ⏱️   CPU mode — training will take several hours")
    print("       Consider Google Colab for free GPU:")
    print("       https://colab.research.google.com")

# ── Load data ───────────────────────────────────────────
print("\n  📂  Loading dataset...")

def load_json(path, max_samples=None):
    if not Path(path).exists():
        print(f"  ❌  File not found: {path}")
        print(f"       Run 0_setup_kaggle.py first!")
        sys.exit(1)
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if max_samples:
        data = data[:max_samples]
    return data

train_data = load_json(PROCESSED / "train.json", MAX_TRAIN)
val_data   = load_json(PROCESSED / "val.json",   MAX_VAL)

print(f"  ✅  Train: {len(train_data)} samples")
print(f"  ✅  Val:   {len(val_data)} samples")

# ── Load tokenizer ──────────────────────────────────────
print(f"\n  📥  Loading tokenizer: {MODEL_NAME}")
print(f"       (First run downloads ~560MB — cached after)")

tokenizer = BartTokenizer.from_pretrained(MODEL_NAME)

# ── Tokenize ─────────────────────────────────────────────
print("  ⚙️   Tokenizing...")

def tokenize(examples):
    inputs = tokenizer(
        examples["dialogue"],
        max_length=MAX_INPUT,
        truncation=True,
        padding=False,
    )
    targets = tokenizer(
        text_target=examples["summary"],
        max_length=MAX_TARGET,
        truncation=True,
        padding=False,
    )
    inputs["labels"] = targets["input_ids"]
    return inputs

def to_hf_dataset(data):
    dialogues = [d["dialogue"] for d in data]
    summaries = [d["summary"] for d in data]
    return Dataset.from_dict({"dialogue": dialogues, "summary": summaries})

train_ds = to_hf_dataset(train_data).map(
    tokenize, batched=True, remove_columns=["dialogue", "summary"],
    desc="Tokenizing train"
)
val_ds = to_hf_dataset(val_data).map(
    tokenize, batched=True, remove_columns=["dialogue", "summary"],
    desc="Tokenizing val"
)

print(f"  ✅  Tokenized: {len(train_ds)} train, {len(val_ds)} val")

# ── Load model ──────────────────────────────────────────
print(f"\n  📥  Loading model: {MODEL_NAME}")
model = BartForConditionalGeneration.from_pretrained(MODEL_NAME)
model = model.to(device)

total_params     = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"  📐  Parameters: {trainable_params:,} trainable / {total_params:,} total")

# ── Data collator ───────────────────────────────────────
data_collator = DataCollatorForSeq2Seq(
    tokenizer, model=model, padding=True, pad_to_multiple_of=8
)

# ── ROUGE metric ─────────────────────────────────────────
rouge = evaluate.load("rouge")

def compute_metrics(eval_pred):
    import numpy as np
    preds, labels = eval_pred

    # preds can be a tuple when using generate — take first element
    if isinstance(preds, tuple):
        preds = preds[0]

    # Clip negative values and replace -100 padding tokens
    preds  = np.clip(preds,  0, tokenizer.vocab_size - 1)
    labels = np.where(labels != -100, labels, tokenizer.pad_token_id)
    labels = np.clip(labels, 0, tokenizer.vocab_size - 1)

    decoded_preds  = tokenizer.batch_decode(preds,  skip_special_tokens=True)
    decoded_labels = tokenizer.batch_decode(labels, skip_special_tokens=True)

    decoded_preds  = [p.strip() for p in decoded_preds]
    decoded_labels = [l.strip() for l in decoded_labels]

    # Filter out empty predictions
    pairs = [(p, l) for p, l in zip(decoded_preds, decoded_labels) if p and l]
    if not pairs:
        return {"rouge1": 0.0, "rouge2": 0.0, "rougeL": 0.0}
    decoded_preds, decoded_labels = zip(*pairs)

    result = rouge.compute(
        predictions=list(decoded_preds),
        references=list(decoded_labels),
        use_stemmer=True
    )
    return {k: round(v * 100, 2) for k, v in result.items()}

# ── Training arguments ──────────────────────────────────
training_args = Seq2SeqTrainingArguments(
    output_dir=str(CHECKPOINT),
    num_train_epochs=EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    per_device_eval_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=GRAD_ACCUM,
    learning_rate=LR,
    warmup_steps=WARMUP_STEPS,
    fp16=use_fp16,
    predict_with_generate=True,
    generation_max_length=MAX_TARGET,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="rouge2",
    greater_is_better=True,
    logging_steps=50,
    save_total_limit=2,
    report_to="none",
    dataloader_num_workers=0,       # avoid multiprocessing issues on Windows
)

# ── Trainer ──────────────────────────────────────────────
trainer = Seq2SeqTrainer(
    model=model,
    args=training_args,
    train_dataset=train_ds,
    eval_dataset=val_ds,
    processing_class=tokenizer,
    data_collator=data_collator,
    compute_metrics=compute_metrics,
    callbacks=[EarlyStoppingCallback(early_stopping_patience=2)],
)

# ── Time estimate ────────────────────────────────────────
steps_per_epoch = len(train_ds) // (BATCH_SIZE * GRAD_ACCUM)
total_steps     = steps_per_epoch * EPOCHS
secs_per_step   = 1.2 if device == "cuda" else 8.0
est_mins        = (total_steps * secs_per_step) / 60

print(f"\n  📊  Training plan:")
print(f"      Steps/epoch: {steps_per_epoch}")
print(f"      Total steps: {total_steps}")
print(f"      Est. time:   {est_mins:.0f} – {est_mins*1.4:.0f} minutes on {device.upper()}")
print(f"\n  🚀  Starting training...")
print("-" * 60)

start = time.time()
trainer.train()
elapsed = time.time() - start

print("-" * 60)
print(f"\n  ⏱️   Training done in {elapsed/60:.1f} minutes")

# ── Save final model ─────────────────────────────────────
print(f"\n  💾  Saving model to {MODEL_OUT}...")
trainer.save_model(str(MODEL_OUT))
tokenizer.save_pretrained(str(MODEL_OUT))

# Save config metadata
meta = {
    "model_name":   MODEL_NAME,
    "max_input":    MAX_INPUT,
    "max_target":   MAX_TARGET,
    "train_samples": len(train_ds),
    "val_samples":   len(val_ds),
    "epochs":        EPOCHS,
    "training_time_minutes": round(elapsed / 60, 1),
    "device":        device,
}
with open(MODEL_OUT / "training_meta.json", "w") as f:
    json.dump(meta, f, indent=2)

print(f"  ✅  Model saved!")

# ── Final evaluation ─────────────────────────────────────
print("\n  📈  Running final evaluation...")
results = trainer.evaluate()
print(f"\n  ROUGE-1:  {results.get('eval_rouge1', 0):.2f}%")
print(f"  ROUGE-2:  {results.get('eval_rouge2', 0):.2f}%")
print(f"  ROUGE-L:  {results.get('eval_rougeL', 0):.2f}%")

print("\n" + "=" * 60)
print("  ✅  DONE! Next step:")
print("      py -3.11 scripts/2_test_summarizer.py")
print("=" * 60)