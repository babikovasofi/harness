# Shared helpers for the quality hooks (verify, lint) and scripts/mutate.py callers.
# Source it: . "$(dirname "$0")/lib/quality.sh"

QUALITY_FILE="${ROOT:-.}/.claude/harness/quality.json"

# q <jq path> <default> — read a value from .claude/harness/quality.json.
q() {
  local v
  v="$(jq -r "$1 // empty" "$QUALITY_FILE" 2>/dev/null || true)"
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"
}

# Code files the quality hooks care about (tests included).
is_code_file() {
  printf '%s' "$1" | grep -qiE '\.(py|ts|tsx|js|jsx|mjs|cjs|go|rs|rb|java|kt|kts|swift|dart|cs|php|scala|c|cc|cpp|h|hpp|tf)$'
}

# detect_test_cmd <root> — a runnable test command for this project, or empty.
detect_test_cmd() {
  local r="$1" c
  c="$(q '.verify.command' '')"
  if [ -n "$c" ]; then printf '%s' "$c"; return; fi
  if [ -f "$r/pubspec.yaml" ]; then printf 'flutter test'
  elif [ -f "$r/pyproject.toml" ] || [ -f "$r/pytest.ini" ] || [ -f "$r/setup.cfg" ]; then
    if [ -f "$r/uv.lock" ] && command -v uv >/dev/null 2>&1; then printf 'uv run pytest -q'; else printf 'python3 -m pytest -q'; fi
  elif [ -f "$r/go.mod" ]; then printf 'go test ./...'
  elif [ -f "$r/Cargo.toml" ]; then printf 'cargo test --quiet'
  elif [ -f "$r/build.gradle.kts" ] || [ -f "$r/build.gradle" ]; then printf './gradlew test -q'
  elif [ -f "$r/package.json" ] && jq -e '.scripts.test // empty' "$r/package.json" >/dev/null 2>&1; then printf 'npm test --silent'
  elif [ -f "$r/Makefile" ] && grep -qE '^test:' "$r/Makefile" 2>/dev/null; then printf 'make test'
  fi
}

# run_timeout <seconds> <shell command> — macOS has no coreutils `timeout`; perl alarm does it.
# Exit 142 = killed by the alarm.
run_timeout() {
  local s="$1"; shift
  perl -e 'alarm shift; exec @ARGV' "$s" sh -c "$*"
}

# repo_root_of <file> — top of the git checkout that holds the file. A night run edits
# files inside .claude/worktrees/<name>/, so tests must run there, not in $CLAUDE_PROJECT_DIR.
repo_root_of() {
  local d; d="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || return 1
  git -C "$d" rev-parse --show-toplevel 2>/dev/null
}

# Harness template repo itself: quality hooks stay quiet there.
is_harness_template() { [ -f "${ROOT:-.}/.claude/skills/setup/SKILL.md" ]; }
