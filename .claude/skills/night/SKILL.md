---
name: night
description: Night mode — the user hands over tasks and goes to sleep. All questions come first (clarify with reasonable options, permission mode, then the night brief and the user's OK); after that it works autonomously with no questions — each task through /plan → /build → /review → /debug in a night/ branch inside its own git worktree, local commits only. At the end runs /memory-bank-defrag (its own branch + PR, the only push) and writes a morning report with everything it decided alone. Use when the user says "ночь" / "работаем ночью" / "night". Stop early with /night-stop.
when_to_use: "Invoke when the user says «ночь», «работаем ночью», «оставлю на ночь», «сделай пока я сплю», «night»."
---

# Skill: /night

ORCHESTRATOR, main session. Adapted from `coordinator-yolo`. Two phases: **interactive**
(user still here — the only time questions are allowed) → **autonomous** (user asleep).

Hard rules for phase 2: `.claude/skills/night/rails.md`. Read it before phase 2.

## Invocation
`/night` — or the user says "ночь" / "работаем ночью" and lists tasks.

## Phase 1 — interactive (start checkpoint: every question happens here)

1. **Collect tasks** — the user's list, verbatim. Nothing gets added that the user did not
   ask for.
2. **Preconditions** (fails → tell the user, do not start the night):
   - `git status --short` empty (the user's uncommitted work is never mixed in).
   - `main` exists.
   - Build + test command found (`package.json` test script, `pyproject.toml`, `go.mod`,
     `build.gradle*`, `Makefile test:` …). None → ask how to test, with options.
   - Every file area the tasks touch has an exec agent in the `AGENTS.md` registry. Missing
     → offer `/new-agent` now, or `general-purpose` for the night (плюсы / минусы each).
   - `git remote` + `gh auth status` — needed for the defrag PR. Missing → night still
     runs, defrag only commits locally; tell the user.
3. **Clarify** — only where a task's context is unclear, following the question rules in
   `AGENTS.md` (context first, 2–4 reasonable options, each with плюсы / минусы, "nothing /
   leave as is" where it is a real choice). Context clear → no questions. Every settling
   answer → `.memory-bank/decisions.md` — the night reads it instead of asking.
4. **Permission mode.** Ask once (`AskUserQuestion`): how the session runs tonight —
   options: "Auto mode" (Recommended: classifier blocks dangerous actions, nothing waits
   for a click) / "bypassPermissions in a sandbox or container" / "Default mode — I accept
   the night may stall on a prompt". Плюсы / минусы in each description.
5. **Night brief** — short, numbered, plain:
   ```
   Ночью сделаю:
   1. <task> — готово когда: <criterion> — файлы/зона: <...> — агент: <exec agent>
   2. ...
   Порядок: <1 → 2 → ...>
   Не трогаю: <...>
   Где: worktree .claude/worktrees/night-<ts>, ветка night/<slug>-<ts> от main, без push
   В конце: чистка Memory Bank → отдельная ветка memory-defrag/<date> + PR (единственный push)
   Если задача не выходит: откат, запись в лог, следующая задача
   Утром: swarm-report/night-<date>.md — что сделано, что решил сам, вопросы к тебе
   ```
   Ask (`AskUserQuestion`): "Всё верно? Что изменить или добавить?" — options
   "Да, уходи в ночь" / "Хочу изменить" / "Хочу добавить".
6. **User edits** → spawn the `skeptic` subagent on the edited brief:
   > Night brief below + user edits: <verbatim>. Critique it as a plan.

   Apply HIGH/MED fixes, show the brief again (step 5). Repeat until the user says OK.
   From the OK on: no questions until the morning report.

## Phase 2 — autonomous (user asleep)

7. **Start of night** — `rails.md` → "Start of night": marker, worktree (with fallback),
   brief + log committed.
8. **Tasks one after another, no pauses**, in the brief's order — `rails.md` →
   "Per-task loop".
9. **Done** with the user's tasks → `rails.md` → "End of night": defrag PR, morning report,
   marker removed, worktree kept. Do not invent new tasks.

## Stop early
`/night-stop` — interrupt the run (Esc), then type `/night-stop`: it finishes the current
step safely, runs the end of night, writes the same morning report.
