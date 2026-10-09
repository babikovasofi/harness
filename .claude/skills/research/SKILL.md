---
name: research
description: Deep web research through Tavily (project MCP server `tavily-research`). First makes sure the user's TAVILY_API_KEY is in the project's .env (never pasted into chat), then researches the topic and returns clear numbered findings, each with the link it came from, plus a full report in swarm-report/. Use when the user says "ресеч", "research", "исследуй", "найди информацию про".
argument-hint: "<topic or question>"
---

# Skill: /research

ORCHESTRATOR. One command: key check → (clarify) → deep search → numbered findings
with sources. Chat answer in caveman mode (full); the report file is human-facing.

## Invocation
`/research "<topic or question>"`

## Step 1 — Tavily key

1. Check without printing the value:
   ```bash
   .claude/scripts/env-has-key.sh TAVILY_API_KEY
   ```
   Never touch `.env` directly — the `guard.sh` hook blocks it and `permissions.deny`
   blocks reading it.
2. `KEY_MISSING` → stop and tell the user, short:
   - Get a key at https://app.tavily.com.
   - `cp .env.example .env`, put the key after `TAVILY_API_KEY=`. `.env` is gitignored.
   - **Do not paste the key into chat** — chat history keeps it forever.
   - Restart the Claude Code session (the MCP server reads `.env` on start), then run
     `/research` again.
3. The user pastes a key into chat anyway → do not repeat it, do not write it anywhere.
   Say it is now in the session history, recommend rotating it at app.tavily.com, and
   point back to step 2.
4. Key OK but no `mcp__tavily-research__*` tools in this session → the project server
   is not approved/started yet: ask the user to approve `tavily-research` (prompt on
   session start, or `/mcp`) and restart. Do not fall back to other search tools
   silently — say which tool you use if the user agrees to one.

## Step 2 — Clarify (only if unclear, start checkpoint)

Topic clear → skip. Unclear or too broad → follow the question rules in `AGENTS.md`:
read `.memory-bank/` first, then one `AskUserQuestion` with 2–4 reasonable options
(scope, region, time range, depth), плюсы / минусы each, recommended first. This is the
only question point before the answer — none during the search.

## Step 3 — Research

1. Split the topic into 3–6 concrete sub-questions.
2. `tavily_research` on the main question for the overview (deep, multi-source).
3. `tavily_search` per sub-question, `search_depth: "advanced"`, recent results where
   freshness matters.
4. `tavily_extract` on the 3–8 strongest URLs to check that each claim is really there.
5. Rules:
   - Every finding needs ≥ 1 URL that a Tavily call actually returned. No URL → not a
     finding. Never invent or "fix up" links.
   - Sources disagree → say so, cite both.
   - Prefer primary sources (docs, official sites, papers, repos) over reposts.
   - Note the date of time-sensitive facts (prices, versions, limits).
   - Comparing options (libraries, APIs, vendors) → each gets плюсы / минусы with sources.

## Step 4 — Answer in chat

Short, numbered, caveman:
```
Ресеч: <topic>
1. <finding> — [source](url)
2. <finding> — [source](url), [source](url)
...
Расходятся: <conflict + both links, or "нет">
Не нашёл: <open gaps>
Отчёт: swarm-report/research-<slug>-<YYYY-MM-DD>.md
```

## Step 5 — Report file

Write `swarm-report/research-<slug>-<YYYY-MM-DD>.md` (human-facing → follow
`.claude/skills/anti-ai-slop-writing/SKILL.md`, + `references/ru-checklist.md` if in Russian):
```
# Research: <topic>
Date: <YYYY-MM-DD> · Tool: Tavily (tavily-research MCP)
## Question
## Short answer
## Findings          — numbered, each with inline source links
## Conflicts
## Open questions
## Sources           — every URL used, with title
```
`/plan` can use this file as input.

## Rules
- The key lives only in `.env`. Never in chat, commits, reports, logs or URLs.
- Only facts backed by returned sources; unknown stays unknown.
- End with the Memory Bank Steward check (as every reply).
