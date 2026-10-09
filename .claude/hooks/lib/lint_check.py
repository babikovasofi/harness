#!/usr/bin/env python3
"""Language-agnostic lint heuristics for lint-gate.sh: file length, control-flow nesting,
single-letter names. Prints one issue per line; prints nothing when the file is clean."""
import json, re, sys

path, cfg_path = sys.argv[1], sys.argv[2]
try:
    cfg = json.load(open(cfg_path)).get("lint", {})
except Exception:
    cfg = {}
max_lines = int(cfg.get("max_file_lines", 400))
max_nest = int(cfg.get("max_nesting", 3))
allowed = set(cfg.get("short_names_allowed", ["i", "j", "k", "n", "x", "y", "z", "e", "_"]))

try:
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
except OSError:
    sys.exit(0)

issues = []
is_test = bool(re.search(r"(^|/)(tests?|__tests__|spec)/|(_test|\.test|\.spec|_spec|Test)\.\w+$|(^|/)test_[^/]*$", path))
limit = max_lines * 2 if is_test else max_lines
if len(lines) > limit:
    issues.append(f"file has {len(lines)} lines (max {limit}{' for tests' if is_test else ''}): split it by responsibility")

CONTROL = re.compile(r"^\s*(?:\}\s*)?(?:if|elif|else\s+if|for|foreach|while|switch|match|try|catch|except|when|guard)\b")
COMMENT = re.compile(r"^\s*(#|//|/\*|\*)")
stack, worst, worst_line = [], 0, 0
for no, raw in enumerate(lines, 1):
    if not raw.strip() or COMMENT.match(raw):
        continue
    indent = len(raw.expandtabs(4)) - len(raw.expandtabs(4).lstrip())
    while stack and stack[-1] >= indent:
        stack.pop()
    if CONTROL.match(raw):
        stack.append(indent)
        if len(stack) > worst:
            worst, worst_line = len(stack), no
if worst > max_nest:
    issues.append(f"line {worst_line}: control flow nested {worst} deep (max {max_nest}): use early returns or extract a function")

ASSIGN = [
    re.compile(r"^\s*([A-Za-z])\s*(?::\s*[\w\[\], .|]+)?=(?!=)"),               # python / plain
    re.compile(r"\b(?:let|const|var|val)\s+([A-Za-z])\b\s*(?::\s*[\w<>\[\]?]+)?\s*="),  # js/ts/kotlin/swift
    re.compile(r"^\s*([A-Za-z])\s*:="),                                        # go
]
seen = set()
for no, raw in enumerate(lines, 1):
    if COMMENT.match(raw) or re.match(r"^\s*for\b", raw):
        continue
    for rx in ASSIGN:
        m = rx.search(raw)
        if m and m.group(1) not in allowed and m.group(1) not in seen:
            seen.add(m.group(1))
            issues.append(f"line {no}: one-letter name '{m.group(1)}': name it after what it holds")
print("\n".join(issues[:12]))
