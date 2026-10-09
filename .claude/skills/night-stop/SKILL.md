---
name: night-stop
description: Stop night mode early and get the morning report. Adapted from coordinator-yolo-stop. Use when the user wakes up / wants to stop the night run and see what was done (interrupt the run with Esc first, then /night-stop).
---

# Skill: /night-stop

Stop the night run and report. Rules: `.claude/skills/night/rails.md`.

## Steps

1. **Stop**: start nothing new. Current task not green → roll it back on the night branch
   (rails → rail 4: `git restore --staged --worktree . && git clean -fd -e swarm-report/`),
   log `❌ stopped by user`, commit the log.
2. **End of night** — rails → "End of night": defrag (own branch + PR), morning report,
   marker removed from both checkouts, `ExitWorktree` keep.
3. **Show the user**: short summary + report path + branch + worktree path, and:
   ```bash
   git diff --stat main...<night-branch>
   git log --oneline main..<night-branch>
   ```
   Questions from the night are in the report — this is the end checkpoint, ask them now
   (`AskUserQuestion`, options with плюсы / минусы).

## Invariant
Only stops, runs defrag and reports. No merge, `main` untouched; the only push is the
defrag branch.
