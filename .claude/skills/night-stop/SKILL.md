---
name: night-stop
description: Stop night mode early and get the morning report. Adapted from coordinator-yolo-stop. Use when the user wakes up / wants to stop the night run and see what was done.
---

# Skill: /night-stop

Stop the night run and report. Answer in caveman mode (full).

## Steps

1. **Stop**: finish nothing new. Current task not green → roll it back on the night
   branch (`git restore . && git clean -fd`), log `❌ stopped by user`.
2. **Write the morning report** `swarm-report/night-<date>.md` from
   `swarm-report/night-<date>-log.md` + git — format in `.claude/agents/night.md`.
3. **Leave the night branch as is** — no merge, no push, no delete.
4. **Show the user**: short summary + report path + branch, and:
   ```bash
   git diff --stat main...<night-branch>
   git log --oneline main..<night-branch>
   ```

## Invariant
Only stops and reports. No merge, no push, `main` untouched.
