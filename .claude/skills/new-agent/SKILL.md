---
name: new-agent
description: Onboard a new stack-specific executing agent into the harness. Asks (once, at the start) for stack, file scope and test command, creates .claude/agents/<name>.md from the template with the exec marker, validates its frontmatter and registers it in the "Executing agents" table of AGENTS.md so /plan and /build route files to it. Use when the user says "добавь агента под <stack>", "new agent", or /plan reports unowned files.
argument-hint: "<stack, e.g. python-fastapi>"
when_to_use: "Invoke when the user says «добавь агента под <стек>», «новый исполнитель», when /plan reports unowned files, or when a new stack shows up in the repo (new manifest such as pyproject.toml or package.json)."
---

# Skill: /new-agent

Create and register one executing agent. The harness does the rest for every agent that
follows the template: the SubagentStart hook greets it (caveman, rules, Memory Bank, exec
contract), the SubagentStop hook rejects a return without the contract YAML.

## Steps

1. **Context first.** Read manifests (`package.json`, `pyproject.toml`, `go.mod`,
   `pubspec.yaml`, `build.gradle*`, `*.xcodeproj`, `*.tf`, `Dockerfile`…), the folder layout,
   `.memory-bank/tech-details/`, and the current registry in `AGENTS.md`. Draft:
   - `name` — kebab-case, `^[a-z0-9]+(-[a-z0-9]+)*$`, e.g. `python-fastapi`, `telegram-bot`.
   - `scope` — globs this agent owns, e.g. `backend/**`, `**/*.py`. No overlap with an
     existing agent's scope (overlap → say which agent and ask).
   - `test_command` — the real one from the repo, e.g. `uv run pytest`.
   - `signal_files` — what proves the stack, e.g. `pyproject.toml`.
2. **One question form** (start checkpoint), only for what step 1 could not settle: stack
   name, scope, test command. 2–4 real options each, плюсы / минусы in descriptions,
   recommended first.
3. **Stack rules.** Short list (5–10 lines) of rules for this stack: framework conventions,
   test framework, lint/format command, what not to do. Facts you are unsure of → offer
   `/research "<stack> best practices <year>"` first instead of guessing.
4. **Create** `.claude/agents/<name>.md` from `.claude/harness/exec-agent-template.md`:
   fill every `{{…}}`. Keep the frontmatter at the very top and the `<!-- harness:exec -->`
   marker — the hooks find exec agents by it. File name = `name`.
5. **Validate** before reporting:
   ```bash
   f=.claude/agents/<name>.md
   head -1 "$f" | grep -qx -- '---'                      # frontmatter starts on line 1
   grep -qE '^name: <name>$' "$f"                        # name matches file name
   grep -qE '^description: .+' "$f"                      # description present
   grep -q 'harness:exec' "$f"                           # exec marker present
   grep -q '^CAVEMAN MODE ACTIVE (full)' "$f"            # caveman lines right after frontmatter
   grep -qx 'model: claude-sonnet-5-5' "$f"              # exec agents build on Sonnet 5.5
   grep -qx 'effort: medium' "$f"                        # effort always medium
   ! grep -q '{{' "$f"                                   # no unfilled placeholders
   ```
   Any check fails → fix, re-run.
5b. **Verify command.** The Verify hook and `/mutation` run one test command per project
   (`verify.command` in `.claude/harness/quality.json`, else auto-detect). Several stacks
   in one repo → set `verify.command` to one command that runs them all (e.g. `make test`).
6. **Register** — add one row to the "Executing agents" table in `AGENTS.md`:
   `| <name> | <scope globs> | \`<test_command>\` | <signal files> |`. Remove the
   "_none yet_" row if it is still there.
7. **Report**: file path, registry row, and the next step — agents load at session start:
   restart the session (or open `/agents`) before `/build` can use it.

## Rules
- One agent per stack/layer. Scopes do not overlap.
- Never touch the consilium agents (planner, skeptic, reviewer, debugger) here.
- End with the Memory Bank Steward check (new agent = importance 2 for
  `.memory-bank/tech-details/`).
