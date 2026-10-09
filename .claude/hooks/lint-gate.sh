#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook — lint after every code edit: file length,
# control-flow nesting, one-letter names (lib/lint_check.py, thresholds in
# .claude/harness/quality.json) + the project's own linter for that file when present
# (ruff, eslint, gofmt, ktlint, swiftlint, rubocop). Issues → decision:block with the list.
# Escape hatch for a justified exception: add the path glob to lint.ignore. Fail-open.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
. "$(dirname "$0")/lib/quality.sh"

[ "${HARNESS_LINT:-1}" = "0" ] && exit 0
[ "$(q '.lint.enabled' 'true')" = "true" ] || exit 0
is_harness_template && exit 0

FILE="$(jq -r '.tool_input.file_path // empty')"
[ -n "$FILE" ] && [ -f "$FILE" ] && is_code_file "$FILE" || exit 0
FROOT="$(repo_root_of "$FILE")" && [ -n "$FROOT" ] && ROOT="$FROOT" \
  && [ -f "$ROOT/.claude/harness/quality.json" ] && QUALITY_FILE="$ROOT/.claude/harness/quality.json"
REL="${FILE#"$ROOT"/}"

# lint.ignore: the project list if the key exists, else built-in defaults, so a partial
# quality.json does not drop them. (A function: bash 3.2 mis-parses quotes inside <(...).)
ignore_globs() {
  if jq -e '.lint | has("ignore")' "$QUALITY_FILE" >/dev/null 2>&1; then
    jq -r '.lint.ignore[]' "$QUALITY_FILE"
  else
    printf '%s\n' '**/migrations/**' '**/generated/**' '**/vendor/**' '**/node_modules/**' '**/*.lock' '**/*.min.js'
  fi
}
while IFS= read -r g; do
  [ -z "$g" ] && continue
  pat="${g//\*\*/*}"
  # "/$REL" lets "*/migrations/*" also match a top-level migrations/ dir
  [[ "$REL" == $pat || "/$REL" == $pat ]] && exit 0
done < <(ignore_globs)

ISSUES=""
if command -v python3 >/dev/null 2>&1; then
  ISSUES="$(python3 "$(dirname "$0")/lib/lint_check.py" "$FILE" "$QUALITY_FILE" 2>/dev/null || true)"
fi

if [ "$(q '.lint.run_project_linter' 'true')" = "true" ]; then
  L=""
  case "$FILE" in
    *.py)  command -v ruff >/dev/null 2>&1 && L="$(cd "$ROOT" && run_timeout 60 "ruff check --quiet --output-format concise '$FILE'" 2>&1)" ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
           ls "$ROOT"/eslint.config.* "$ROOT"/.eslintrc* >/dev/null 2>&1 && [ -x "$ROOT/node_modules/.bin/eslint" ] \
             && L="$(cd "$ROOT" && run_timeout 60 "node_modules/.bin/eslint --format unix '$FILE'" 2>&1)" ;;
    *.go)  command -v gofmt >/dev/null 2>&1 && [ -n "$(gofmt -l "$FILE" 2>/dev/null)" ] && L="gofmt: file is not formatted (run gofmt -w)" ;;
    *.kt|*.kts) command -v ktlint >/dev/null 2>&1 && L="$(cd "$ROOT" && run_timeout 60 "ktlint --relative '$FILE'" 2>&1)" ;;
    *.swift) command -v swiftlint >/dev/null 2>&1 && L="$(cd "$ROOT" && run_timeout 60 "swiftlint lint --quiet '$FILE'" 2>&1)" ;;
    *.rb)  command -v rubocop >/dev/null 2>&1 && L="$(cd "$ROOT" && run_timeout 60 "rubocop --format emacs '$FILE'" 2>&1 | grep -v 'no offenses')" ;;
  esac
  [ -n "$L" ] && ISSUES="$ISSUES
$(printf '%s\n' "$L" | head -15)"
fi

ISSUES="$(printf '%s\n' "$ISSUES" | sed '/^[[:space:]]*$/d')"
[ -n "$ISSUES" ] || exit 0

jq -nc --arg r "Lint: $REL
$ISSUES
Fix these now. A justified exception (generated file, data table) → add its glob to lint.ignore in .claude/harness/quality.json and say why." '{decision:"block", reason:$r}'
exit 0
