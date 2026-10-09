#!/usr/bin/env bash
# SubagentStop hook — an executing agent (agent file with the `harness:exec` marker) may not
# finish without the exec-contract YAML (`status:` + `tests_result:`). Other agents pass.
# Fail-open on any error. Loop-safe: never re-blocks inside a stop-hook continuation.
set -euo pipefail
trap 'exit 0' ERR
command -v jq >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
STDIN="$(cat)"
[ "$(printf '%s' "$STDIN" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

AGENT="$(printf '%s' "$STDIN" | jq -r '.agent_type // empty')"
AGENT_FILE="$ROOT/.claude/agents/${AGENT}.md"
[ -n "$AGENT" ] && [ -f "$AGENT_FILE" ] && grep -q 'harness:exec' "$AGENT_FILE" || exit 0

MSG="$(printf '%s' "$STDIN" | jq -r '.last_assistant_message // empty')"
if printf '%s' "$MSG" | grep -qE '^[[:space:]]*status:' && printf '%s' "$MSG" | grep -qE '^[[:space:]]*tests_result:'; then
  exit 0
fi

REASON="Return the exec-contract YAML from .claude/harness/exec-contract.md (at least status, changed_files, tests_run, tests_result, tests_output). Tests not run → tests_result: not_run + why."
jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
exit 0
