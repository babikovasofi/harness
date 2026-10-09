#!/usr/bin/env bash
# Stop hook — anti-AI-slop check on the answer the user is about to read. Counts only
# high-precision AI markers (EN + RU) outside code spans, fenced blocks and quotes; two or
# more → one rewrite pass. Density scorer, never an LLM judge. Adapted from ayusavin/skills
# slop-gate. Loop-safe (stop_hook_active → allow), fail-open.
set -euo pipefail
trap 'exit 0' ERR
command -v jq >/dev/null 2>&1 || exit 0

STDIN="$(cat)"
[ "$(printf '%s' "$STDIN" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

ANS="$(printf '%s' "$STDIN" | jq -r '.last_assistant_message // empty')"
if [ -z "$ANS" ]; then
  T="$(printf '%s' "$STDIN" | jq -r '.transcript_path // empty')"
  [ -n "$T" ] && [ -f "$T" ] || exit 0
  ANS="$(jq -rs 'map(select(.type=="assistant")) | last // empty | .message.content[]? | select(.type=="text") | .text' "$T" 2>/dev/null || true)"
fi
[ -n "$ANS" ] || exit 0

# perl with UTF-8: drop fenced blocks, inline code, «quotes» and "quotes" (quoting a banned
# phrase is not using it), then count Cyrillic + Latin markers case-insensitively.
FOUND="$(printf '%s' "$ANS" | perl -CSDA -Mutf8 -0777 -ne '
  s/^```.*?^```//msg; s/`[^`\n]*`//g; s/«[^»]*»//g; s/"[^"\n]*"//g; s/\x{201C}[^\x{201D}]*\x{201D}//g;
  my $re = qr/\bdelve|\btapestry|\bmoreover\b|\bfurthermore\b|it.s (?:important|worth) (?:to note|noting)|it is important to note|navigating the|in the realm of|underscores the|a testament to|ever-evolving|\bseamless(?:ly)?\b|robust solution|elevate your|in today.s|let.s dive|great question|стоит отметить|важно отметить|стоит подчеркнуть|важно понимать|в современном мире|ни для кого не секрет|играет (?:важную|ключевую) роль|выводит на новый уровень|не просто [^,.]{1,40}, а |подводя итог|в заключение|таким образом,|отличный вопрос/i;
  my ($n, %u, @l) = (0);
  while (/($re)/g) { $n++; my $k = lc $1; push @l, $k unless $u{$k}++ }
  print "$n\t", join(",", @l[0 .. ($#l < 4 ? $#l : 4)]);
' 2>/dev/null || true)"
N="${FOUND%%$'\t'*}"; FOUND="${FOUND#*$'\t'}"
[ "${N:-0}" -ge 2 ] 2>/dev/null || exit 0

REASON="Anti-slop: the answer has ${N} AI-text markers (${FOUND}). Rewrite it per .claude/skills/anti-ai-slop-writing/SKILL.md (+ references/ru-checklist.md for Russian): drop the marker phrases, lead with the fact, keep caveman compression in chat. Do not mention this check."
jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
exit 0
