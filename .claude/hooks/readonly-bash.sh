#!/usr/bin/env bash
# PreToolUse(Bash) hook scoped to read-only subagents (planner, skeptic) via their
# frontmatter: Bash is there only for the code index and read-only inspection. Every
# command segment (split on && || ; |) must start with an allowed reader; no redirects
# into files. Exit 2 blocks. Fail-closed on parse errors (read-only agents lose nothing).
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "readonly-bash: jq missing" >&2; exit 2; }
CMD="$(jq -r '.tool_input.command // empty' 2>/dev/null)" || { echo "readonly-bash: bad input" >&2; exit 2; }
[ -n "$CMD" ] || exit 0

block() { echo "read-only agent: $1. Allowed: ast-index, git log/show/diff/status/ls-files/blame/grep, ls, cat, head, tail, wc, rg, grep, find (no -exec/-delete), tree." >&2; exit 2; }

# Output redirection into a file (2>/dev/null and >/dev/null are fine).
STRIPPED="$(printf '%s' "$CMD" | sed -E 's/[0-9]?>&?[[:space:]]*\/dev\/null//g; s/[0-9]>&[0-9]//g')"
printf '%s' "$STRIPPED" | grep -qE '(^|[^<])>{1,2}' && block "no redirects into files"
printf '%s' "$CMD" | grep -qE '\$\(|`' && block "no command substitution"

while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue
  first="$(printf '%s' "$seg" | awk '{print $1}')"
  case "$first" in
    ast-index|ls|cat|head|tail|wc|rg|grep|tree|pwd|echo|sort|uniq|cut|tr|jq) ;;
    find) printf '%s' "$seg" | grep -qE -- '-(exec|execdir|delete|ok|fprint)' && block "find with -exec/-delete" ;;
    git)
      sub="$(printf '%s' "$seg" | awk '{for(i=2;i<=NF;i++){ if ($i=="-C"||$i=="-c"||$i=="--git-dir"||$i=="--work-tree"){i++; continue} if ($i !~ /^-/){print $i; exit} }}')"
      case "$sub" in log|show|diff|status|ls-files|blame|grep|rev-parse|branch) ;; *) block "git $sub is not read-only" ;; esac
      [ "$sub" = branch ] && printf '%s' "$seg" | grep -qE -- '(-d|-D|-m|-M|-c|-C|--delete|--move|--copy)\b' && block "git branch changes refs" ;;
    *) block "'$first' is not a reader" ;;
  esac
done < <(printf '%s\n' "$CMD" | sed -E 's/(\&\&|\|\||;|\|)/\n/g')
exit 0
