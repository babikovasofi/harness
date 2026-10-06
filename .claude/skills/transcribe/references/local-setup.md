# Local transcription — setup

`transcribe.py` picks a backend based on the platform:

| Platform | STT | Diarization | Speed (RTF) |
|----------|-----|-------------|-------------|
| **macOS (Apple Silicon)** | mlx-whisper (MLX) | FluidAudio (CoreML, ANE) | ~30× realtime |
| Linux / Intel Mac / Windows | whisply (faster-whisper) | pyannote-audio | ~3-5× realtime |

`run.sh` bootstraps everything on first invocation:
- venv at `~/.local/share/transcribe-skill/.venv/`
- macOS: clones and builds FluidAudio `v0.14.7` into `~/.local/share/transcribe-skill/FluidAudio/`
- Whisper and FluidAudio models are downloaded on demand

## macOS (default — fast path)

No tokens, no manual setup.

Requirements:
- macOS on Apple Silicon (M1+)
- Python 3.11-3.13 (`brew install python@3.12`)
- Swift toolchain — usually already installed. If not: `xcode-select --install`
- ffmpeg (`brew install ffmpeg`)

First run:
```bash
bash ~/.claude/skills/transcribe/scripts/run.sh path/to/file.m4a
```

What happens on first run:
- venv is created (~10s)
- `pip install mlx-whisper python-dotenv` (~30s)
- `git clone` FluidAudio + `swift build -c release` (~1-2 min)
- Whisper model `large-v3-turbo` downloaded from HF (~1.5 GB, one-time)
- FluidAudio models (pyannote-segmentation + WeSpeaker) downloaded to `~/Library/Application Support/FluidAudio/Models/` (~50-100 MB, one-time)

After that: ~1 minute for a 30-minute file.

## Linux / Intel Mac / Windows (fallback)

Requires a HuggingFace token and acceptance of gated pyannote models.

### 1. HuggingFace token

1. https://huggingface.co/join
2. https://huggingface.co/settings/tokens → **New token** → **Read**
3. Copy it (`hf_xxxxxxxx`)

### 2. Accept gated pyannote models

Visit while logged in and click **Agree and access**:
- https://huggingface.co/pyannote/segmentation-3.0
- https://huggingface.co/pyannote/speaker-diarization-3.1

### 3. Provide the token

Globally (recommended):
```bash
mkdir -p ~/.config/transcribe-skill
echo 'HF_TOKEN=hf_xxx' > ~/.config/transcribe-skill/.env
```

Or in a project-local `.env`, or via `export HF_TOKEN=...`.

## FAQ

**Q: How long does transcription take?**
A: macOS (FluidAudio + mlx-whisper): RTF ~30× — a 30-minute file in about a minute. Fallback: RTF 3-5×.

**Q: Quality for non-English languages?**
A: `large-v3-turbo` gives WER ~10% on clean speech. Use `--model large-v3` for higher accuracy (~7% WER) at the cost of speed.

**Q: Diarization mixes speakers up?**
A: Pass the exact count: `--num-speakers N`.

**Q: How do I change the FluidAudio version?**
A: Remove `~/.local/share/transcribe-skill/FluidAudio/`, update `FA_VERSION` in `run.sh`, re-run.

**Q: Where are the caches?**
- Whisper: `rm -rf ~/.cache/huggingface/hub`
- FluidAudio: `rm -rf ~/Library/Application\ Support/FluidAudio/`
- Venv: `rm -rf ~/.local/share/transcribe-skill/.venv`

**Q: How do I point to a different `fluidaudiocli` binary?**
A: Set `FLUIDAUDIO_BIN=/path/to/fluidaudiocli` to override the default path.

**Q: Big file — how to speed it up?**
A: ffmpeg pre-conversion is unnecessary (the script downmixes to 16 kHz mono itself). To save disk space first:
```bash
ffmpeg -i input.mp4 -vn -acodec libopus -b:a 48k output.ogg
```

**Q: How does the transcription cache work?**
A: After the first run a `<input>.transcribe.json` is written next to the source file. Subsequent invocations (including `--relabel`) reuse it without recomputing. Force a fresh run with `--force`.
