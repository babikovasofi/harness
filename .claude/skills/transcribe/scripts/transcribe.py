#!/usr/bin/env python3
"""
Local transcription with speaker diarization.

macOS (Apple Silicon): mlx-whisper for STT + FluidAudio (CoreML) for diarization.
Other platforms: falls back to whisply (faster-whisper + pyannote).

Usage:
    # Step 1: Transcribe (Speaker 0, Speaker 1, ...)
    python scripts/transcribe.py meeting.mp4

    # Step 2: After reviewing, re-label speakers
    python scripts/transcribe.py meeting.mp4 --relabel '{"Speaker 0": "Alex", "Speaker 1": "Maria"}'

Output: Markdown transcript with speaker labels and timestamps.
Cached <input>.transcribe.json is reused on re-runs (no duplicate compute).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from dotenv import load_dotenv


MAC = sys.platform == "darwin"
DEFAULT_FA_BIN = Path.home() / ".local/share/transcribe-skill/FluidAudio/.build/release/fluidaudiocli"
DEFAULT_WHISPER_REPO = "mlx-community/whisper-large-v3-turbo"


def _audio_duration(path: Path) -> float:
    try:
        res = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
            check=False, capture_output=True, text=True,
        )
        return float(res.stdout.strip()) if res.stdout.strip() else 0.0
    except Exception:
        return 0.0


def _preconvert_audio(input_path: Path, work_dir: Path) -> Path:
    out = work_dir / (input_path.stem + ".wav")
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(input_path),
        "-ac", "1", "-ar", "16000",
        "-vn",
        str(out),
    ]
    res = subprocess.run(cmd, check=False)
    if res.returncode != 0 or not out.exists():
        print("Warning: ffmpeg preconvert failed, passing original file", file=sys.stderr)
        return input_path
    return out


# ----- Mac backend: mlx-whisper + FluidAudio --------------------------------

def _run_mlx_whisper(wav: Path, language: str | None, model_repo: str) -> dict:
    import mlx_whisper

    print(f"Running mlx-whisper (model={model_repo}, lang={language or 'auto'})...",
          file=sys.stderr)
    kwargs = {
        "path_or_hf_repo": model_repo,
        "word_timestamps": True,
        "verbose": False,
    }
    if language:
        kwargs["language"] = language
    result = mlx_whisper.transcribe(str(wav), **kwargs)
    return _clean_whisper_json(result)


def _clean_whisper_json(r: dict) -> dict:
    import numpy as np

    def conv(o):
        if isinstance(o, dict):
            return {k: conv(v) for k, v in o.items()}
        if isinstance(o, list):
            return [conv(v) for v in o]
        if isinstance(o, (np.floating,)):
            return float(o)
        if isinstance(o, (np.integer,)):
            return int(o)
        return o

    return conv(r)


def _resolve_fa_bin() -> Path:
    explicit = os.getenv("FLUIDAUDIO_BIN")
    if explicit:
        p = Path(explicit)
        if p.exists():
            return p
    if DEFAULT_FA_BIN.exists():
        return DEFAULT_FA_BIN
    found = shutil.which("fluidaudiocli")
    if found:
        return Path(found)
    print(
        f"Error: fluidaudiocli not found. Build it via run.sh or set FLUIDAUDIO_BIN. "
        f"Expected at {DEFAULT_FA_BIN}.",
        file=sys.stderr,
    )
    sys.exit(1)


def _run_fluidaudio(wav: Path, num_speakers: int | None) -> dict:
    fa = _resolve_fa_bin()
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out_path = Path(tf.name)
    try:
        cmd = [
            str(fa), "process", str(wav),
            "--mode", "offline",
            "--output", str(out_path),
        ]
        if num_speakers:
            cmd.extend(["--num-speakers", str(num_speakers)])
        print(f"Running FluidAudio diarization (num_speakers={num_speakers or 'auto'})...",
              file=sys.stderr)
        res = subprocess.run(cmd, check=False)
        if res.returncode != 0 or not out_path.exists():
            print(f"Error: fluidaudiocli exited with code {res.returncode}", file=sys.stderr)
            sys.exit(res.returncode or 1)
        with open(out_path, "r", encoding="utf-8") as f:
            raw = json.load(f)
        for s in raw.get("segments", []):
            s.pop("embedding", None)
        return raw
    finally:
        out_path.unlink(missing_ok=True)


def transcribe_mac(
    input_path: Path,
    language: str | None,
    num_speakers: int | None,
    model_repo: str,
) -> dict:
    with tempfile.TemporaryDirectory(prefix="preconv_", dir=Path.cwd()) as conv_dir:
        wav = _preconvert_audio(input_path, Path(conv_dir))
        stt = _run_mlx_whisper(wav, language, model_repo)
        diar = _run_fluidaudio(wav, num_speakers)
    return {"backend": "mac", "stt": stt, "diar": diar}


# ----- Fallback backend: whisply (faster-whisper + pyannote) ----------------

def _require_hf_token() -> str:
    if os.getenv("HF_TOKEN"):
        return os.environ["HF_TOKEN"]
    load_dotenv()
    if os.getenv("HF_TOKEN"):
        return os.environ["HF_TOKEN"]
    global_env = Path.home() / ".config/transcribe-skill/.env"
    if global_env.exists():
        load_dotenv(global_env)
    if os.getenv("HF_TOKEN"):
        return os.environ["HF_TOKEN"]
    print(
        "Error: HF_TOKEN not set (required for pyannote diarization on fallback path).\n"
        "  - env var: export HF_TOKEN=hf_...\n"
        f"  - global file: {global_env}\n"
        "See references/local-setup.md.",
        file=sys.stderr,
    )
    sys.exit(1)


def transcribe_fallback(
    input_path: Path,
    language: str | None,
    num_speakers: int | None,
    model: str,
) -> dict:
    token = _require_hf_token()
    with tempfile.TemporaryDirectory(prefix="whisply_", dir=Path.cwd()) as tmp:
        tmp_dir = Path(tmp)
        cmd = [
            "whisply", "run",
            "--files", str(input_path),
            "--output_dir", str(tmp_dir),
            "--device", "auto",
            "--model", model,
            "--annotate",
            "--hf_token", token,
            "--export", "json",
        ]
        if language:
            cmd.extend(["--language", language])
        if num_speakers:
            cmd.extend(["--num_speakers", str(num_speakers)])
        print(f"Running whisply fallback (model={model}, lang={language or 'auto'})...",
              file=sys.stderr)
        res = subprocess.run(cmd, check=False)
        if res.returncode != 0:
            print(f"Error: whisply exited with code {res.returncode}", file=sys.stderr)
            sys.exit(res.returncode)
        json_files = list(tmp_dir.rglob("*.json"))
        if not json_files:
            print("Error: whisply produced no JSON output", file=sys.stderr)
            sys.exit(1)
        with open(max(json_files, key=lambda p: p.stat().st_size), "r", encoding="utf-8") as f:
            return {"backend": "whisply", "whisply": json.load(f)}


# ----- Alignment + formatting ----------------------------------------------

def _format_timestamp(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


def _pick_speaker(start: float, end: float, diar_segs: list) -> str | None:
    overlaps: dict = {}
    for ds, de, sp in diar_segs:
        ov = max(0.0, min(end, de) - max(start, ds))
        if ov > 0:
            overlaps[sp] = overlaps.get(sp, 0.0) + ov
    if overlaps:
        return max(overlaps.items(), key=lambda kv: kv[1])[0]
    nearest = None
    best_gap = float("inf")
    mid = (start + end) / 2
    for ds, de, sp in diar_segs:
        if mid < ds:
            gap = ds - mid
        elif mid > de:
            gap = mid - de
        else:
            gap = 0.0
        if gap < best_gap:
            best_gap = gap
            nearest = sp
    return nearest


def _align_mac(stt: dict, diar: dict) -> list[dict]:
    diar_segs = [
        (float(s["startTimeSeconds"]), float(s["endTimeSeconds"]), s["speakerId"])
        for s in diar.get("segments", [])
    ]
    out = []
    for seg in stt.get("segments", []):
        start = float(seg.get("start", 0) or 0)
        end = float(seg.get("end", start) or start)
        text = (seg.get("text") or "").strip()
        if not text:
            continue
        sp = _pick_speaker(start, end, diar_segs)
        out.append({"start": start, "end": end, "text": text, "speaker": sp})
    return out


def _extract_whisply(raw: dict) -> list[dict]:
    segments = []
    if "transcription" in raw and isinstance(raw["transcription"], dict):
        body = next(iter(raw["transcription"].values()), {})
        if isinstance(body, dict):
            segments = body.get("chunks") or body.get("segments") or []
    elif "segments" in raw:
        segments = raw["segments"]

    out = []
    for seg in segments:
        text = (seg.get("text") or seg.get("transcript") or "").strip()
        if "timestamp" in seg and isinstance(seg["timestamp"], (list, tuple)) and seg["timestamp"]:
            start = seg["timestamp"][0] or 0
            end = seg["timestamp"][1] if len(seg["timestamp"]) > 1 else start
        else:
            start = seg.get("start", 0) or 0
            end = seg.get("end", start) or start
        speaker = seg.get("speaker")
        if speaker is None and isinstance(seg.get("words"), list) and seg["words"]:
            counts: dict = {}
            for w in seg["words"]:
                sp = w.get("speaker")
                if sp is not None:
                    counts[sp] = counts.get(sp, 0) + 1
            if counts:
                speaker = max(counts.items(), key=lambda kv: kv[1])[0]
        if text:
            out.append({
                "start": float(start),
                "end": float(end or start),
                "text": text,
                "speaker": speaker,
            })
    return out


def _normalize_speakers(rows: list[dict]) -> list[dict]:
    """Map raw speaker IDs to stable Speaker 0..N in first-seen order."""
    mapping: dict = {}
    for r in rows:
        sp = r["speaker"]
        if sp is None:
            continue
        if sp not in mapping:
            mapping[sp] = f"Speaker {len(mapping)}"
    for r in rows:
        r["speaker"] = mapping.get(r["speaker"], "Speaker ?")
    return rows


def format_transcript(payload: dict, speaker_map: dict[str, str] | None = None) -> str:
    backend = payload.get("backend")
    if backend == "mac":
        rows = _align_mac(payload["stt"], payload["diar"])
    elif backend == "whisply":
        rows = _extract_whisply(payload["whisply"])
    else:
        rows = []
    rows = _normalize_speakers(rows)

    if speaker_map:
        for r in rows:
            r["speaker"] = speaker_map.get(r["speaker"], r["speaker"])

    lines = []
    prev = None
    buf_text: list = []
    buf_start: float | None = None

    for r in rows:
        label = r["speaker"]
        if label != prev:
            if buf_text:
                lines.append(
                    f"**[{_format_timestamp(buf_start)}] {prev}:** " + " ".join(buf_text)
                )
            buf_text = [r["text"]]
            buf_start = r["start"]
            prev = label
        else:
            buf_text.append(r["text"])

    if buf_text:
        lines.append(
            f"**[{_format_timestamp(buf_start)}] {prev}:** " + " ".join(buf_text)
        )

    return "\n\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Local transcription with diarization (mlx-whisper + FluidAudio on Mac, whisply elsewhere)"
    )
    parser.add_argument("input", help="Path to audio/video file")
    parser.add_argument("--output", "-o", help="Output .md path (default: <input>.transcript.md)")
    parser.add_argument(
        "--relabel",
        help='JSON map to rename speakers: \'{"Speaker 0": "Alex", "Speaker 1": "Maria"}\'',
    )
    parser.add_argument(
        "--model",
        default=None,
        help=f"Whisper model. Mac default: {DEFAULT_WHISPER_REPO}. Fallback default: large-v3-turbo.",
    )
    parser.add_argument(
        "--language", "-l", default=None,
        help="Language code (default: auto-detect; e.g. ru, en, de)",
    )
    parser.add_argument(
        "--num-speakers", type=int, default=None,
        help="Number of speakers (default: auto-detect)",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Re-run pipeline even if cached JSON exists",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    cache_path = input_path.with_suffix(".transcribe.json")
    legacy_cache = input_path.with_suffix(".whisply.json")
    output_path = args.output or str(input_path.with_suffix(".transcript.md"))

    speaker_map = json.loads(args.relabel) if args.relabel else None

    if cache_path.exists() and not args.force:
        print(f"Using cached transcription: {cache_path}", file=sys.stderr)
        with open(cache_path, "r", encoding="utf-8") as f:
            payload = json.load(f)
    elif legacy_cache.exists() and not args.force:
        print(f"Using legacy whisply cache: {legacy_cache}", file=sys.stderr)
        with open(legacy_cache, "r", encoding="utf-8") as f:
            payload = {"backend": "whisply", "whisply": json.load(f)}
    else:
        if MAC:
            model = args.model or DEFAULT_WHISPER_REPO
            payload = transcribe_mac(input_path, args.language, args.num_speakers, model)
        else:
            model = args.model or "large-v3-turbo"
            payload = transcribe_fallback(input_path, args.language, args.num_speakers, model)
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        print(f"Pipeline cached: {cache_path}", file=sys.stderr)

    transcript = format_transcript(payload, speaker_map)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(f"# Transcript: {input_path.name}\n\n")
        if speaker_map:
            seen = set()
            uniq = []
            for n in speaker_map.values():
                if n not in seen:
                    seen.add(n)
                    uniq.append(n)
            f.write(f"**Speakers:** {', '.join(uniq)}\n\n---\n\n")
        f.write(transcript)
        f.write("\n")

    print(f"Transcript saved to {output_path}", file=sys.stderr)
    print(output_path)


if __name__ == "__main__":
    main()
