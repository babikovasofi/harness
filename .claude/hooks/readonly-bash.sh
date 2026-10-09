#!/usr/bin/env bash
# PreToolUse(Bash) hook scoped to read-only subagents (planner, skeptic) via their
# frontmatter: Bash is there only for the code index and read-only inspection. Every
# command segment (split on && || ; | &) must start with an allowed reader; no redirects
# into files. Exit 2 blocks. Fail-closed on parse errors (read-only agents lose nothing).
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "readonly-bash: jq missing" >&2; exit 2; }
CMD="$(jq -r '.tool_input.command // empty' 2>/dev/null)" || { echo "readonly-bash: bad input" >&2; exit 2; }
[ -n "$CMD" ] || exit 0

block() { echo "read-only agent: $1. Allowed: ast-index, git log/show/diff/status/ls-files/blame/grep, ls, cat, head, tail, wc, rg, grep, find (no -exec/-delete), sort, cut, tr, jq." >&2; exit 2; }

# Fd plumbing (2>&1, >/dev/null, &>/dev/null) is harmless; drop it before the checks below.
CLEAN="$(printf '%s' "$CMD" | sed -E 's/&?[0-9]?>&?[[:space:]]*\/dev\/null//g; s/[0-9]?>&[0-9]//g')"

# Writes into files, command / process substitution, background jobs.
printf '%s' "$CLEAN" | grep -qE '(^|[^<])>{1,2}' && block "no redirects into files"
printf '%s' "$CLEAN" | grep -qE '\$\(|`|<\(|>\(' && block "no command or process substitution"

while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue
  first="$(printf '%s' "$seg" | awk '{print $1}')"
  case "$first" in
    ast-index|ls|cat|head|tail|wc|grep|pwd|echo|cut|tr|jq) ;;
    sort) printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])(-o|--output)' && block "sort -o writes a file" ;;
    uniq) [ "$(printf '%s' "$seg" | awk '{n=0; for(i=2;i<=NF;i++) if ($i !~ /^-/) n++; print n}')" -le 1 ] || block "uniq with an output file" ;;
    rg)   printf '%s' "$seg" | grep -qE -- '--pre(=|[[:space:]])' && block "rg --pre runs a command" ;;
    find) printf '%s' "$seg" | grep -qE -- '-(exec|execdir|delete|ok|okdir|fprint|fprint0|fprintf|fls)' && block "find with -exec/-delete/-fprint" ;;
    git)
      sub="$(printf '%s' "$seg" | awk '{for(i=2;i<=NF;i++){ if ($i=="-C"||$i=="-c"||$i=="--git-dir"||$i=="--work-tree"){i++; continue} if ($i !~ /^-/){print $i; exit} }}')"
      case "$sub" in log|show|diff|status|ls-files|blame|grep|rev-parse|branch) ;; *) block "git $sub is not read-only" ;; esac
      printf '%s' "$seg" | grep -qE -- '--output(=|[[:space:]])' && block "git --output writes a file"
      [ "$sub" = branch ] && printf '%s' "$seg" | grep -qE -- '(-d|-D|-m|-M|-c|-C|--delete|--move|--copy)\b' && block "git branch changes refs" ;;
    *) block "'$first' is not a reader" ;;
  esac
done < <(printf '%s\n' "$CLEAN" | sed -E 's/(\&\&|\|\||;|\||\&)/\n/g')
exit 0
