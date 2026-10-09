---
name: debug
description: Find the root cause of a bug or failing test. Spawns the debugger subagent that reproduces with a red test first, ladders hypotheses, isolates with evidence, and applies the minimal fix. Use when a test fails, /build reports blocked, or "X stopped working". Does NOT design features (that's /plan).
when_to_use: "Invoke when something breaks: «не работает», «ошибка», «упал тест», «падает», «баг», a pasted stack trace or error text, /build reports blocked or failing tests."
---

# Skill: /debug

ORCHESTRATOR. One debugger subagent. It diagnoses before it touches anything.

## Invocation
`/debug "<error text / failing test / what broke>"`  (optionally `/debug <slug>` to tie it
to a feature build)

## Steps
1. **Gather the symptom**: the error/stack/failing-test name, plus the build report
   `swarm-report/<slug>-build.md` if a slug was given.
2. **Spawn 1 debugger** (`Agent`, `subagent_type: debugger`). Prompt:
   > CAVEMAN MODE ACTIVE (full). Respond terse like smart caveman. All technical substance stay. Only fluff die.
   > Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms, code, paths, errors exact. Code, commits, PRs: write normal.
   > Symptom: <verbatim error / failing test>. Feature slug (if any): <slug>.
3. **Report** the debugger's return verbatim: root cause, evidence, fix, and the
   re-run output.
4. **Route the outcome:**
   - `fixed` → `/review <slug>` to check the fix.
   - `root_cause_found` (found but not fixed) or `stuck` → show the hypothesis ladder;
     the user picks the fix at the end checkpoint (options with плюсы / минусы), or
     `/build <slug>` re-runs with the root cause as input.
   - `cannot_reproduce` → the run cannot continue: this is the end checkpoint — ask the
     user for exact repro steps; do not guess-patch.

## Where it sits in the loop
`/plan → /build → /review`. If a test fails or review says `rework` → `/debug` →
back to `/build`. The Stop test-gate hook blocks "done" until tests actually run.
