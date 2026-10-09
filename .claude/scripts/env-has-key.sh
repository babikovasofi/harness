#!/usr/bin/env bash
# Prints KEY_OK if .env has a non-empty value for the given name, else KEY_MISSING.
# Never prints the value. Usage: .claude/scripts/env-has-key.sh TAVILY_API_KEY
set -euo pipefail
NAME="${1:?usage: env-has-key.sh <NAME>}"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
if grep -qE "^${NAME}=.+" "$ROOT/.env" 2>/dev/null; then echo KEY_OK; else echo KEY_MISSING; fi
