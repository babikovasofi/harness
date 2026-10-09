# Night rails

Hard rules for the autonomous phase of `/night`. Adapted from `coordinator-yolo`
(github.com/AlexGladkov/claude-code-agents). The user is asleep and CANNOT answer. You drive
the user's approved night brief task by task, in a sandbox, so the user wakes up to
progress, not a broken project.

This runs in the **main session**, never as a subagent: subagents cannot spawn subagents
by default, and every task needs planner, skeptic, exec agents, reviewer.

Tone: decisive on the work, paranoid on safety. Every decision logged with "why".

## Rails (break one = night failed)

1. **Night branch only.** All changes go to `night/<slug>-<ts>` cut from `main`, inside the
   night worktree. Never commit to `main` or any other branch. Never merge, never push the
   night branch, never force, never deploy, no destructive git (`reset --hard` on other
   branches, `branch -D`, `filter-branch`, …). Only exception: the end-of-night defrag pushes
   its own `memory-defrag/<YYYY-MM-DD>` branch and opens a PR. The `guard.sh` hook enforces
   this while `.claude/state/night.active` exists.
2. **No questions.** `AskUserQuestion` is FORBIDDEN. Decide from the brief + Memory Bank
   (`.memory-bank/decisions.md` — the user's past answers win); log why. Doubts go to the
   morning report — that is the end checkpoint.
3. **Only the user's tasks.** Exactly the tasks in the brief, in its order. Respect its
   "не трогаю". Tasks done → stop. Never invent new tasks.
4. **Validate before every commit.** Done = build passes + tests green + review `ship`. Red →
   roll back this task only:
   ```bash
   git restore --staged --worktree . && git clean -fd -e swarm-report/
   ```
   `swarm-report/` (brief, log, plans) survives the rollback. Log `❌ <reason>`, next task.
   Never leave a red tree. Never delete or weaken a test to get green.
5. **Memory Bank is read-only on the night branch.** After each task run the `/memory-bank`
   check; suggestions (importance ≥ 2) go to the log and the morning report, never into
   `.memory-bank/`. Only the end-of-night defrag edits it, on its own branch, via its PR.
6. **Commits.** English, Conventional Commits (`AGENTS.md` → "Commits, PRs, push").
   One commit = one task: `<type>(<scope>): <what>`, body `Night task #<n> from brief.`
   The log gets its own commit after every task outcome: `chore(night): log task <n> <result>`.
7. **Context is finite.** Long command output → redirect to a file, read the tail. After
   compaction or resume the SessionStart hook reminds you: re-read this file, the brief and
   the log before the next step. The log is the night's memory.

## Start of night (phase 2)

1. Write the marker (main checkout, so the hooks see it):
   ```bash
   mkdir -p "$CLAUDE_PROJECT_DIR/.claude/state"
   printf 'brief: swarm-report/night-<date>-brief.md\nlog: swarm-report/night-<date>-log.md\nworktree: <path>\nbranch: night/<slug>-<ts>\n' > "$CLAUDE_PROJECT_DIR/.claude/state/night.active"
   ```
2. **Worktree.** `EnterWorktree` (name `night-<ts>`) → the session moves into
   `.claude/worktrees/night-<ts>`, the user's checkout stays as it was. Then
   `git checkout -B night/<slug>-<ts> main`. Fallback — `EnterWorktree` unavailable, fails,
   or skills do not load inside it → `ExitWorktree`, then in the main checkout
   `git checkout main && git checkout -b night/<slug>-<ts>` (tree is clean, checked in phase 1).
   Log which path you took. Update `worktree:` in the marker and copy the marker into the
   worktree's `.claude/state/` too (gitignored) — hooks may resolve the project dir to
   either checkout.
3. Write `swarm-report/night-<date>-brief.md` (the approved brief) and start
   `swarm-report/night-<date>-log.md` (branch, worktree, start time, task list). Commit both:
   `chore(night): start night <ts>`.

## Per-task loop

Run the existing skills; where they would ask the user, apply the night rule instead.

1. **/plan** `"<task>"` — planner + skeptic. The skeptic stands in for user approval.
   - Skeptic HIGH you can fix from the brief / Memory Bank → fix, log why.
   - HIGH that needs a user decision, or `unowned_files` with no sensible owner →
     skip the task, log `⏭ skipped: <blocker>`.
2. **/build** `<slug>` — unowned file → `general-purpose` with the exec contract, log it.
3. **/review** `<slug>`:
   - `ship` → commit (rail 6), log ✅.
   - `rework` → `/build` again with the findings as input.
4. **/debug** — failing test / build blocked → `/debug`, then back to `/build`.
5. **Give up on a task** after 2 full `/build` retries (rework or debug) without green
   + `ship` → roll back (rail 4), log ❌ with the last finding, next task.

## End of night (also on `/night-stop`)

1. Commit the log on the night branch.
2. `/memory-bank-defrag` unattended (`.claude/skills/memory-bank-defrag/SKILL.md` →
   "Unattended runs"): `git switch -c memory-defrag/<YYYY-MM-DD> main`, commit with the
   `Memory-Defrag:` trailer, push that branch, open the PR, `git switch night/<slug>-<ts>`.
   Nothing changed → no-op, no branch, no PR. No remote / `gh` → commit locally, say so.
3. Write the morning report, commit it (`docs(night): morning report <date>`).
4. Remove the marker from both checkouts (main checkout and worktree `.claude/state/`).
5. `ExitWorktree` with keep — the worktree and the branch stay for the morning.

## Log — `swarm-report/night-<date>-log.md`

```markdown
# Night log: <slug>
Branch: night/<slug>-<ts> · worktree: <path> · start <timestamp>

## <timestamp> · Task <#>: <name>
Plan: swarm-report/<slug>-plan.md
Decisions: <what you decided without the user + why>
Files: <...>
Validation: build ✅ · tests ✅ · review ship
Commit: <hash | —>
Memory Bank suggestions: <MEMORY_SUGGESTION blocks, or none>
Result: ✅ done | ❌ rolled back (<reason>) | ⏭ skipped (<blocker>)
```

## Morning report — `swarm-report/night-<date>.md`

Human-facing: follow `.claude/skills/anti-ai-slop-writing/SKILL.md`
(+ `references/ru-checklist.md` if in Russian). Questions and doubts from the night live
here — this is the end checkpoint.
- Branch, worktree path, work window, tasks done / total.
- **Done**: commits (hash · task · criterion met).
- **Rolled back / skipped**: what and why.
- **Decisions made without you**: from the log, each with плюсы / минусы of the choice —
  the user checks these first.
- **Questions for you**: doubts that came up at night, each with reasonable options.
- **Memory Bank suggestions**: every `MEMORY_SUGGESTION` block from the night.
- **Memory Bank defrag**: PR link, or "no-op, nothing changed since last defrag".
- `git diff --stat main...<night-branch>`.
- **Morning recommendations**: what to review first, what looks ready to merge, what to
  drop; how to clean up: `git worktree remove .claude/worktrees/night-<ts>` after merging.

Leave the night branch and the worktree as is — no merge, no push, no delete. The user
decides in the morning. The defrag PR is never merged by you either.
