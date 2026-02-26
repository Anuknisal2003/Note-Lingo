#!/usr/bin/env python3
"""
STEP 1 — Record Your Own Voice Dataset
=======================================
Run this script to record voice samples for training.
Each sample = 1 recording + 1 transcript line.

Usage:
    python scripts/1_record_dataset.py

Controls:
    ENTER  → start recording
    ENTER  → stop recording
    s      → skip this sentence
    q      → quit and save
"""

import os
import csv
import wave
import time
import threading
import numpy as np

# ── Try importing audio libraries ────────────────────────────────
try:
    import sounddevice as sd
    import scipy.io.wavfile as wavfile
    HAS_AUDIO = True
except ImportError:
    HAS_AUDIO = False
    print("⚠️  sounddevice not installed.")
    print("   Run: pip install sounddevice scipy")
    print("   Falling back to MANUAL mode (add your own .wav files)\n")

# ── Sentence list to record ───────────────────────────────────────
# These are starter sentences — add your own domain-specific ones!
SENTENCES = [
    # General lecture phrases
    "The lecture today covers the introduction to machine learning",
    "Neural networks are inspired by the human brain",
    "Deep learning uses multiple layers to learn representations",
    "The training loss decreased significantly after ten epochs",
    "Gradient descent is used to minimize the loss function",
    "Overfitting occurs when the model memorizes training data",
    "We use dropout layers to prevent overfitting",
    "The validation accuracy is eighty five percent",
    "Convolutional neural networks are used for image classification",
    "Recurrent neural networks handle sequential data",

    # Meeting phrases
    "Let us schedule a follow up meeting for next week",
    "The project deadline is the end of this month",
    "We need to review the requirements document",
    "Please send me the updated report by Friday",
    "The budget for this quarter has been approved",
    "Action item assigned to the development team",
    "We will present the results to the stakeholders",
    "The sprint review is scheduled for Thursday afternoon",
    "Can everyone confirm their availability for the demo",
    "The client approved the new design mockups",

    # Study notes
    "The photosynthesis process converts sunlight to energy",
    "Water molecules consist of two hydrogen and one oxygen atom",
    "The speed of light is approximately three hundred thousand kilometers per second",
    "Newton's first law states that objects in motion stay in motion",
    "The capital of Sri Lanka is Sri Jayawardenepura Kotte",
    "Binary search runs in logarithmic time complexity",
    "A linked list stores elements in sequential memory nodes",
    "The database uses a relational model with foreign keys",
    "Version control allows teams to collaborate on code",
    "Application programming interfaces connect different services",

    # Note Lingo specific
    "Today's meeting covered three main topics",
    "The first point discussed was the budget allocation",
    "Key action items from this session are as follows",
    "This note was recorded on the fourteenth of February",
    "Please summarize the important points from this lecture",
    "The professor mentioned that the exam will cover chapters one through five",
    "Important keywords from today include algorithm data structure and complexity",
    "The interview went well and they will follow up next week",
    "Personal reminder to review the notes before the exam",
    "This recording covers the second half of the lecture",

    # Sinhala-English mixed (common in Sri Lanka)
    "The assignment submission date has been extended",
    "We discussed the project proposal this morning",
    "The research paper needs two more references",
    "Laboratory practical is scheduled for Wednesday",
    "The group presentation is worth thirty percent of the grade",
]

# ── Config ────────────────────────────────────────────────────────
SAMPLE_RATE  = 16000   # 16kHz — required by Wav2Vec2
CHANNELS     = 1       # Mono
DATASET_DIR  = "dataset"
AUDIO_DIR    = os.path.join(DATASET_DIR, "audio")
METADATA_CSV = os.path.join(DATASET_DIR, "metadata.csv")

os.makedirs(AUDIO_DIR, exist_ok=True)

# ── Load existing metadata ─────────────────────────────────────────
existing = set()
if os.path.exists(METADATA_CSV):
    with open(METADATA_CSV, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            existing.add(row["file"])

# ── Recording state ────────────────────────────────────────────────
recording     = False
audio_buffer  = []
record_thread = None

def _record_worker():
    """Runs in background thread, captures mic audio."""
    global audio_buffer
    audio_buffer = []
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                        dtype='float32') as stream:
        while recording:
            data, _ = stream.read(SAMPLE_RATE // 10)  # 100ms chunks
            audio_buffer.extend(data[:, 0].tolist())

def start_recording():
    global recording, record_thread
    recording     = True
    record_thread = threading.Thread(target=_record_worker, daemon=True)
    record_thread.start()

def stop_recording():
    global recording
    recording = False
    if record_thread:
        record_thread.join(timeout=2)
    return np.array(audio_buffer, dtype=np.float32)

def save_wav(audio: np.ndarray, filepath: str):
    """Save float32 audio as 16-bit WAV."""
    audio_int16 = (audio * 32767).astype(np.int16)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio_int16.tobytes())

# ── Main recording loop ───────────────────────────────────────────
def record_dataset():
    # Count already recorded
    recorded_count = len(existing)
    print("=" * 60)
    print("🎙️  Note Lingo — Dataset Recorder")
    print("=" * 60)
    print(f"  Already recorded: {recorded_count} samples")
    print(f"  Sentences queued: {len(SENTENCES)}")
    print(f"  Target: 50+ samples for training\n")
    print("  Controls:")
    print("    ENTER → start recording")
    print("    ENTER → stop recording")
    print("    s     → skip sentence")
    print("    q     → quit and save\n")

    with open(METADATA_CSV, "a", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        if recorded_count == 0:
            writer.writerow(["file", "transcript", "duration"])  # header

        sample_idx = recorded_count

        for i, sentence in enumerate(SENTENCES):
            filename = f"sample_{sample_idx:04d}.wav"

            # Skip already recorded
            if filename in existing:
                continue

            print(f"\n{'─' * 50}")
            print(f"  [{sample_idx + 1}/{len(SENTENCES)}] Say this sentence:")
            print(f"\n  📢  \"{sentence}\"\n")

            cmd = input("  Press ENTER to record, 's' to skip, 'q' to quit: ").strip().lower()

            if cmd == "q":
                print("\n✅  Saved and quit.")
                break
            if cmd == "s":
                print("  ⏩  Skipped.")
                continue

            if not HAS_AUDIO:
                # Manual mode — user provides their own .wav file
                print(f"  📁  Manual mode: place your WAV file as:")
                print(f"      dataset/audio/{filename}")
                print(f"      Transcript: {sentence}")
                filepath = os.path.join(AUDIO_DIR, filename)
                if os.path.exists(filepath):
                    writer.writerow([filename, sentence.lower(), "unknown"])
                    csvfile.flush()
                    sample_idx += 1
                    print("  ✅  Added to dataset.")
                continue

            # ── Real recording ────────────────────────────────────
            print("  🔴  Recording... (press ENTER to stop)")
            start_recording()
            start_time = time.time()
            input()
            audio = stop_recording()
            duration = time.time() - start_time

            if len(audio) < SAMPLE_RATE * 0.5:  # < 0.5 seconds
                print("  ⚠️   Too short! Try again.")
                continue

            # Save
            filepath = os.path.join(AUDIO_DIR, filename)
            save_wav(audio, filepath)
            writer.writerow([filename, sentence.lower(), f"{duration:.2f}"])
            csvfile.flush()
            sample_idx += 1

            print(f"  ✅  Saved: {filename} ({duration:.1f}s, {len(audio)} samples)")

    print(f"\n{'=' * 60}")
    print(f"🎉  Dataset recording complete!")
    print(f"    Total samples: {sample_idx}")
    print(f"    Location: {METADATA_CSV}")
    print(f"\n    Next step: python scripts/2_prepare_dataset.py")

if __name__ == "__main__":
    record_dataset()