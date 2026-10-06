#!/usr/bin/env bash
# Bootstrap transcribe-skill deps and run transcribe.py.
#
# macOS (Apple Silicon): mlx-whisper for STT + FluidAudio (CoreML) for diarization.
# Other platforms: whisply (faster-whisper + pyannote) fallback.
set -euo pipefail

ROOT_DIR="${TRANSCRIBE_ROOT:-$HOME/.local/share/transcribe-skill}"
VENV_DIR="${TRANSCRIBE_VENV:-$ROOT_DIR/.venv}"
FA_DIR="$ROOT_DIR/FluidAudio"
FA_VERSION="v0.14.7"
FA_BIN="$FA_DIR/.build/release/fluidaudiocli"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$ROOT_DIR"

if [ ! -d "$VENV_DIR" ]; then
  echo "→ Creating venv at $VENV_DIR" >&2
  PYTHON_CMD=""
  for candidate in python3.12 python3.11 python3.13 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      ver=$("$candidate" -c 'import sys; print("%d.%d" % sys.version_info[:2])')
      major=${ver%.*}; minor=${ver#*.}
      if [ "$major" = "3" ] && [ "$minor" -ge 11 ] && [ "$minor" -le 13 ]; then
        PYTHON_CMD="$candidate"
        break
      fi
    fi
  done
  if [ -z "$PYTHON_CMD" ]; then
    echo "Error: need Python 3.11-3.13. Install via 'brew install python@3.12'." >&2
    exit 1
  fi
  "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090,SC1091
source "$VENV_DIR/bin/activate"

if [ "$(uname -s)" = "Darwin" ]; then
  if ! python -c "import mlx_whisper, dotenv" 2>/dev/null; then
    echo "→ Installing mlx-whisper + python-dotenv" >&2
    pip install -q mlx-whisper python-dotenv
  fi
  if [ ! -x "$FA_BIN" ] && [ -z "${FLUIDAUDIO_BIN:-}" ]; then
    if ! command -v swift >/dev/null 2>&1; then
      echo "Error: Swift toolchain not found. Install Xcode or Command Line Tools (xcode-select --install)." >&2
      exit 1
    fi
    if [ ! -d "$FA_DIR" ]; then
      echo "→ Cloning FluidAudio $FA_VERSION" >&2
      git clone --depth=1 --branch "$FA_VERSION" https://github.com/FluidInference/FluidAudio.git "$FA_DIR" >&2
    fi
    echo "→ Building FluidAudio (one-time, ~1-2 min)" >&2
    (cd "$FA_DIR" && swift build -c release >&2)
    if [ ! -x "$FA_BIN" ]; then
      echo "Error: FluidAudio build did not produce $FA_BIN" >&2
      exit 1
    fi
  fi
else
  if ! python -c "import whisply, dotenv" 2>/dev/null; then
    echo "→ Installing whisply fallback (one-time, ~2 min)" >&2
    pip install -q whisply python-dotenv
  fi
fi

exec python "$SCRIPT_DIR/transcribe.py" "$@"
