#!/usr/bin/env bash
# Starts the Tavily MCP server with TAVILY_API_KEY from the project's .env,
# so the key never has to be pasted into chat or committed.
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi
exec npx -y tavily-mcp@0.2.22
