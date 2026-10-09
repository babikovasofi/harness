#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook — Verify: after every code edit run the project's
# tests, so an agent cannot come back with "done" while something is broken.
# Red → decision:block with the output tail (Claude sees it and fixes). Green → one short
# line of evidence. Records the result for test-gate.sh. Off: quality.json verify.enabled
# false, or HARNESS_VERIFY=0. Fail-open on hook errors.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
. "$(dirname "$0")/lib/quality.sh"

[ "${HARNESS_VERIFY:-1}" = "0" ] && exit 0
[ "$(q '.verify.enabled' 'true')" = "true" ] || exit 0
is_harness_template && exit 0

STDIN="$(cat)"
FILE="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
SESSION="$(printf '%s' "$STDIN" | jq -r '.session_id // "nosession"')"
[ -n "$FILE" ] && is_code_file "$FILE" || exit 0
# Tests run in the checkout that holds the edited file (night worktree included); its own
# quality.json wins. The session state file stays under the main project dir.
STATE_ROOT="$ROOT"
FROOT="$(repo_root_of "$FILE")" && [ -n "$FROOT" ] && ROOT="$FROOT" && QUALITY_FILE="$ROOT/.claude/harness/quality.json"
[ -f "$QUALITY_FILE" ] || QUALITY_FILE="$STATE_ROOT/.claude/harness/quality.json"

CMD="$(detect_test_cmd "$ROOT")"
[ -n "$CMD" ] || exit 0
TO="$(q '.verify.timeout_sec' '120')"

START=$(date +%s)
OUT="$(cd "$ROOT" && run_timeout "$TO" "$CMD" 2>&1)"; RC=$?
DUR=$(( $(date +%s) - START ))

mkdir -p "$STATE_ROOT/.claude/sessions" 2>/dev/null || true
STATE="$STATE_ROOT/.claude/sessions/${SESSION}.verify"

if [ "$RC" -eq 0 ]; then
  printf 'pass %s\n' "$(date +%s)" > "$STATE" 2>/dev/null || true
  jq -nc --arg c "Verify: tests green after editing $(basename "$FILE") (\`$CMD\`, ${DUR}s)." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$c}}'
  exit 0
fi

if [ "$RC" -eq 142 ]; then
  printf 'timeout %s\n' "$(date +%s)" > "$STATE" 2>/dev/null || true
  jq -nc --arg c "Verify: \`$CMD\` did not finish in ${TO}s after editing $(basename "$FILE"); run the relevant tests yourself before claiming done (raise verify.timeout_sec in .claude/harness/quality.json if the suite is just slow)." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$c}}'
  exit 0
fi

printf 'fail %s\n' "$(date +%s)" > "$STATE" 2>/dev/null || true
TAIL="$(printf '%s\n' "$OUT" | tail -30)"
jq -nc --arg r "Verify: tests FAIL after editing $FILE (\`$CMD\`, exit $RC). Writing a red test first on purpose (TDD, /debug repro)? Then this is expected — go on and make it green. Otherwise fix the code (never weaken the test):
$TAIL" '{decision:"block", reason:$r}'
exit 0
