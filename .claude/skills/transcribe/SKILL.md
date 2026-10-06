---
name: transcribe
description: >
  Transcribe a meeting recording locally with speaker diarization. On macOS
  (Apple Silicon) uses mlx-whisper + FluidAudio (CoreML, ANE) for ~30× realtime
  speed; on other platforms falls back to whisply (faster-whisper + pyannote).
  Use when the user asks to transcribe a recording, generate a transcript,
  or identify speakers from audio/video.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: <path-to-audio-or-video-file>
---

# Meeting Transcription with Speaker Diarization (local)

Transcribe an audio or video recording locally:

- **macOS (Apple Silicon)** — mlx-whisper (Whisper large-v3-turbo via MLX) for STT + FluidAudio CLI (pyannote-segmentation + WeSpeaker via CoreML on the Neural Engine) for diarization. ~30× realtime on M-series. No HF token needed.
- **Other platforms** — whisply (faster-whisper + pyannote). Requires HF token + accepting gated pyannote models.

The skill bootstraps and maintains its own global Python venv at `~/.local/share/transcribe-skill/.venv/` and (on Mac) builds FluidAudio into `~/.local/share/transcribe-skill/FluidAudio/`. No per-project setup needed.

The input file path is provided as `$ARGUMENTS`.

## Step 0: Environment Check

**macOS:** no token needed. Verify Swift is available:
```
command -v swift >/dev/null && echo OK || echo "run: xcode-select --install"
```

**Other platforms:** verify `HF_TOKEN` is set (env, project `.env`, or `~/.config/transcribe-skill/.env`):
```
grep -h HF_TOKEN .env ~/.config/transcribe-skill/.env 2>/dev/null | head -1
```
If missing, read `${CLAUDE_SKILL_DIR}/references/local-setup.md` and walk the user through setup.

No venv setup needed. `run.sh` auto-creates everything on first invocation:
- venv (~10s)
- mlx-whisper / whisply install (~30s-2min)
- FluidAudio clone + build (Mac only, ~1-2 min)

## Step 1: Transcribe

```
bash ${CLAUDE_SKILL_DIR}/scripts/run.sh $ARGUMENTS
```

The wrapper will:
- Bootstrap venv + FluidAudio (first run only)
- Pre-convert input to 16 kHz mono WAV via ffmpeg
- Run STT + diarization, align by timestamp overlap (Mac) or use whisply's combined output (fallback)
- Cache the raw pipeline output as `<file>.transcribe.json` (reused on subsequent runs — no recompute)
- Generate `<file>.transcript.md` with generic speaker labels (Speaker 0, Speaker 1, ...)

If `<file>.transcribe.json` already exists, the script skips compute and reuses it. Use `--force` to re-run. Legacy `<file>.whisply.json` caches from older skill versions are also honored.

Flags (passed through to `transcribe.py`):
- `--model <name>` — override Whisper model. Mac default: `mlx-community/whisper-large-v3-turbo`. Fallback default: `large-v3-turbo`. Use `large-v3` for max accuracy.
- `--language <code>` — force language (default auto-detect; e.g. `ru`, `en`, `de`)
- `--num-speakers <N>` — fix speaker count if auto-detect splits wrong
- `--output <path>` — output `.md` path (default: `<input>.transcript.md`)
- `--force` — bypass JSON cache and re-run pipeline

## Step 2: Auto-identify Speakers (MANDATORY — do not skip)

After Step 1 finishes, immediately read the generated `.transcript.md` file and analyze the conversation to identify speakers. Do not just dump the transcript and stop — the auto-labeling step is part of every transcribe invocation.

1. Look for self-introductions (e.g. "Hi, I'm Alex", "My name is Maria") in whatever language the meeting was held in
2. Look for how speakers address each other by name
3. Look for role mentions ("I'm the tech lead", "we at <company>")
4. Cross-reference with project-specific notes if available (e.g. `.assistant/`, `CLAUDE.md`, project README, attendee lists)

Build a proposed mapping like:
```
Speaker 0 → Alex Smith (host, leads the discussion)
Speaker 1 → Maria Jones (engineer, presents the design)
```

Present the proposed mapping to the user and ask for confirmation or corrections using AskUserQuestion. Show a few representative quotes from each speaker to help the user verify.

## Step 3: Relabel

Once the user confirms the speaker mapping, run the relabel command:

```
bash ${CLAUDE_SKILL_DIR}/scripts/run.sh $ARGUMENTS --relabel '{"Speaker 0": "Alex Smith", "Speaker 1": "Maria Jones"}'
```

This rewrites `.transcript.md` with real names. The cached `.transcribe.json` is reused — no recompute.

## Step 4: Save

Ask the user where to save the final transcript. Suggest a sensible default based on the project structure (e.g., a `transcripts/` directory or project root).

Move the final `.transcript.md` to the chosen location with a descriptive filename.

Report the final file path to the user.

## Notes

- Supported formats: mp4, mp3, wav, m4a, webm, ogg, flac, and other common audio/video formats supported by ffmpeg
- First run (Mac) downloads Whisper model (~1.5 GB) to `~/.cache/huggingface/` and FluidAudio models (~50-100 MB) to `~/Library/Application Support/FluidAudio/Models/`
- Subsequent runs: ~1 min for a 30-min recording on M-series Mac
- Cached `.transcribe.json` contains raw STT segments (with word-level timestamps) + diarization segments — add `*.transcribe.json` to `.gitignore`
- All processing is local — no audio leaves the machine
- Global venv: `~/.local/share/transcribe-skill/.venv/` (override with `TRANSCRIBE_VENV` env var)
- FluidAudio binary: `~/.local/share/transcribe-skill/FluidAudio/.build/release/fluidaudiocli` (override with `FLUIDAUDIO_BIN`)
- Requires Python 3.11-3.13 on PATH; Swift toolchain on Mac (Xcode Command Line Tools)
