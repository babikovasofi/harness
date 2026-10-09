#!/usr/bin/env python3
"""Small mutation-testing harness for /mutation.

Mutates ONLY the lines changed against a base ref (default: main), one operator at a time,
runs the project's tests on every mutant and reports which mutants survived (tests still
green = the tests do not check that behaviour). Every file is restored after each mutant;
a backup in .claude/state/mutation-backup/ covers a crash or Ctrl+C.

Usage:
  .claude/scripts/mutate.py --test-cmd "python3 -m pytest -q" [--base main] [--files a.py b.py]
                            [--max 25] [--timeout 120] [--report swarm-report/mutation-x.md]
Exit: 0 = score >= --min-score (or nothing to mutate), 1 = below, 2 = setup error.
"""
import argparse, json, os, re, shutil, signal, subprocess, sys, time
from pathlib import Path

CODE_EXT = {".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".go", ".rs", ".rb", ".java",
            ".kt", ".kts", ".swift", ".dart", ".cs", ".php", ".scala", ".c", ".cc", ".cpp"}
TEST_PATH = re.compile(r"(^|/)(tests?|__tests__|spec)(/|$)|(_test|\.test|\.spec|_spec|Test)\.\w+$|(^|/)test_[^/]*$")
COMMENT = re.compile(r"^\s*(#|//|/\*|\*)")

# (name, regex, replacement) — operators need spaces around them so `->`, `=>`, `++`,
# `**`, `//`, generics and unary minus are left alone.
OPERATORS = [
    ("+ → -",   r"(?<=\s)\+(?=\s)", "-"),
    ("- → +",   r"(?<=\s)-(?=\s)", "+"),
    ("* → /",   r"(?<=\s)\*(?=\s)", "/"),
    ("/ → *",   r"(?<=\s)/(?=\s)", "*"),
    ("== → !=", r"(?<=\s)==(?=\s)", "!="),
    ("!= → ==", r"(?<=\s)!=(?=\s)", "=="),
    ("=== → !==", r"(?<=\s)===(?=\s)", "!=="),
    ("!== → ===", r"(?<=\s)!==(?=\s)", "==="),
    ("<= → <",  r"(?<=\s)<=(?=\s)", "<"),
    (">= → >",  r"(?<=\s)>=(?=\s)", ">"),
    ("< → <=",  r"(?<=\s)<(?=\s)", "<="),
    ("> → >=",  r"(?<=\s)>(?=\s)", ">="),
    ("and → or", r"\band\b", "or"),
    ("or → and", r"\bor\b", "and"),
    ("&& → ||", r"&&", "||"),
    ("|| → &&", r"\|\|", "&&"),
    ("True → False", r"\bTrue\b", "False"),
    ("False → True", r"\bFalse\b", "True"),
    ("true → false", r"\btrue\b", "false"),
    ("false → true", r"\bfalse\b", "true"),
    ("not x → x", r"\bnot\s+", ""),
]

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parents[2])
BACKUP = ROOT / ".claude/state/mutation-backup"


def sh(cmd, timeout):
    start = time.time()
    try:
        p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        return p.returncode, time.time() - start, (p.stdout + p.stderr)[-2000:]
    except subprocess.TimeoutExpired:
        return "timeout", time.time() - start, ""


def restore_backups():
    if not BACKUP.exists():
        return []
    restored = []
    for b in BACKUP.rglob("*"):
        if b.is_file():
            target = ROOT / b.relative_to(BACKUP)
            shutil.copy2(b, target)
            restored.append(str(target.relative_to(ROOT)))
    shutil.rmtree(BACKUP, ignore_errors=True)
    return restored


def changed_lines(base, files):
    """{path: [line numbers]} for lines added/changed vs base (working tree included)."""
    args = ["git", "diff", "-U0", base, "--"] + (files or [])
    out = subprocess.run(args, cwd=ROOT, capture_output=True, text=True).stdout
    result, cur = {}, None
    for line in out.splitlines():
        if line.startswith("+++ "):
            p = line[4:]
            cur = p[2:] if p.startswith("b/") else None
            if cur and (Path(cur).suffix not in CODE_EXT or TEST_PATH.search(cur)):
                cur = None
        elif line.startswith("@@") and cur:
            m = re.search(r"\+(\d+)(?:,(\d+))?", line)
            start, count = int(m.group(1)), int(m.group(2) or 1)
            result.setdefault(cur, []).extend(range(start, start + count))
    # untracked new files: every line counts
    if not files:
        untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT,
                                   capture_output=True, text=True).stdout.split()
        for u in untracked:
            if Path(u).suffix in CODE_EXT and not TEST_PATH.search(u) and (ROOT / u).is_file():
                n = len((ROOT / u).read_text(errors="replace").splitlines())
                result.setdefault(u, []).extend(range(1, n + 1))
    return result


def mutants_for(path, lines):
    text = (ROOT / path).read_text(errors="replace").split("\n")
    out = []
    for no in sorted(set(lines)):
        if no < 1 or no > len(text):
            continue
        src = text[no - 1]
        if COMMENT.match(src) or not src.strip():
            continue
        code = re.sub(r"(\"[^\"]*\"|'[^']*')", lambda m: " " * len(m.group(0)), src)  # mask strings
        for name, rx, rep in OPERATORS:
            for m in re.finditer(rx, code):
                mutated = src[:m.start()] + rep + src[m.end():]
                if mutated != src:
                    out.append({"file": path, "line": no, "op": name, "before": src.strip(), "after": mutated.strip(),
                                "new_line": mutated})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-cmd", required=True)
    ap.add_argument("--base", default="main")
    ap.add_argument("--files", nargs="*")
    ap.add_argument("--max", type=int, default=25)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--min-score", type=float, default=0.6)
    ap.add_argument("--report")
    a = ap.parse_args()

    leftover = restore_backups()
    if leftover:
        print(f"restored files from an interrupted run: {', '.join(leftover)}")

    rc, base_time, out = sh(a.test_cmd, a.timeout)
    if rc != 0:
        print(f"setup: tests are not green before mutating (exit {rc}); fix them first.\n{out[-800:]}")
        return 2

    candidates = []
    for path, lines in changed_lines(a.base, a.files).items():
        candidates += mutants_for(path, lines)
    if not candidates:
        print(f"nothing to mutate: no changed code lines vs {a.base} (tests excluded).")
        return 0
    # spread the budget across files and lines instead of taking the first N
    candidates.sort(key=lambda m: (m["line"] * 7919 + hash(m["file"] + m["op"])) % 1000003)
    picked = candidates[: a.max]

    interrupted = {"flag": False}
    signal.signal(signal.SIGINT, lambda *_: interrupted.__setitem__("flag", True))
    results = []
    for m in picked:
        if interrupted["flag"]:
            break
        target = ROOT / m["file"]
        bpath = BACKUP / m["file"]
        bpath.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, bpath)
        try:
            lines = target.read_text(errors="replace").split("\n")
            lines[m["line"] - 1] = m["new_line"]
            target.write_text("\n".join(lines))
            rc, dur, _ = sh(a.test_cmd, max(a.timeout, int(base_time * 3) + 5))
            m["result"] = "survived" if rc == 0 else ("timeout" if rc == "timeout" else "killed")
        finally:
            shutil.copy2(bpath, target)
            bpath.unlink(missing_ok=True)
        results.append(m)
    shutil.rmtree(BACKUP, ignore_errors=True)

    killed = sum(1 for r in results if r["result"] in ("killed", "timeout"))
    score = killed / len(results) if results else 1.0
    survived = [r for r in results if r["result"] == "survived"]

    lines = [f"# Mutation report", "",
             f"Base: `{a.base}` · tests: `{a.test_cmd}` · mutants: {len(results)} of {len(candidates)} candidates",
             f"Score: **{killed}/{len(results)} = {score:.0%}** (min {a.min_score:.0%})", ""]
    if survived:
        lines += ["## Survived — tests stay green with this bug", ""]
        for r in survived:
            lines.append(f"- `{r['file']}:{r['line']}` {r['op']}: `{r['before']}` → `{r['after']}`")
        lines.append("")
    lines += ["## Killed", ""] + [f"- `{r['file']}:{r['line']}` {r['op']}" for r in results if r["result"] != "survived"]
    report = "\n".join(lines) + "\n"
    if a.report:
        Path(ROOT / a.report).parent.mkdir(parents=True, exist_ok=True)
        (ROOT / a.report).write_text(report)
    print(report)
    print(json.dumps({"score": round(score, 3), "mutants": len(results), "survived": len(survived)}))
    return 0 if score >= a.min_score else 1


if __name__ == "__main__":
    sys.exit(main())
