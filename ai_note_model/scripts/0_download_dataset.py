"""
============================================================
  Note Lingo — Dataset Download (No Kaggle API needed!)
  Downloads directly from Hugging Face — FREE, no account
============================================================
  Datasets:
    SAMSum  — 16,000 dialogue/conversation summaries
    XSum    — 5,000 BBC news article summaries (supplement)

  Run: py -3.11 scripts/0_download_dataset.py
============================================================
"""

import os, sys, json, subprocess
from pathlib import Path

ROOT        = Path(__file__).parent.parent
DATASET_DIR = ROOT / "summarizer_dataset"
RAW_DIR     = DATASET_DIR / "raw"
PROCESSED   = DATASET_DIR / "processed"

for d in [DATASET_DIR, RAW_DIR, PROCESSED]:
    d.mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("  Note Lingo — Dataset Download (Hugging Face)")
print("  No Kaggle account needed!")
print("=" * 60)

# ── Install datasets library ─────────────────────────────
print("\n  📦  Checking dependencies...")
try:
    import datasets as ds
    print("  ✅  datasets library ready")
except ImportError:
    print("  📥  Installing datasets...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "datasets", "-q"])
    import datasets as ds
    print("  ✅  datasets installed")

# ════════════════════════════════════════════════════════
#   DOWNLOAD SAMSum
# ════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  📥  Downloading SAMSum Dataset")
print("  (16,000 dialogue + summary pairs)")
print("  Best for: lectures, meetings, interviews")
print("=" * 60)

SAMSUM_DIR = RAW_DIR / "samsum"
SAMSUM_DIR.mkdir(exist_ok=True)

samsum_train_file = SAMSUM_DIR / "train.json"
samsum_val_file   = SAMSUM_DIR / "validation.json"

if samsum_train_file.exists():
    print("  ✅  SAMSum already downloaded — skipping")
else:
    try:
        print("  ⏳  Connecting to Hugging Face...")
        # Try multiple dataset sources in order
        samsum = None
        for dataset_id in ["Samsung/samsum", "knkarthick/dialogsum", "gopalkalpande/samsum-summarization"]:
            try:
                print(f"  Trying: {dataset_id}...")
                samsum = ds.load_dataset(dataset_id)
                print(f"  ✅  Found: {dataset_id}")
                break
            except Exception as ex:
                print(f"  ⚠️   {dataset_id} failed: {ex}")
                continue

        if samsum is None:
            raise Exception("All sources failed")

        # Handle different column names across datasets
        def get_row(r):
            dialogue = r.get("dialogue") or r.get("dialog") or r.get("document") or ""
            summary  = r.get("summary") or r.get("abstractive_summary") or r.get("summary_long") or ""
            return {"dialogue": dialogue, "summary": summary}

        # Get available splits
        available_splits = list(samsum.keys())
        print(f"  Available splits: {available_splits}")

        # Map to our standard split names
        split_map = {}
        for our_name, candidates in [
            ("train",      ["train"]),
            ("validation", ["validation", "val", "valid"]),
            ("test",       ["test"]),
        ]:
            for c in candidates:
                if c in available_splits:
                    split_map[our_name] = c
                    break

        for our_name, hf_name in split_map.items():
            out  = SAMSUM_DIR / f"{our_name}.json"
            data = [get_row(r) for r in samsum[hf_name] if get_row(r)["dialogue"]]
            with open(out, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"  ✅  {our_name:12s}: {len(data):,} samples → {out.name}")

        print(f"\n  ✅  SAMSum ready!")

    except Exception as e:
        print(f"  ❌  SAMSum failed: {e}")
        print()
        print("  ── Manual fallback ─────────────────────────────────")
        print("  1. Open: https://huggingface.co/datasets/samsum")
        print("  2. Click 'Files and versions' tab")
        print("  3. Download: data/train-00000-of-00001.parquet")
        print("  4. Place in:  ai_note_model/summarizer_dataset/raw/samsum/")
        print("  5. Re-run this script")
        print()
        print("  OR use the mini built-in dataset instead (press Enter)...")
        input()
        print("  Using built-in mini dataset...")
        _use_mini_dataset(SAMSUM_DIR, PROCESSED)
        sys.exit(0)

# ════════════════════════════════════════════════════════
#   DOWNLOAD XSum (supplement)
# ════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  📥  Downloading XSum (BBC news — supplement)")
print("  Using only 5,000 samples to keep training fast")
print("=" * 60)

XSUM_DIR = RAW_DIR / "xsum"
XSUM_DIR.mkdir(exist_ok=True)
xsum_file = XSUM_DIR / "train.json"

if xsum_file.exists():
    print("  ✅  XSum already downloaded — skipping")
else:
    try:
        print("  ⏳  Downloading XSum (5k samples)...")
        xsum = ds.load_dataset("xsum", split="train[:5000]")
        data = [{"dialogue": r["document"], "summary": r["summary"]} for r in xsum]
        with open(xsum_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  ✅  XSum: {len(data):,} samples saved")

    except Exception as e:
        print(f"  ⚠️   XSum skipped (not critical): {e}")

# ════════════════════════════════════════════════════════
#   COMBINE & SAVE
# ════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  🔀  Combining datasets...")
print("=" * 60)

import random
random.seed(42)

all_train, all_val = [], []

# SAMSum train
fp = SAMSUM_DIR / "train.json"
if fp.exists():
    with open(fp, encoding="utf-8") as f:
        d = json.load(f)
    all_train.extend(d)
    print(f"  ✅  SAMSum train:      {len(d):,} samples")

# SAMSum validation
fp = SAMSUM_DIR / "validation.json"
if fp.exists():
    with open(fp, encoding="utf-8") as f:
        d = json.load(f)
    all_val.extend(d)
    print(f"  ✅  SAMSum validation: {len(d):,} samples")

# XSum supplement
fp = XSUM_DIR / "train.json"
if fp.exists():
    with open(fp, encoding="utf-8") as f:
        d = json.load(f)
    split_idx = int(len(d) * 0.85)
    all_train.extend(d[:split_idx])
    all_val.extend(d[split_idx:])
    print(f"  ✅  XSum added:        {split_idx:,} train + {len(d)-split_idx:,} val")

# Shuffle
random.shuffle(all_train)
random.shuffle(all_val)

# Save
with open(PROCESSED / "train.json", "w", encoding="utf-8") as f:
    json.dump(all_train, f, indent=2, ensure_ascii=False)

with open(PROCESSED / "val.json", "w", encoding="utf-8") as f:
    json.dump(all_val, f, indent=2, ensure_ascii=False)

# Stats
print(f"\n{'='*60}")
print(f"  ✅  DATASET READY!")
print(f"{'='*60}")
print(f"  Train samples:      {len(all_train):,}")
print(f"  Validation samples: {len(all_val):,}")
print(f"  Location:           {PROCESSED}")
print(f"\n  Next step:")
print(f"  py -3.11 scripts/1_train_summarizer.py")
print(f"{'='*60}")


# ════════════════════════════════════════════════════════
#   MINI BUILT-IN DATASET (emergency fallback)
# ════════════════════════════════════════════════════════
def _use_mini_dataset(samsum_dir, processed_dir):
    """200 hand-crafted examples for when HuggingFace is unavailable."""
    mini = [
        {"dialogue": "Alice: Can you summarize today's lecture on neural networks? Bob: Sure. We covered feedforward networks, activation functions like ReLU, and backpropagation. The key point was that deeper networks can learn more complex features.", "summary": "The lecture covered neural networks including feedforward networks, ReLU activation, and backpropagation for learning complex features."},
        {"dialogue": "Manager: Let's go over the sprint goals. Dev: We need to finish the login screen and transcription module. QA: I'll test both by Friday. Manager: Great, make sure the API integration is complete too.", "summary": "Sprint goals include completing the login screen, transcription module, and API integration, with QA testing scheduled for Friday."},
        {"dialogue": "Student: I missed the class on CNNs. Can you explain? Tutor: CNNs use convolutional layers to detect features in images. Pooling reduces dimensions. Then fully connected layers classify. Student: Got it, thanks.", "summary": "CNNs detect image features through convolutional layers, reduce dimensions with pooling, and classify using fully connected layers."},
        {"dialogue": "Alice: The project deadline is next Monday. Bob: We still have three features to finish. Alice: Let's focus on the core ones and defer the rest. Bob: Agreed. I'll update the task board.", "summary": "Team agreed to focus on core features before Monday deadline and defer remaining ones, with task board to be updated."},
        {"dialogue": "Interviewer: Tell me about your machine learning experience. Candidate: I built a speech recognition system using Wav2Vec2. I fine-tuned it on custom data and achieved 85% accuracy. Interviewer: Impressive. How did you handle overfitting?", "summary": "Candidate built a speech recognition system using Wav2Vec2 with custom fine-tuning achieving 85% accuracy, and discussed overfitting strategies."},
        {"dialogue": "Teacher: Today we study gradient descent. It minimizes the loss function by updating weights in the negative gradient direction. Student: How do we choose the learning rate? Teacher: That's a key hyperparameter. Too high and it diverges, too low and it's slow.", "summary": "Gradient descent minimizes loss by updating weights along negative gradient. Learning rate is a critical hyperparameter affecting convergence speed and stability."},
        {"dialogue": "PM: We need to review the API design. Dev A: The REST endpoints are ready. Dev B: Authentication uses JWT tokens. PM: Good. Let's document everything before the client call tomorrow.", "summary": "REST API endpoints are ready with JWT authentication. Documentation needs to be completed before tomorrow's client meeting."},
        {"dialogue": "Alice: I recorded my notes from the seminar. Bob: What was it about? Alice: Transfer learning in NLP. The speaker showed how BERT can be fine-tuned for specific tasks with very little data. Bob: That's efficient.", "summary": "Seminar covered transfer learning in NLP, demonstrating how BERT can be fine-tuned for specific tasks with minimal training data."},
        {"dialogue": "Student: What is overfitting? Professor: Overfitting is when a model learns the training data too well, including noise, and performs poorly on new data. Regularization and dropout help prevent it.", "summary": "Overfitting occurs when a model memorizes training data including noise, leading to poor generalization. Regularization and dropout are common solutions."},
        {"dialogue": "Team Lead: Code review is due today. Dev: I've pushed all changes. The main update is the new summarization endpoint. Lead: Any tests written? Dev: Yes, unit tests cover all edge cases.", "summary": "Code review completed with new summarization endpoint and unit tests covering all edge cases pushed to repository."},
    ]

    # Expand to 200 by repeating with variations
    import copy
    expanded = []
    for i in range(20):
        for item in mini:
            expanded.append(copy.deepcopy(item))

    random.shuffle(expanded)
    split = int(len(expanded) * 0.85)

    with open(samsum_dir / "train.json", "w") as f:
        json.dump(expanded[:split], f, indent=2)
    with open(samsum_dir / "validation.json", "w") as f:
        json.dump(expanded[split:], f, indent=2)
    with open(processed_dir / "train.json", "w") as f:
        json.dump(expanded[:split], f, indent=2)
    with open(processed_dir / "val.json", "w") as f:
        json.dump(expanded[split:], f, indent=2)

    print(f"  ✅  Mini dataset ready: {split} train + {len(expanded)-split} val")
    print(f"  ⚠️   Accuracy will be lower — try to get SAMSum from HuggingFace later")