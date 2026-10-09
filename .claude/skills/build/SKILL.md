---
name: build
description: Implement an already-approved plan from swarm-report/<slug>-plan.md. Routes each file to the exec agent that owns it (AGENTS.md registry), runs them in parallel per layer, checks their exec-contract returns and test results, writes an implementation report. Use AFTER /plan, never before.
when_to_use: "Invoke after the user approves a plan: «да, запускай», «ок, делай», «погнали», «запускай build». Never before swarm-report/<slug>-plan.md exists."
---

# Skill: /build

ORCHESTRATOR. You route work to executing agents by file scope. No code edits in the
main loop. No questions to the user mid-build (see "Questions" in `AGENTS.md`).

## Invocation
`/build <slug>`

## Steps
1. **Find the plan**: `swarm-report/<slug>-plan.md`. Missing → abort:
   "Run `/plan \"<feature>\"` first."
2. **Check Blockers** in the plan. Any unresolved → abort and name it: the user resolves it
   at the after-plan checkpoint, not here.
3. **Route by owner**: group the plan's affected files by their `owner` (exec agent from
   the "Executing agents" registry in `AGENTS.md`). A file still without an owner (the user
   chose `general-purpose` at the checkpoint) → `general-purpose`.
4. **Spawn the exec agents** — one `Agent` call each, in parallel when the feature spans
   several layers (single message, N calls, `subagent_type: <owner agent name>`). Prompt:
   > CAVEMAN MODE ACTIVE (full). Respond terse like smart caveman. All technical substance stay. Only fluff die.
   > Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms, code, paths, errors exact. Code, commits, PRs: write normal.
   > Plan: swarm-report/<slug>-plan.md. Your scope: <the files for this agent>.

   The SubagentStart hook injects the harness greeting + exec contract; the SubagentStop
   hook rejects a return without the contract YAML. Exec agents run on Sonnet 5.5 from their
   frontmatter; a `general-purpose` fallback gets `model: "sonnet"` in the call. For `general-purpose` add to the
   prompt: "Follow `.claude/harness/exec-contract.md` and return its YAML."
   If one agent's output changes a contract another needs (`cross_layer_notes`), pass that
   note into the dependent agent's prompt — or run the provider first, then the consumer.
5. **Verify**: read each return's `status` and `tests_result`. Any `blocked`, `fail` or
   `not_run` → do NOT claim success. Report the failures verbatim and stop; route to
   `/debug` (day: at the end checkpoint; night: per rails).
6. **Write** `swarm-report/<slug>-build.md`: per-agent changed files, test commands +
   real results, cross-layer notes, assumptions.
7. **Report** to user: status per scope + test results. Quote real output — no "done"
   without proof.
