---
name: night
description: Night mode — the user hands over tasks and goes to sleep. First asks clarifying questions (only if context is unclear, always with reasonable options), retells the night brief and gets the user's OK, then works autonomously with no questions — each task through /plan → /build → /review → /debug in an isolated night/ branch from main, local commits only, no push. Stops when the user's tasks are done and writes a morning report. Use when the user says "ночь" / "работаем ночью" / "night". Stop early with /night-stop.
---

# Skill: /night

ORCHESTRATOR. Adapted from `coordinator-yolo`. Two phases: **interactive** (user still
here) → **autonomous** (user asleep). Answer in caveman mode (full).

Read `.claude/agents/night.md` first — its rails are hard rules for the whole night.

## Invocation
`/night` — or the user says "ночь" / "работаем ночью" and lists tasks.

## Phase 1 — interactive (user still here)

1. **Collect tasks** — the user's list, verbatim. Nothing gets added that the user did not ask for.
2. **Preconditions** (any fails → tell the user, do not start the night):
   - `git status --short` empty (clean tree — the user's uncommitted work is never mixed in).
   - `main` exists.
   - Build + test command found (`package.json` test script, `pyproject.toml`, `go.mod`,
     `build.gradle*`, `Makefile test:` …). None → ask the user how to test, with options.
3. **Clarify** — only where a task's context is unclear. Context first: read
   `.memory-bank/` (incl. `decisions.md`), repo, recent commits, draft your best answer;
   ask only about the gaps. Each question = `AskUserQuestion` with 2–4 reasonable
   options, real and true to this project, recommended first; each option = concrete
   step + benefit + risk; real choice → include "nothing / leave as is". Context clear →
   no questions. Every settling answer → `.memory-bank/decisions.md`
   (`<YYYY-MM-DD> · context · choice · why`) — the night reads it instead of asking.
4. **Night brief** — short, numbered, plain:
   ```
   Ночью сделаю:
   1. <task> — готово когда: <criterion> — файлы/зона: <...>
   2. ...
   Порядок: <1 → 2 → ...>
   Не трогаю: <...>
   Ветка: night/<slug>-<ts> от main, без push
   Если задача не выходит: откат, запись в лог, следующая задача
   Утром: swarm-report/night-<date>.md
   ```
   Ask with `AskUserQuestion`: "Всё верно? Что изменить или добавить?" — options like
   "Да, уходи в ночь" / "Хочу изменить" / "Хочу добавить".
5. **User edits** → spawn the **skeptic** on the edited brief (`Task`, `general-purpose`):
   > Answer in caveman mode (full). Read `.claude/agents/skeptic.md` and follow it
   > exactly. Feature: night brief below + user edits: <verbatim>.

   Apply HIGH/MED fixes, show the brief again (step 4). Repeat until the user says OK.
6. **Save the brief** to `swarm-report/night-<date>-brief.md`. From here: no questions.

## Phase 2 — autonomous (user asleep)

7. **Branch** from main:
   ```bash
   SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   TS=$(date +%Y%m%d-%H%M)
   git checkout main && git checkout -b "night/$SLUG-$TS"
   ```
   Start the log `swarm-report/night-<date>-log.md` (branch, start time, task list).
8. **Tasks one after another, no pauses**, in the brief's order. Per task — full loop,
   following `.claude/agents/night.md`:
   `/plan` (skeptic stands in for the user) → `/build` → `/review` → `rework` / failing test →
   `/debug` → back to `/build`.
9. **Done** with the user's tasks → write the morning report (see `.claude/agents/night.md`),
   stop. Do not invent new tasks.

## Stop early
`/night-stop` — stops after the current step, writes the same morning report.
