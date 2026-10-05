---
name: day
description: Day mode (default) — the user is at the keyboard and stays in the loop. Runs /plan → /build → /review → /debug, but before /build retells the plan as short numbered points and asks "всё устраивает?"; user edits go back through the skeptic. Any doubt → a question form with real options. Use when the user says "день" / "day", or names no mode.
---

# Skill: /day

ORCHESTRATOR. Normal loop, user always in the know. Answer in caveman mode (full).

## Invocation
`/day "<task>"` — or the user just says "день" and gives tasks. No mode named → day.

## Steps

1. **Doubt → ask.** At any step, if something is unclear or has several reasonable
   answers, ask with `AskUserQuestion` (see **Questions** below). Do not guess silently.
2. **Plan**: run `/plan "<task>"` (planner + skeptic → `swarm-report/<slug>-plan.md`).
3. **Retell before /build** — short, plain, numbered points, no jargon dump:
   ```
   План: <feature>
   1. <what we do> — <files/area>
   2. ...
   Готово когда: <acceptance criteria, 1 line each>
   Не делаем: <out of scope>
   Риски/блокеры: <skeptic HIGH, or "нет">
   ```
   Then ask with `AskUserQuestion`: "Всё устраивает?" — options like
   "Да, запускай build" / "Хочу изменить" / "Хочу добавить".
4. **User edits** (anything the user writes about the plan):
   - Spawn the **skeptic** on the edited plan (`Task`, `general-purpose`):
     > Answer in caveman mode (full). Read `.claude/agents/skeptic.md` and follow it
     > exactly. Plan: swarm-report/<slug>-plan.md. User edits: <verbatim>.
   - Apply HIGH/MED fixes, update `swarm-report/<slug>-plan.md`, list unresolved under
     Blockers.
   - Go back to step 3 (retell + ask). Repeat until the user says "ок" / "да".
5. **Build**: only after explicit OK → `/build <slug>`.
6. **Review**: `/review <slug>`. Short numbered summary of the verdict + findings.
   `rework` → ask (with options) whether to `/build` again with the findings.
7. **Debug**: test fails / build blocked → `/debug`, then back to `/build`.

## Questions
- Only to the point: ask only what changes what you do next. No questions for the sake of
  asking, nothing answerable from the repo / Memory Bank / plan.
- Always a form (`AskUserQuestion`) with 2–4 reasonable options: each real, true to this
  project (checked against the repo / Memory Bank, never invented), and one the user could
  actually pick. No filler or joke options. Recommended one first.
- Context first: read `.memory-bank/` (incl. `decisions.md`), repo, recent commits, draft
  your best answer — then ask only about the gaps.
- Each option: concrete step + benefit + risk in its description. Real choice → include
  a "nothing / leave as is" option.
- Every settling answer → `.memory-bank/decisions.md` (`<YYYY-MM-DD> · context · choice ·
  why`). Already decided there → follow it, do not ask again.

## Rules
- Never start `/build` without the user's explicit OK on the latest retold plan.
- Retell = short. If it does not fit ~10 lines, the plan is too big — say so.
