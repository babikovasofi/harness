---
name: setup
description: Install this harness into a target project. Copies AGENTS.md, the consilium agents, all skills (except setup), hooks, harness templates, scripts, settings (merged), .mcp.json (merged), .env.example and .gitignore lines, then seeds an empty Memory Bank and swarm-report/. Links AGENTS.md from an existing CLAUDE.md. Run this from a clone of the harness repo — pass the absolute path to the project you want to equip.
argument-hint: "<absolute-path-to-target-project>"
when_to_use: "Invoke when the user says «поставь харнесс в проект <путь>», «установи харнесс», «подключи харнесс к проекту». Only from the harness repo."
---

# Skill: /setup

Install the harness into another project. You run in a clone of the harness repo; the
target is a different directory the user names. This skill only moves and merges files:
no build, no user code edits.

## Invocation
`/setup <absolute-path-to-target-project>`

## Step 1 — Checks and the one question form (start checkpoint)

1. `SRC` = this harness repo root (`$CLAUDE_PROJECT_DIR`). `DST` = the argument, `~`
   expanded. No argument → ask for it. `DST` missing / not a directory → abort:
   "Target `<path>` not found — give the absolute path to your project." `DST` = `SRC` →
   refuse.
2. Collect every conflict first, then ask once (`AskUserQuestion`, плюсы / минусы per
   option) — never in the middle of copying:
   - `DST` not a git repo → offer `git init`.
   - `DST/AGENTS.md` exists → overwrite / keep theirs and append ours under a heading /
     skip.
   - `DST/CLAUDE.md` (or `CLAUDE.local.md`) exists without `@AGENTS.md` → add the line
     `@AGENTS.md` at its top? (Claude Code reads only `CLAUDE.md` when both exist.)
   - `DST/.claude/agents/<name>.md` exists with the same name as ours → overwrite / skip.
3. Dependencies (warn, do not block): `jq` (hooks), `git`, `gh` (night defrag PR),
   `node`/`npx` (Tavily MCP), `ast-index` (code index:
   `brew tap defendend/ast-index && brew install ast-index`), Python 3.11–3.13 + `ffmpeg`
   (transcribe).

## Step 2 — Copy

```bash
mkdir -p "$DST/.claude/agents" "$DST/.claude/skills" "$DST/.claude/hooks" \
         "$DST/.claude/harness" "$DST/.claude/scripts" "$DST/swarm-report"
cp "$SRC"/.claude/agents/*.md "$DST/.claude/agents/"            # consilium only in SRC
for s in "$SRC"/.claude/skills/*/; do
  n=$(basename "$s"); [ "$n" = setup ] && continue              # target never re-installs
  rm -rf "$DST/.claude/skills/$n" && cp -R "$s" "$DST/.claude/skills/$n"
done
cp "$SRC"/.claude/hooks/*.sh "$DST/.claude/hooks/"   && chmod +x "$DST"/.claude/hooks/*.sh
cp "$SRC"/.claude/harness/*  "$DST/.claude/harness/"
cp "$SRC"/.claude/scripts/*  "$DST/.claude/scripts/" && chmod +x "$DST"/.claude/scripts/*.sh
chmod +x "$DST"/.claude/skills/transcribe/scripts/run.sh
[ -f "$DST/swarm-report/.gitkeep" ] || touch "$DST/swarm-report/.gitkeep"
```
`AGENTS.md` and `CLAUDE.md` — per the answers from step 1.

## Step 3 — Merge, never clobber

- **`.claude/settings.json`** — absent → copy. Present → merge with `jq`: for every hook
  event in ours (`SessionStart`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop`,
  `PreToolUse`, `Stop`)
  add our entries, dedupe by `command`; union `permissions.deny`. Keep all their keys.
  Verify the result parses (`jq . file`).
- **`.mcp.json`** — absent → copy. Present → add `mcpServers."tavily-research"` only if
  missing.
- **`.env.example`** — absent → copy. Present → append `TAVILY_API_KEY=` if missing.
  Never create or touch `.env`.
- **`.gitignore`** — append each of our lines that is missing (`.claude/sessions/`,
  `.claude/state/`, `.claude/worktrees/`, `.env`, `*.transcribe.json`, `.DS_Store`,
  `.ast-index-root`).
  Append-only.

## Step 4 — Seed an empty Memory Bank (never overwrite)

`DST/.memory-bank/` absent → copy `SRC/.memory-bank/index.md` and the empty folders
(`product-overview/`, `steerings/`, `tech-details/`, `tasks/` with `.gitkeep`). No
`decisions.md` — it appears with the first decision. Present → leave it untouched.

## Step 4b — Code index

`ast-index` installed → `(cd "$DST" && ast-index rebuild)` once, report the `ast-index stats`
line. Not installed → say how to install; the SessionStart hook builds the index on the
first session after that.

## Step 5 — Report

List exactly what was written / merged / skipped, then the next steps:
1. `cp .env.example .env` and put the Tavily key in `.env` (for `/research`) — never in chat.
2. Open `<DST>` in Claude Code, approve the `tavily-research` MCP server when asked.
3. Fill `.memory-bank/index.md` (what, goal, stack) — or ask Claude to draft it from the repo.
4. Add exec agents for the stack: `/new-agent <stack>`.
5. Start: "день" + task, or `/plan "<first feature>"`.

## Notes
- Idempotent: re-running refreshes agents / skills / hooks / templates to the current
  version, dedupes settings, never touches `.memory-bank/`, `.env`, or the user's own hooks.
- The harness repo itself stays a clean template — `/setup` never writes back into `SRC`.
