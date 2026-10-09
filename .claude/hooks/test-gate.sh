#!/usr/bin/env bash
# Stop hook — "test after every feature" enforcement.
# If code files were edited this session and no test command was run, block the
# agent from declaring done until it runs the project's tests and cites output.
# Fail-open on any error. Loop-safe: caps at 2 blocks per git HEAD, then gives up.
set -euo pipefail
trap 'exit 0' ERR

command -v jq >/dev/null 2>&1 || exit 0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STDIN="$(cat)"

# Never re-block once already inside a Stop-hook continuation.
[ "$(printf '%s' "$STDIN" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

SESSION_ID="$(printf '%s' "$STDIN" | jq -r '.session_id // empty')"
TRANSCRIPT="$(printf '%s' "$STDIN" | jq -r '.transcript_path // empty')"
[ -n "$SESSION_ID" ] || exit 0
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Did the agent edit any code file this session?
EDITED="$(jq -r 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use")
  | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit")
  | .input.file_path // empty' "$TRANSCRIPT" 2>/dev/null || echo)"
. "$(dirname "$0")/lib/quality.sh"
CODE_EDIT="$(printf '%s\n' "$EDITED" | while IFS= read -r f; do is_code_file "$f" && { echo "$f"; break; }; done || true)"
[ -n "$CODE_EDIT" ] || exit 0

# Resolve this project's test command — same detection as the Verify hook (lib/quality.sh).
TEST_CMD="$(detect_test_cmd "$ROOT")"
TEST_PAT="$(printf '%s' "$TEST_CMD" | awk '{print ($1=="python3"||$1=="uv") ? "pytest|unittest" : $1" "$2}')|pytest|unittest|go test|npm test|vitest|jest|gradlew|make test|cargo test|flutter test"
[ -n "$TEST_CMD" ] || exit 0   # no known test command -> nothing to enforce

# Was a test command actually run in a Bash tool call this session?
RAN="$(jq -r 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use") | select(.name=="Bash")
  | .input.command // empty' "$TRANSCRIPT" 2>/dev/null | grep -ciE "$TEST_PAT" || true)"
RAN="${RAN:-0}"
[ "$RAN" -gt 0 ] && exit 0
# The Verify hook (verify.sh) already ran the suite green after the last code edit.
grep -q '^pass ' "$ROOT/.claude/sessions/${SESSION_ID}.verify" 2>/dev/null && exit 0

# Loop-safe cap: <=2 blocks at the same HEAD.
SESS_DIR="$ROOT/.claude/sessions"; mkdir -p "$SESS_DIR" 2>/dev/null || exit 0
COUNTER="$SESS_DIR/${SESSION_ID}.testcount"
HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo no-git)"
PREV_HEAD=""; PREV_COUNT=0
if [ -f "$COUNTER" ]; then
  PREV_HEAD="$(cut -d' ' -f1 "$COUNTER" 2>/dev/null || echo)"
  PREV_COUNT="$(cut -d' ' -f2 "$COUNTER" 2>/dev/null || echo 0)"
fi
case "$PREV_COUNT" in ''|*[!0-9]*) PREV_COUNT=0 ;; esac
if [ "$PREV_HEAD" = "$HEAD" ]; then
  [ "$PREV_COUNT" -ge 2 ] && exit 0
  NEW_COUNT=$((PREV_COUNT + 1))
else NEW_COUNT=1; fi
printf '%s %s\n' "$HEAD" "$NEW_COUNT" > "$COUNTER" 2>/dev/null || true

MSG="You edited code (\`$(basename "$CODE_EDIT")\`) but ran no tests this session. Run \`$TEST_CMD\` and cite the real output before declaring done. Build-green is not tested. If a test genuinely can't run here, say why."
jq -nc --arg r "$MSG" --arg c "$MSG  (test-gate ${NEW_COUNT}/2 at this commit)" \
  '{decision:"block", reason:$r, hookSpecificOutput:{hookEventName:"Stop", additionalContext:$c}}'
exit 0
