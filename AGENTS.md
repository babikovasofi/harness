# Mini Dev-Loop Harness

A drop-in `.claude/` layout that gives any Claude Code / Codex project a deterministic
development loop: **/plan → /build → /review → /debug**.

It is *files*, not a CLI. There is no `harness do "build X"`. Install it into a project with
`/setup` (run from the harness repo), then use your normal agent CLI; the harness activates
through skills, subagents and hooks.

## The loop

1. `/plan "<feature>"` — design before code. planner + skeptic read your Memory Bank,
   argue, and write a plan to `swarm-report/`, every file mapped to its exec agent.
2. `/build <slug>` — the executing agents that own the touched files implement the approved
   plan and run the tests. Multi-layer feature → several exec agents in parallel.
3. `/review <slug>` — the reviewer checks the diff against the plan and reports ship/rework.
4. `/debug "<error>"` — when a test fails, a build is blocked, or something breaks: the
   debugger reproduces, ladders hypotheses, isolates on evidence, applies the minimal fix.

Feature broke on test or review said `rework` → `/debug` → back to `/build`. The **Stop
test-gate hook** blocks "done" until the project's tests actually run and their output is
cited — testing after every feature is enforced, not optional.

Around the loop:
- `/research "<topic>"` — deep Tavily search, numbered findings with source links, report in
  `swarm-report/research-<slug>-<date>.md` that `/plan` can read. Tavily key lives only in
  `.env` (see `.env.example`), never in chat.
- `/new-agent <stack>` — onboard a stack-specific executing agent (see "Agents").
- `/memory-bank` (Steward), `/memory-bank-defrag` — keep `.memory-bank/` current.
- `/transcribe <file>` — local meeting transcript with speaker labels.
- `/anti-ai-slop-writing` — rules for any text a human reads outside the chat.

## Modes: day and night

Two work modes. Pick by the user's words:

- **"день"** / **"day"** → `/day` (`.claude/skills/day/SKILL.md`).
- **"ночь"** / **"работаем ночью"** / **"night"** → `/night` (`.claude/skills/night/SKILL.md`).
- Neither said → **day** is the default.

| | Day | Night |
|---|---|---|
| Questions | Only at checkpoints: start, after plan, end | All before going autonomous; leftovers in the morning report |
| Before `/build` | Short numbered plan → "всё устраивает?" | Short numbered night brief → "всё верно? что изменить/добавить?" |
| User edits the plan | Edits go through skeptic, plan re-shown, until "ок" | Same |
| Loop | `/plan → /build → /review → /debug` | Same loop per task, skeptic stands in for the user |
| Git | Current branch | Worktree `.claude/worktrees/night-<ts>`, branch `night/<slug>-<ts>` from `main`, local commits, no push (except the defrag PR) |
| End | Summary + questions (checkpoint 3) | `/memory-bank-defrag` → PR, then `swarm-report/night-<date>.md`; `/night-stop` stops early |

## Commits, PRs, push

- **English only** — commit messages, PR titles and bodies, branch names.
- **Conventional Commits** (https://www.conventionalcommits.org):
  `<type>(<optional scope>): <description>`
  - types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
    `chore`, `revert`.
  - description: imperative, lowercase start, no trailing period, ≤72 chars for the line.
  - body (optional): blank line after the subject, explains *why*.
  - breaking change: `!` after type/scope (`feat(api)!: ...`) + `BREAKING CHANGE:` footer.
- **PR title** = a Conventional Commit subject. PR body: what changed, why, how tested.
- Commit bodies and PR text follow `/anti-ai-slop-writing` (see Working agreement).
- **Before every push** (incl. opening a PR, which pushes the branch) — show a short,
  clear list and ask right away, in the same message:
  ```
  Push: <branch> → <remote>/<branch>
  Commits:
  - <hash> <subject>
  - ...
  Files: <N changed, +X / −Y>
  ```
  Then `AskUserQuestion`: "Пушить?" — options "Да, пушить" / "Нет, не пушить".
  Push only after an explicit yes. Force-push is blocked by the `guard.sh` hook — the user
  runs it themselves after a separate yes.
- **One exception:** `/memory-bank-defrag` run unattended at the end of `/night` may push
  its own `memory-defrag/<YYYY-MM-DD>` branch and open a PR without asking. Never `main`,
  never another branch, never force. The PR link goes into the morning report.

## Agents

All agents are real Claude Code subagents (`.claude/agents/*.md` with frontmatter), spawned
with `subagent_type: <name>`. Orchestration (`/plan`, `/build`, `/day`, `/night`) always
runs in the main session: subagents cannot spawn subagents by default.

### Consilium (plan + review + debug — diagnose, don't bulk-edit)
| Agent    | Tools                         | Used by                   |
|----------|-------------------------------|---------------------------|
| planner  | Read, Grep, Glob              | `/plan`                   |
| skeptic  | Read, Grep, Glob              | `/plan`, `/day`, `/night` |
| reviewer | Read, Grep, Glob, Bash        | `/review`                 |
| debugger | all                           | `/debug`                  |

### Executing agents (write code — matched by file scope)
`/plan` maps every affected file to the agent whose scope covers it; `/build` spawns those
agents, in parallel when a feature spans several layers. Add agents only with `/new-agent`
— it fills the template, validates it and adds the row here.

| Agent | Scope (globs) | Test command | Signal files |
|-------|---------------|--------------|--------------|
| _none yet — add with `/new-agent <stack>`_ | | | |

A file no agent covers → `/plan` lists it under Blockers; the user picks `/new-agent` or
`general-purpose` at the after-plan checkpoint.

### Onboarding — how the harness greets a subagent
- **SubagentStart hook** (`.claude/hooks/subagent-greeting.sh`) injects
  `.claude/harness/greeting.md` into every subagent before its first prompt: caveman, Memory
  Bank, scope, no questions, no secrets, test ratchet, anti-slop. Exec agents (marker
  `<!-- harness:exec -->`) also get `.claude/harness/exec-contract.md`.
- **SubagentStop hook** (`.claude/hooks/exec-return-check.sh`) does not let an exec agent
  finish without the contract YAML (`status`, `tests_result`, …).
- Template: `.claude/harness/exec-agent-template.md`. Spawn prompts stay short — the hook
  carries the shared rules.

## Hooks (`.claude/settings.json`)

| Event | Script | Does |
|-------|--------|------|
| SessionStart | `session-context.sh` | Puts `.memory-bank/index.md` into context; during a night run reminds to re-read brief, log, rails after compaction |
| SubagentStart | `subagent-greeting.sh` | Greeting + exec contract (see Onboarding) |
| SubagentStop | `exec-return-check.sh` | Exec agents must return the contract YAML |
| PreToolUse (Bash) | `guard.sh` | Blocks commands touching `.env`, printing the Tavily key, any force-push; at night any push except `memory-defrag/*` and PR merges |
| Stop | `test-gate.sh` | Code edited but no tests run → not done |

Plus `permissions.deny: Read(.env)` so file tools cannot read secrets.

## Working agreement (every agent respects)

- **Accuracy > speed.** Verify before claiming done. Tests pass ≠ feature works.
- **Read the Memory Bank first.** `.memory-bank/index.md` is the source of truth for what
  the project is (the SessionStart hook loads it). Missing → say so, do not invent facts.
- **Disagree loudly.** Request wrong, scope bloated, plan flawed → say it, offer one
  alternative with плюсы / минусы. Do not play along.
- **Stay in your scope.** An exec agent touches only its layer. Cross-layer impact →
  note it in the return for the sibling agent, do not reach across.
- **Edit > Write.** Change existing files; add new ones only when the plan calls for them.
- **No comments that narrate code.** Only *why* comments for a non-obvious invariant.
- **Test ratchet.** Never delete, skip, or weaken a test to make it pass. Red test → fix
  the code, or report it red.
- **Security by default.** No injection, no hardcoded secrets. Validate external input at
  the boundary. Never read `.env` or print keys (hook + permissions enforce it).
- **Ask before risky actions:** deleting files/branches, force push, dropping deps,
  anything visible outside the repo.
- **Proposals show плюсы / минусы.** Any proposal — in chat or as a question option — lists
  its плюсы and минусы when it has them. One-sided proposals are not allowed.
- **Questions: only at checkpoints, to the point, with options.**
  - **When:** at the **start** (before planning), **after the plan** (before `/build`), or
    at the **end** (after review / report). Never in the middle of work — the user must not
    have to sit at the screen waiting. A doubt mid-work → take the safest reasonable
    option, note it, bring it to the next checkpoint. Work cannot continue at all → stop
    the run; that stop is the end checkpoint.
  - **What:** only what changes the next step and cannot be found in the repo / Memory
    Bank. Always one form (`AskUserQuestion`) with 2–4 reasonable options — real, true to
    this project, never invented, no filler choices, recommended first.
  - **Context first, then questions.** Before asking, read `.memory-bank/` (incl.
    `decisions.md`), `AGENTS.md`, `README*`, manifests, recent commits; draft your best
    answer — then ask only about the gaps. Options come from what you read.
  - **Each option = concrete step + плюсы + минусы** (in its description). Where it is a
    real choice, include a "nothing / leave as is" option.
  - **Decision log.** Every user answer that settles something goes to
    `.memory-bank/decisions.md`: `<YYYY-MM-DD> · context · choice · why`. Create the file on
    first use. Already decided there → do not ask again, follow it.
- **Memory Bank Steward after every reply.** The main agent ends every reply with the
  `/memory-bank` check (`.claude/skills/memory-bank/SKILL.md`): importance ≥ 2 →
  `MEMORY_SUGGESTION` block; otherwise one line `NO_MEMORY_UPDATE` with the reason. The
  "Применить?" question goes into the next checkpoint form, not mid-work. Apply only after
  yes. Never write secrets. Night: do not touch `.memory-bank/`, suggestions go into the
  morning report.
- **Human-facing text → anti-AI-slop.** Whenever you write prose a person will read
  outside this chat, first read `.claude/skills/anti-ai-slop-writing/SKILL.md` +
  `references/banned-words.md`, and for Russian text also `references/ru-checklist.md`.
  Applies to: commit bodies, PR titles/bodies, README / docs, reports the user reads
  (`swarm-report/night-<date>.md`, review/build summaries), product copy (bot messages,
  UI strings, end-user error texts). Does not apply to: chat replies and agent returns
  (caveman), code, YAML agent outputs, logs.
- **Caveman always.** Every agent and every subagent answers in `/caveman` (full): drop
  articles / filler / pleasantries / hedging, fragments OK, keep every technical fact
  exact. Subagents get the rule from the SubagentStart greeting. Code, commits, PRs:
  written normally.
- **Harness template stays clean.** In the harness source repo (it has
  `.claude/skills/setup/`) never write project facts to `.memory-bank/`, decisions to
  `decisions.md`, or reports to `swarm-report/` — it must stay an empty template, ready
  for the next project. Steward there → `NO_MEMORY_UPDATE` (harness template).
