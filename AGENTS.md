# Mini Dev-Loop Harness

A drop-in `.claude/` layout that gives any Claude Code / Codex project a deterministic
development loop: **/plan → /build → /review → /debug**.

It is *files*, not a CLI. There is no `harness do "build X"`. After you copy `.claude/`
into your project, you use your normal agent CLI; the harness activates through skills
and agents.

## The loop

1. `/plan "<feature>"` — design before code. planner + skeptic read your Memory Bank,
   argue, and write a plan to `swarm-report/`.
2. `/build <slug>` — the executing agents whose file scope the feature touches implement
   the approved plan and run the tests. Multi-layer feature → several exec agents in
   parallel.
3. `/review <slug>` — the reviewer checks the diff against the plan and reports ship/rework.
4. `/debug "<error>"` — when a test fails, a build is blocked, or something breaks: the
   debugger reproduces, ladders hypotheses, isolates on evidence, applies the minimal fix.

Feature broke on test or review said `rework` → `/debug` → back to `/build`. The **Stop
test-gate hook** blocks "done" until the project's tests actually run and their output is
cited — testing after every feature is enforced, not optional.

## Modes: day and night

Two work modes. Pick by the user's words:

- **"день"** / **"day"** → `/day` (`.claude/skills/day/SKILL.md`).
- **"ночь"** / **"работаем ночью"** / **"night"** → `/night` (`.claude/skills/night/SKILL.md`).
- Neither said → **day** is the default.

| | Day | Night |
|---|---|---|
| Questions | Any time a doubt appears — always as a form with real options | Only before going autonomous; none after |
| Before `/build` | Short numbered plan → "всё устраивает?" | Short numbered night brief → "всё верно? что изменить/добавить?" before going autonomous |
| User edits the plan | Edits go through skeptic, plan re-shown, until "ок" | Same |
| Loop | `/plan → /build → /review → /debug`, user in the loop | Same loop per task, skeptic stands in for the user |
| Git | Current branch | Own branch `night/<slug>-<ts>` from `main`, local commits, no push |
| End | — | Report `swarm-report/night-<date>.md`; `/night-stop` stops early |

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
  Push only after an explicit yes. Never force-push without a separate explicit yes.

## Agents

### Consilium (plan + review + debug — diagnose, don't bulk-edit)
| Role          | Agent                             | Used by          |
|---------------|-----------------------------------|------------------|
| planner       | `.claude/agents/planner.md`       | `/plan`          |
| skeptic       | `.claude/agents/skeptic.md`       | `/plan`          |
| reviewer      | `.claude/agents/reviewer.md`      | `/review`        |
| debugger      | `.claude/agents/debugger.md`      | `/debug`         |
| night         | `.claude/agents/night.md`         | `/night`         |

### Executing (write code — matched by file scope)
`/build` maps each plan task's affected files to an exec agent. A feature that touches
several layers runs several exec agents in parallel.

**Match order: stack-specific first, generic fallback last.** The specific agents carry
2026 best-practice rules for their stack; the generic ones catch anything not covered.
Confirm the actual stack from the repo (`package.json`, `pubspec.yaml`, `pyproject.toml`,
`*.xcodeproj`, `build.gradle.kts`, `*.tf`) before picking.

**Stack-specific:**
| Agent                              | Scope (signal files / globs)                              |
|------------------------------------|-----------------------------------------------------------|
| `.claude/agents/react-ts.md`       | `**/*.{tsx,jsx}` + React in `package.json`                |
| `.claude/agents/node-ts.md`        | server `**/*.ts` + `package.json` (Fastify/Nest/Hono, no React) |
| `.claude/agents/python-fastapi.md` | `**/*.py`, `pyproject.toml` (FastAPI)                     |
| `.claude/agents/flutter.md`        | `pubspec.yaml`, `**/*.dart`                               |
| `.claude/agents/ios.md`            | `**/*.swift`, `*.xcodeproj`, `Package.swift`             |
| `.claude/agents/android.md`        | `**/*.kt`, `build.gradle.kts`, `libs.versions.toml`      |
| `.claude/agents/terraform-yandex.md` | `**/*.tf`, `.terraform.lock.hcl`                        |

**Generic fallback (stacks not covered above — e.g. Vue/Svelte, Go/Ruby, plain infra):**
| Agent                        | Scope                                                              |
|------------------------------|-------------------------------------------------------------------|
| `.claude/agents/frontend.md` | `frontend/**`, `web/**`, `ui/**`, `**/*.{vue,svelte,css,scss}`     |
| `.claude/agents/backend.md`  | `backend/**`, `api/**`, `server/**`, `**/*.{go,rb,java}`           |
| `.claude/agents/devops.md`   | `Dockerfile`, `docker-compose*`, `.github/**`, `k8s/**`, `Makefile` |
| `.claude/agents/mobile.md`   | other mobile not matched above                                    |

No scope matches → ask the user which exec agent should own the change. Edit these globs to
fit each project's real layout.

## Working agreement (every agent respects)

- **Accuracy > speed.** Verify before claiming done. Tests pass ≠ feature works.
- **Read the Memory Bank first.** `.memory-bank/index.md` is the source of truth for what
  the project is. Missing → say so, do not invent project facts.
- **Disagree loudly.** Request wrong, scope bloated, plan flawed → say it, offer one
  alternative. Do not play along.
- **Stay in your scope.** An exec agent touches only its layer. Cross-layer impact →
  note it in the return for the sibling agent, do not reach across.
- **Edit > Write.** Change existing files; add new ones only when the plan calls for them.
- **No comments that narrate code.** Only *why* comments for a non-obvious invariant.
- **Security by default.** No injection, no hardcoded secrets. Validate external input at
  the boundary.
- **Ask before risky actions:** deleting files/branches, force push, dropping deps,
  anything visible outside the repo.
- **Questions: to the point, with options.** Ask only what changes the next step and
  cannot be found in the repo / Memory Bank. Always as a form (`AskUserQuestion`) with
  2–4 reasonable options — real, true to this project, never invented, no filler choices.
  - **Context first, then questions.** Before asking, read `.memory-bank/` (incl.
    `decisions.md`), `AGENTS.md`, `README*`, manifests, recent commits; draft your best
    answer — then ask only about the gaps. Options come from what you read.
  - **Each option = concrete step + benefit + risk** (in its description). Where it is a
    real choice, include a "nothing / leave as is" option.
  - **Decision log.** Every user answer that settles something goes to
    `.memory-bank/decisions.md`: `<YYYY-MM-DD> · context · choice · why`. Create the file on
    first use. Already decided there → do not ask again, follow it.
- **Human-facing text → anti-AI-slop.** Whenever you write prose a person will read
  outside this chat, first read `.claude/skills/anti-ai-slop-writing/SKILL.md` +
  `references/banned-words.md`, and for Russian text also `references/ru-checklist.md`.
  Applies to: commit bodies, PR titles/bodies, README / docs, reports the user reads
  (`swarm-report/night-<date>.md`, review/build summaries), product copy (bot messages,
  UI strings, end-user error texts). Does not apply to: chat replies and agent returns
  (caveman), code, YAML agent outputs, logs.
- **Caveman always.** Every agent and every subagent answers in `/caveman` (full): drop
  articles / filler / pleasantries / hedging, fragments OK, keep every technical fact
  exact. Subagents do not inherit this file — each `.claude/agents/*.md` repeats the rule,
  and every spawn prompt starts with "Answer in caveman mode (full)". Code, commits, PRs:
  written normally.
