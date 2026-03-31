"""
============================================================
  Note Lingo — Step 2: Test Your Trained Summarizer
============================================================
  Tests your fine-tuned BART model with structured output
  matching exactly what the Flutter app expects.

  Run: py -3.11 scripts/2_test_summarizer.py
============================================================
"""

import json, re, sys
from pathlib import Path

ROOT      = Path(__file__).parent.parent
MODEL_DIR = ROOT / "summarizer_model" / "final"

# ── Check model exists ───────────────────────────────────
if not MODEL_DIR.exists():
    print("❌  Model not found. Run 1_train_summarizer.py first!")
    sys.exit(1)

print("=" * 60)
print("  Note Lingo — Summarizer Test")
print("=" * 60)

import torch
from transformers import BartTokenizer, BartForConditionalGeneration

device    = "cuda" if torch.cuda.is_available() else "cpu"
print(f"\n  🖥️   Device: {device.upper()}")
print(f"  📥  Loading model from {MODEL_DIR}...")

tokenizer = BartTokenizer.from_pretrained(str(MODEL_DIR))
model     = BartForConditionalGeneration.from_pretrained(str(MODEL_DIR)).to(device)
model.eval()
print("  ✅  Model loaded")

# ── Structured summary builder ───────────────────────────
def extract_keywords(text: str, top_n: int = 8) -> list:
    """Extract important keywords from text."""
    stopwords = {
        "the","a","an","is","are","was","were","be","been","being",
        "have","has","had","do","does","did","will","would","could",
        "should","may","might","shall","can","need","dare","ought",
        "to","of","in","on","at","by","for","with","about","against",
        "between","into","through","during","before","after","above",
        "below","from","up","down","out","off","over","under","again",
        "further","then","once","and","but","or","nor","so","yet",
        "both","either","neither","not","only","own","same","than",
        "too","very","just","because","as","until","while","i","you",
        "he","she","it","we","they","this","that","these","those",
        "what","which","who","when","where","how","all","each","every",
    }
    words  = re.findall(r'\b[a-zA-Z]{4,}\b', text.lower())
    scored = {}
    for w in words:
        if w not in stopwords:
            scored[w] = scored.get(w, 0) + 1
    sorted_kw = sorted(scored.items(), key=lambda x: -x[1])
    return [k for k, _ in sorted_kw[:top_n]]


def summarize(text: str, max_new_tokens: int = 130) -> str:
    """Run BART inference and return raw summary."""
    inputs = tokenizer(
        text,
        return_tensors="pt",
        max_length=512,
        truncation=True,
    ).to(device)
    with torch.no_grad():
        ids = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            min_length=30,
            num_beams=4,
            length_penalty=1.2,
            no_repeat_ngram_size=3,
            early_stopping=True,
        )
    return tokenizer.decode(ids[0], skip_special_tokens=True).strip()


def build_structured_summary(text: str, category: str = "lecture") -> dict:
    """
    Build a structured summary dict matching what Flutter app expects.
    Categories: lecture | meeting | interview | personal | general
    """
    # Get BART summary
    raw_summary = summarize(text)

    # Split into sentences
    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', raw_summary) if len(s.strip()) > 10]

    # Overview = first sentence
    overview = sentences[0] if sentences else raw_summary

    # Key points = remaining sentences as bullet items
    key_points = sentences[1:] if len(sentences) > 1 else []
    # Also extract from original if summary is short
    if len(key_points) < 3:
        orig_sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', text) if len(s.strip()) > 20]
        key_points += orig_sentences[:max(0, 4 - len(key_points))]
    key_points = key_points[:5]   # max 5 bullet points

    # Keywords from original + summary
    keywords = extract_keywords(text + " " + raw_summary, top_n=8)

    # Conclusion = last sentence of raw_summary (if different from overview)
    conclusion = sentences[-1] if len(sentences) > 1 else raw_summary

    # Category-specific heading / emoji
    styles = {
        "lecture":   {"heading": "📚 Lecture Notes",    "points_label": "Key Concepts"},
        "meeting":   {"heading": "🗓️ Meeting Minutes",   "points_label": "Action Items"},
        "interview": {"heading": "🎙️ Interview Notes",   "points_label": "Key Responses"},
        "personal":  {"heading": "📝 Personal Note",     "points_label": "Key Points"},
        "general":   {"heading": "📄 Note Summary",      "points_label": "Key Points"},
    }
    style = styles.get(category.lower(), styles["general"])

    return {
        "category_heading": style["heading"],
        "overview":         overview,
        "key_points":       key_points,
        "points_label":     style["points_label"],
        "keywords":         keywords,
        "conclusion":       conclusion,
        "raw_summary":      raw_summary,
    }

# ── Test samples ─────────────────────────────────────────
test_samples = [
    {
        "category": "lecture",
        "text": """
        Today we will be covering convolutional neural networks.
        A CNN is a type of deep learning model primarily used for image classification.
        It uses convolutional layers to automatically learn spatial features from input images.
        The pooling layers reduce the spatial dimensions and help with translation invariance.
        Dropout layers are used to prevent overfitting during training.
        At the end of the network, fully connected layers map the learned features to output classes.
        The model is trained using backpropagation and the Adam optimizer.
        We saw that ResNet and VGG are famous CNN architectures used in practice.
        """
    },
    {
        "category": "meeting",
        "text": """
        Alright everyone, let's start the sprint review.
        The development team completed the login screen and the recording feature this week.
        The AI transcription module is still in progress — the team expects it by Thursday.
        John raised a concern about the API quota exceeding the budget.
        We agreed to switch to the local model to avoid API costs.
        Action item for Sarah: update the Firestore security rules before Friday.
        Action item for Mike: fix the export bug on Android devices.
        Next sprint will focus on the export feature and UI polish.
        The product demo is scheduled for next Monday at 2 PM.
        """
    },
    {
        "category": "interview",
        "text": """
        Can you tell me about your experience with machine learning?
        Yes, I have been working with ML for about two years. I mainly focus on NLP.
        What projects have you worked on?
        I built a speech-to-text pipeline using Wav2Vec2 and integrated it into a Flutter app.
        How did you handle the limited dataset problem?
        I used data augmentation and combined multiple open datasets to improve coverage.
        What was the biggest challenge?
        The biggest challenge was getting the model to work on low resource mobile devices.
        How did you solve it?
        We used model quantization and ran inference through a Flask API on the user's PC.
        """
    }
]

# ── Run tests ─────────────────────────────────────────────
print("\n" + "=" * 60)
print("  🧪  Testing structured summaries")
print("=" * 60)

for i, sample in enumerate(test_samples, 1):
    print(f"\n  ── Test {i}: {sample['category'].upper()} ─────────────────")
    result = build_structured_summary(sample["text"].strip(), sample["category"])

    print(f"\n  {result['category_heading']}")
    print(f"\n  📖 Overview")
    print(f"     {result['overview']}")
    print(f"\n  🔑 {result['points_label']}")
    for pt in result["key_points"]:
        print(f"     • {pt}")
    print(f"\n  🏷️  Keywords")
    print(f"     {', '.join(result['keywords'])}")
    print(f"\n  💡 Conclusion")
    print(f"     {result['conclusion']}")

print("\n" + "=" * 60)
print("  ✅  Tests complete! Ready for Flask integration.")
print("      py -3.11 flask_api/app.py")
print("=" * 60)