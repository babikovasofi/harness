---
name: memory-bank-defrag
description: >
  Defragment and re-actualize a project memory bank (the .memory-bank/ knowledge
  base + the project's auto-memory). Reads everything that changed in the repo
  since the last defrag, finds where the memory bank has gone stale or
  accumulated amendment-on-amendment "patches", folds the patches into clean
  current-state docs, closes resolved questions, and updates the auto-memory —
  then shows a diff for review. Use when the user says "defrag the memory bank",
  "привести memory bank в порядок", "дефрагментация памяти", "актуализируй
  .memory-bank", "причеши базу знаний", or runs /memory-bank-defrag.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: "[baseline-ref]  (optional: e.g. HEAD~20 or a commit SHA to override auto-detected baseline)"
when_to_use: "Invoke when the user says «почисти memory bank», «дефрагментация», «актуализируй базу знаний», «причеши память», and at the end of every night."
---

# Memory Bank Defrag

Bring a project's memory bank back in sync with reality and remove cruft. The
memory bank is three things:

1. **`.memory-bank/`** in the repo — the durable, version-controlled knowledge
   base (project context, requirements, decisions/ADRs, scope, open questions,
   stakeholders, glossary). Structure varies per project; operate on whatever
   files exist, don't assume a fixed layout.
2. **Auto-memory** — the cross-session memory at
   `~/.claude/projects/<slugified-cwd>/memory/` (an `MEMORY.md` index plus one
   file per fact). Local only — **absent on cloud/headless runs**; skip silently
   if the directory doesn't exist.
3. **Repo current-state docs** — files that assert *what is true now* and drift
   the same way: `README.md`, `AGENTS.md`/`CLAUDE.md`, design specs, proposals.
   Update these when a recent commit makes them stale. Do **not** touch raw
   source records that capture *what happened* — meeting transcripts, chat
   dumps, extracted board content — those are evidence; keep them verbatim
   (translate only by adding a summary alongside, never by overwriting).

The job is **defragmentation**, not rewriting: same facts, fewer patches.
Amendment-on-amendment trails collapse into one current-state statement;
resolved questions get closed; stale facts get corrected against the actual
code/docs; new durable facts from recent commits get captured.

## Non-negotiables

- **Accuracy > speed.** Memory is point-in-time and may be wrong. Before you
  assert a fact as current, **verify it against the live repo** (file exists,
  symbol not renamed, deadline not passed, stack matches code). If a memory
  claim contradicts current code, trust the code and fix the memory.
- **Fold, don't lose.** When collapsing patches, preserve every substantive
  fact. A reversal that carries decision-relevant context (why we moved off X)
  stays as a short supersession note — that's history, not a patch.
- **Only substantive facts — no process noise.** The memory bank records the
  *project*, not your maintenance of it. Do **not** add "actualized on <date>",
  "switched to English", "synced the docs" timeline/history entries, and do not
  repeat the same standing rule (e.g. "working language is English") across many
  files — state it once in its authoritative home and link to it. When a sync
  you just did makes an old "needs updating" caveat stale, delete the caveat;
  don't leave a trail.
- **Don't invent.** No facts, paths, dates, or decisions that aren't in the
  commits, the code, or the existing memory. Unknown stays unknown.
- **Review before commit.** Make the edits, then show the diff and a summary. Do
  **not** auto-commit unless the user asks (interactive) or the unattended rules
  below apply. Auto-memory files live outside the repo and are written directly
  (not committed).
- **Convert relative dates to absolute** (use the current date from context).

## Workflow

### 1. Locate the baseline (last defrag)

Find the commit of the previous defrag so you only process what changed since.

```bash
# Preferred: explicit trailer this skill writes on its own commits
git log -1 --grep='^Memory-Defrag:' --format='%H %cI %s'
# Fallback: the conventional subject line
git log -1 --grep='actualize memory bank' --format='%H %cI %s'
```

- If the user passed a `baseline-ref` argument, use it instead.
- If neither is found (first ever run), say so and propose a sensible range
  (e.g. last 20 commits, or since the memory bank dir was created:
  `git log --diff-filter=A -1 --format=%H -- .memory-bank`). Confirm with the user
  before processing a large history (interactive) or just use it (unattended).

### 2. Gather what changed since baseline — and bail early if nothing did

```bash
git log <baseline>..HEAD --format='%h %cI %s'           # commit subjects
git diff <baseline>..HEAD --stat -- . ':(exclude).memory-bank'  # what code/docs moved
```

**No-op guard:** if `<baseline>..HEAD` is empty (no commits since the last
defrag), there is nothing to do. Stop here — no edits, no commit, no PR. Report
"nothing changed since the last defrag" and exit. (This is what keeps a daily
schedule cheap and quiet.)

Otherwise read the actual diffs (or the changed files) for anything that
changes a fact the memory bank records: stack/dependency changes, renamed or
deleted files, new integrations, resolved decisions, changed config, new
constraints. Ignore pure formatting / lockfile churn — if the only changes are
cosmetic, treat it as a no-op too.

### 3. Read the current memory bank

- `ls` and read every file under `.memory-bank/`.
- If auto-memory exists, read its `MEMORY.md` and the referenced files. (On
  cloud/headless runs this directory won't exist — skip it.)

### 4. Detect divergences

Build a list, each tagged with evidence (commit SHA, file:line):

- **Stale facts** — memory says X, current code/docs say Y.
- **Patches to fold** — multiple "Amendment <date>" blocks on one decision,
  superseded-but-still-described content, the same fact stated three ways across
  files. Collapse to current state + one supersession note where a reversal
  happened.
- **Resolvable questions** — open questions the recent commits actually answered.
- **Dangling references** — memory cites a file/symbol/flag that no longer exists.
- **Uncaptured facts** — durable decisions/constraints in recent commits not yet
  in the memory bank.

If divergences are large or ambiguous in an interactive run, surface the list
and confirm direction before mass-editing. In an unattended run, proceed and let
the PR be the review surface.

### 5. Apply the edits

Edit `.memory-bank/`, the repo current-state docs (README and the like), and
auto-memory to current state:

- Rewrite patched sections as clean current-state; keep a one-line
  "superseded by … because …" only where the reversal matters.
- Close resolved questions in place (mark resolved + the answer + the commit),
  matching the file's existing convention.
- Correct stale facts; fix or drop dangling references.
- Capture new durable facts in the right file.
- Auto-memory (skip if absent): update the relevant fact file (don't duplicate —
  edit the existing one), refresh its `MEMORY.md` index line, delete memories
  proven wrong. Link related memories with `[[name]]`.

### 6. Verify

- `grep` the memory bank for leftovers of anything you retired (old vendor,
  old path, old decision) — catch half-updated mentions.
- Re-check internal consistency: a table row and the prose around it agree; a
  closed question isn't still referenced as open elsewhere.

### 7. Report + commit

Summary: files touched, patches folded, questions closed, facts corrected,
anything you deliberately left alone.

- **Interactive run:** show the diff (`git diff`); commit only when the user asks.
- **Unattended run:** see below.

Commit subject + trailer (the trailer is what the next run's baseline detection
finds — always include it):

```
docs(memory-bank): actualize memory bank, <one-line theme>

<what was folded/closed/corrected>

Memory-Defrag: <YYYY-MM-DD>
```

## Unattended runs (end of night)

When there is no human to review mid-run. In this harness that is the last step of
`/night` (`.claude/skills/night/rails.md` → "End of night"). This is the one allowed exception to the
"ask before every push" rule in `AGENTS.md`:

- **Open a pull request, never push to `main`.** Create a branch
  (`memory-defrag/<YYYY-MM-DD>`) from `main`, commit with the trailer above, push it, and
  open a PR whose body is the step-7 summary. A human merges. This keeps the
  baseline-trailer in history once merged, and keeps the knowledge base reviewed.
- **If the no-op guard fired (step 2), do nothing** — no branch, no PR. A quiet
  run is the correct outcome on a day with no relevant commits.
- **Don't loop on yourself.** Your own defrag commit carries the `Memory-Defrag:`
  trailer and becomes the next baseline, so the following run sees no new
  substantive commits and no-ops. Never treat a prior defrag commit as a change
  to process.
- Auto-memory: skip in unattended runs — operate on the repo alone, so every change
  lands in the PR.
- Push only the `memory-defrag/<YYYY-MM-DD>` branch. Never `main`, never the night
  branch, never force. After the PR is open, check out the night branch again and put
  the PR link into the morning report.

## Notes

- This skill changes documentation/knowledge only — it never edits product code.
- If the project's `CLAUDE.md`/`AGENTS.md` defines a memory-update protocol or a
  working-language rule, follow it.
- Keep the memory bank's existing tone and structure; match it, don't impose a
  new one.
