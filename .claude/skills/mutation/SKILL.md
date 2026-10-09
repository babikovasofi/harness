---
name: mutation
description: Check that the tests really test something. Mutates the changed code lines one operator at a time (+ → -, == → !=, >= → >, and → or, True → False …), runs the tests on every mutant and reports which mutants survive — a surviving mutant is a bug the tests would miss. Runs inside /review after every build; survivors become findings and new test cases.
argument-hint: "[slug]  (optional: tie the report to a feature)"
when_to_use: "Runs automatically in /review. Also when the user says «проверь тесты», «тесты что-то проверяют?», «мутационное тестирование», «mutation testing», «насколько хороши тесты»."
---

# Skill: /mutation

Small mutation-testing harness. Script: `.claude/scripts/mutate.py`; limits in
`.claude/harness/quality.json` → `mutation` (`max_mutants`, `min_score`, `timeout_sec`).

## Steps

1. **Real tool first.** The project already has a mutation tool configured (`mutmut` in
   `pyproject.toml`, Stryker `stryker.conf.*`, `go-mutesting`, PIT in Gradle/Maven) → run it
   on the changed files instead, same report shape. Otherwise use the script.
2. **Test command**: `verify.command` from `quality.json`, else the one the Verify hook
   detects (pytest / go test / npm test / gradlew test / make test). No test command at all
   → skip with one line ("no tests to mutate against — add a test command"), never fail the
   review on it.
3. **Base** = what this review covers. Uncommitted code changes exist (normal: day before
   the commit, night before the task's commit) → `--base HEAD`, only the current task.
   Otherwise the branch point: `--base "$(git merge-base HEAD main)"`.
   **Run**:
   ```bash
   python3 .claude/scripts/mutate.py --test-cmd "<cmd>" --base <base> \
     --max <max_mutants> --timeout <timeout_sec> --min-score <min_score> \
     --report swarm-report/<slug>-mutation.md
   ```
   - Exit 2 = setup problem: tests red before mutating (→ `/debug`, not a mutation result)
     or the base ref is missing (on `master` use `--base master`; to mutate only
     uncommitted work use `--base HEAD`).
   - Run it from the checkout that holds the change (at night: inside the worktree).
   - The script mutates only changed, non-test code lines and restores every file; a crash
     leftover is restored on the next run.
4. **Read the report.** Every survivor = one missing test case: "`<file>:<line>` `>= → >`
   survives" means no test pins the boundary. Turn each survivor into a test case in the
   plan format (`given / when / then`, `kills: <file>:<line> <op>`).
5. **Verdict**: score ≥ `min_score` → pass. Below → `rework`: the survivors' test cases go
   back to `/build` for the exec agent (Sonnet) to write. Never "fix" a survivor by
   changing the code to dodge the mutant.

## Rules
- Do not run on the harness template repo (no project code there).
- Generated code, migrations, vendored files → not mutated (`lint.ignore` globs are a good
  hint; pass `--files` to narrow the run).
- Equivalent mutants (the change cannot alter behaviour, e.g. `x >= 0` on a value that is
  never 0) → mark them as such in the report instead of writing a pointless test.
