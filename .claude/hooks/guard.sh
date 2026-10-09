#!/usr/bin/env bash
# PreToolUse(Bash) hook — hard rails that prose alone cannot guarantee:
#   - no reading .env / printing the Tavily key (use .claude/scripts/env-has-key.sh)
#   - no force-push, ever (the user runs it themselves after a separate yes)
#   - night run active (.claude/state/night.active): no push except memory-defrag/*,
#     no PR merges
# Exit 2 blocks the call; stderr is shown to Claude. Fail-open on parse errors.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
RAW="$(jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[ -n "$RAW" ] || exit 0
# Check the command itself, not heredoc bodies: text written into a file (docs, scripts)
# may mention `.env` without touching it.
CMD="$(printf '%s\n' "$RAW" | awk '
  skip { if ($0 == delim || $0 ~ "^[[:space:]]*" delim "$") skip=0; next }
  { print }
  match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
    d = substr($0, RSTART, RLENGTH); sub(/<<-?[[:space:]]*["'"'"']?/, "", d); delim=d; skip=1
  }')"

block() { echo "harness guard: $1" >&2; exit 2; }

if printf '%s' "$CMD" | grep -qE '(^|[[:space:]"'"'"'=/<(])\.env($|[[:space:]"'"'"';|&)>])'; then
  block "commands that touch .env are blocked (secrets). Check a key with .claude/scripts/env-has-key.sh <NAME>; the user edits .env themselves."
fi
if printf '%s' "$CMD" | grep -q 'TAVILY_API_KEY' && ! printf '%s' "$CMD" | grep -q 'env-has-key.sh'; then
  block "do not print or pass the Tavily key; it stays in .env."
fi

if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push'; then
  if printf '%s' "$CMD" | grep -qE '(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+[A-Za-z0-9_./-]+)'; then
    block "force-push is blocked. Ask the user; they run it themselves after a separate explicit yes."
  fi
  if [ -f "$ROOT/.claude/state/night.active" ] && ! printf '%s' "$CMD" | grep -q 'memory-defrag/'; then
    block "night run active: the only allowed push is the memory-defrag/<date> branch."
  fi
fi

if [ -f "$ROOT/.claude/state/night.active" ] && printf '%s' "$CMD" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge'; then
  block "night run active: PRs are never merged at night."
fi

exit 0
