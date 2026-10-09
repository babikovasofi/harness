---
name: review
description: Review a finished change against its plan. Spawns the reviewer subagent (read-only tools), reports ship/rework with severity-tagged findings. Use AFTER /build.
when_to_use: "Invoke after every /build, and when the user says «проверь код», «ревью», «посмотри изменения», «готово к мержу?», «review»."
---

# Skill: /review

ORCHESTRATOR. One reviewer subagent. Read-only — the reviewer does not fix.

## Invocation
`/review <slug>`

## Steps
1. **Gather**: plan `swarm-report/<slug>-plan.md` + build report `swarm-report/<slug>-build.md`
   + the diff (`git diff` for staged + unstaged, or vs the branch point).
2. **Spawn 1 reviewer** (`Agent`, `subagent_type: reviewer`). Prompt:
   > CAVEMAN MODE ACTIVE (full). Respond terse like smart caveman. All technical substance stay. Only fluff die.
   > Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms, code, paths, errors exact. Code, commits, PRs: write normal.
   > Plan: swarm-report/<slug>-plan.md
   > Diff below:
   > <paste git diff here>

   Paste the diff INTO the prompt — the reviewer must not re-read the whole repo.
3. **Mutation check** — run `/mutation <slug>` on the changed code. Every surviving
   mutant is added as a finding: `<file>:<line> — MED: tests miss <op>. Add test case
   <given/when/then>.` Score below `min_score` (`.claude/harness/quality.json`) → verdict
   `rework` even if the reviewer said `ship`.
4. **Report** the reviewer's verdict + findings + mutation score verbatim.
5. If `verdict: rework` — the findings ARE the input to a `/build <slug>` retry. Do not
   auto-fix here; in day mode the user decides at the end checkpoint (options with
   плюсы / минусы), at night the rails decide.
