#!/usr/bin/env python3
"""Deterministic merge step for /setup. Never clobbers what the target project already has.

  setup-merge.py <SRC harness repo> <DST project> [--agents-md overwrite|append|skip]
                                                  [--link-claude-md]

- .claude/settings.json : add our hook entries per event (dedupe by command), union
                          permissions.deny, set effortLevel only if absent, keep their keys.
- .mcp.json             : add mcpServers."tavily-research" only if missing.
- .gitignore            : append our lines that are missing (append-only).
- .env.example          : create, or append TAVILY_API_KEY= if missing. Never touches .env.
- .claude/harness/quality.json : copy only if absent (keeps tuned thresholds).
- AGENTS.md             : overwrite keeps the target's "Executing agents" registry rows;
                          append adds ours under a heading; skip leaves it.
- CLAUDE.md             : --link-claude-md adds "@AGENTS.md" at the top if missing.
Prints one line per action.
"""
import argparse, json, re, shutil, sys
from pathlib import Path

GITIGNORE_LINES = [".claude/sessions/", ".claude/state/", ".claude/worktrees/", ".env",
                   "*.transcribe.json", ".DS_Store", ".ast-index-root"]


def load_json(p):
    return json.loads(p.read_text()) if p.exists() and p.read_text().strip() else {}


def merge_settings(src, dst):
    ours, theirs = load_json(src), load_json(dst)
    if not theirs:
        shutil.copy2(src, dst)
        return "settings.json: copied"
    added = 0
    for event, entries in ours.get("hooks", {}).items():
        have = {h.get("command") for e in theirs.setdefault("hooks", {}).get(event, []) for h in e.get("hooks", [])}
        for entry in entries:
            new_hooks = [h for h in entry.get("hooks", []) if h.get("command") not in have]
            if new_hooks:
                theirs["hooks"].setdefault(event, []).append({**entry, "hooks": new_hooks})
                added += len(new_hooks)
    deny = theirs.setdefault("permissions", {}).setdefault("deny", [])
    for rule in ours.get("permissions", {}).get("deny", []):
        if rule not in deny:
            deny.append(rule)
    for key in ("$schema", "effortLevel"):
        if key in ours and key not in theirs:
            theirs[key] = ours[key]
    dst.write_text(json.dumps(theirs, indent=2, ensure_ascii=False) + "\n")
    return f"settings.json: merged, {added} hook(s) added"


def merge_mcp(src, dst):
    ours, theirs = load_json(src), load_json(dst)
    servers = theirs.setdefault("mcpServers", {})
    if "tavily-research" in servers:
        return ".mcp.json: tavily-research already there"
    servers["tavily-research"] = ours["mcpServers"]["tavily-research"]
    dst.write_text(json.dumps(theirs, indent=2, ensure_ascii=False) + "\n")
    return ".mcp.json: tavily-research added"


def merge_gitignore(dst):
    have = set(dst.read_text().splitlines()) if dst.exists() else set()
    missing = [l for l in GITIGNORE_LINES if l not in have]
    if missing:
        with dst.open("a") as f:
            f.write("\n# harness\n" + "\n".join(missing) + "\n")
    return f".gitignore: {len(missing)} line(s) appended"


def merge_env_example(src, dst):
    if not dst.exists():
        shutil.copy2(src, dst)
        return ".env.example: copied"
    if re.search(r"^TAVILY_API_KEY=", dst.read_text(), re.M):
        return ".env.example: TAVILY_API_KEY already listed"
    with dst.open("a") as f:
        f.write("\n# Tavily API key for /research deep level: https://app.tavily.com\nTAVILY_API_KEY=\n")
    return ".env.example: TAVILY_API_KEY appended"


REG_HEAD = re.compile(r"^\| Agent \| Scope \(globs\) \| Test command \| Signal files \|$", re.M)


def registry_rows(text):
    m = REG_HEAD.search(text)
    if not m:
        return []
    rows = []
    for line in text[m.end():].splitlines()[2:]:  # skip separator line
        if not line.startswith("|"):
            break
        if "_none yet" not in line:
            rows.append(line)
    return rows


def agents_md(src, dst, mode):
    if not dst.exists() or mode == "overwrite":
        rows = registry_rows(dst.read_text()) if dst.exists() else []
        text = src.read_text()
        if rows:
            text = re.sub(r"^\| _none yet[^\n]*\n", "\n".join(rows) + "\n", text, count=1, flags=re.M)
        dst.write_text(text)
        return f"AGENTS.md: {'written' if not rows else f'overwritten, kept {len(rows)} registry row(s)'}"
    if mode == "append":
        with dst.open("a") as f:
            f.write("\n\n# Harness (mini dev-loop)\n\n" + src.read_text())
        return "AGENTS.md: harness appended under a heading"
    return "AGENTS.md: skipped"


def link_claude_md(dst_root):
    for name in ("CLAUDE.md", "CLAUDE.local.md"):
        p = dst_root / name
        if p.exists() and "@AGENTS.md" not in p.read_text():
            p.write_text("@AGENTS.md\n\n" + p.read_text())
            return f"{name}: @AGENTS.md added at the top"
    return "CLAUDE.md: nothing to link"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--agents-md", choices=["overwrite", "append", "skip"], default="overwrite")
    ap.add_argument("--link-claude-md", action="store_true")
    a = ap.parse_args()
    src, dst = Path(a.src).resolve(), Path(a.dst).resolve()
    if src == dst:
        print("refusing: target is the harness repo itself"); return 2
    (dst / ".claude/harness").mkdir(parents=True, exist_ok=True)
    out = [
        merge_settings(src / ".claude/settings.json", dst / ".claude/settings.json"),
        merge_mcp(src / ".mcp.json", dst / ".mcp.json"),
        merge_gitignore(dst / ".gitignore"),
        merge_env_example(src / ".env.example", dst / ".env.example"),
        agents_md(src / "AGENTS.md", dst / "AGENTS.md", a.agents_md),
    ]
    q = dst / ".claude/harness/quality.json"
    if q.exists():
        out.append("quality.json: kept the project's thresholds")
    else:
        shutil.copy2(src / ".claude/harness/quality.json", q); out.append("quality.json: copied defaults")
    if a.link_claude_md:
        out.append(link_claude_md(dst))
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
