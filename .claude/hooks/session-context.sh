#!/usr/bin/env bash
# SessionStart hook — puts the Memory Bank index into context on start/resume/compact, so
# "read the Memory Bank first" does not depend on discipline. During a night run it also
# tells Claude (after compaction or resume) to re-read the brief, the log and the rails.
set -euo pipefail
trap 'exit 0' ERR
command -v jq >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
STDIN="$(cat)"
SOURCE="$(printf '%s' "$STDIN" | jq -r '.source // "startup"')"

CTX=""
if [ -f "$ROOT/.claude/skills/setup/SKILL.md" ]; then
  CTX="This repo is the HARNESS TEMPLATE itself (it has .claude/skills/setup). Keep it clean: do not write project facts to .memory-bank/, decisions to decisions.md, or reports to swarm-report/. Steward check → NO_MEMORY_UPDATE (harness template)."
elif [ -f "$ROOT/.memory-bank/index.md" ]; then
  CTX="Memory Bank index (.memory-bank/index.md):
$(head -c 4000 "$ROOT/.memory-bank/index.md")"
  [ -f "$ROOT/.memory-bank/decisions.md" ] && CTX="$CTX

Decisions already made live in .memory-bank/decisions.md — read it before asking the user anything."
fi

MARK="$ROOT/.claude/state/night.active"
if [ -f "$MARK" ] && [ "$SOURCE" != "startup" ]; then
  CTX="$CTX

NIGHT RUN IN PROGRESS ($SOURCE). Before the next step re-read .claude/skills/night/rails.md and the files listed here, then continue the per-task loop. No questions.
$(cat "$MARK")"
fi

[ -n "$CTX" ] || exit 0
jq -nc --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$c}}'
