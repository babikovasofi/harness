---
name: day
description: Day mode (default) — the user stays in the loop but does not have to babysit. Questions only at three checkpoints — start, after the plan, end — never mid-work. Runs /plan → /build → /review → /debug; before /build retells the plan as short numbered points and asks "всё устраивает?"; user edits go back through the skeptic. Every proposal shows плюсы / минусы. Use when the user says "день" / "day", or names no mode.
when_to_use: "Default for every task with no mode word: «сделай», «добавь», «исправь», «переделай», «день», «работаем днём». Invoke it yourself; the user never needs to type /day."
---

# Skill: /day

ORCHESTRATOR, main session. Normal loop, user always in the know, but never waiting at the
screen for a question that pops up halfway through.

## Invocation
`/day "<task>"` — or the user just says "день" and gives tasks. No mode named → day.

## Checkpoints — the only moments with questions

| # | When | What is asked |
|---|------|---------------|
| 1 | **Start**, before `/plan` | Everything unclear about the task (context first, then the gaps) |
| 2 | **After plan**, before `/build` | Retold plan → "всё устраивает?" + plan Blockers |
| 3 | **End**, after `/review` (or when the run cannot go on) | Doubts collected on the way, rework decisions, Memory Bank suggestions |

Between checkpoints: no `AskUserQuestion`. A doubt mid-work → take the safest reasonable
option, note it ("решил сам: X, потому что Y; плюсы / минусы"), bring it to checkpoint 3.

## Steps

1. **Checkpoint 1 — start.** Read `.memory-bank/` (incl. `decisions.md`), the repo, recent
   commits; draft your best understanding; ask one form about the real gaps only. Clear →
   no questions.
2. **Plan**: `/plan "<task>"` (planner + skeptic → `swarm-report/<slug>-plan.md`).
   Trivial change (typo, one obvious line, rename in one file, a config value) → no
   `/plan`, no Opus: say in one line what you will change and do it; Verify / lint hooks and
   the end checkpoint still apply.
3. **Checkpoint 2 — retell before /build**, short, plain, numbered:
   ```
   План: <feature>
   1. <what we do> — <files/area> — <exec agent>
   2. ...
   Готово когда: <acceptance criteria, 1 line each>
   Не делаем: <out of scope>
   Риски/блокеры: <skeptic HIGH, unowned files, or "нет">
   ```
   Then one `AskUserQuestion`: "Всё устраивает?" — options "Да, запускай build" /
   "Хочу изменить" / "Хочу добавить" (+ one question per Blocker, options with плюсы /
   минусы).
4. **User edits** (anything the user writes about the plan):
   - Spawn the `skeptic` subagent on the edited plan:
     > CAVEMAN MODE ACTIVE (full). Respond terse like smart caveman. All technical substance stay. Only fluff die.
     > Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms, code, paths, errors exact. Code, commits, PRs: write normal.
     > Plan: swarm-report/<slug>-plan.md. User edits: <verbatim>.
   - Apply HIGH/MED fixes, update `swarm-report/<slug>-plan.md`, list unresolved under
     Blockers.
   - Back to step 3 (retell + ask). Repeat until the user says "ок" / "да".
5. **Build**: only after explicit OK → `/build <slug>`. No questions from here to step 7.
6. **Review**: `/review <slug>`; failing tests / `blocked` / `rework` → `/debug` → `/build`
   again, up to 2 rounds without asking (same cap as the night).
7. **Checkpoint 3 — end.** Short numbered summary: what was done, review verdict, test
   output tail, decisions taken alone (with плюсы / минусы), open questions. Ask them in
   one form, plus the Memory Bank Steward suggestions.

## Rules
- Never start `/build` without the user's explicit OK on the latest retold plan.
- Retell = short. If it does not fit ~10 lines, the plan is too big — say so.
- Question format: `AGENTS.md` → "Questions".
