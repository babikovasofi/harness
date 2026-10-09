#!/usr/bin/env bash
# UserPromptSubmit hook — the user never has to type skill names. Every prompt gets:
#   1) the always-on writing rules (caveman + anti-slop in chat),
#   2) the intent → skill map, plus a "likely skill" hint when the words clearly match.
# Context only, never blocks. Fail-open.
set -euo pipefail
trap 'exit 0' ERR
command -v jq >/dev/null 2>&1 || exit 0

P="$(jq -r '.prompt // empty')"
[ -n "$P" ] || exit 0
case "$P" in /*) exit 0 ;; esac            # explicit slash command: no routing needed

# perl with UTF-8: case-insensitive Cyrillic matching (grep/tr in the C locale cannot).
hint="$(P="$P" perl -CSDA -Mutf8 -e '
  my $p = $ENV{P}; utf8::decode($p) unless utf8::is_utf8($p);
  my @r = (
    [ qr/работаем ночью|(?<![а-яё])ночь(?![а-яё])|\bnight\b/i,                      "/night" ],
    [ qr/стоп ноч|останови ноч|проснул|night-stop/i,                                   "/night-stop" ],
    [ qr/ресеч|ресерч|research|исследу|найди (информ\w*|инфу|всё|все) про|поищи/i,     "/research" ],
    [ qr/\.(mp3|mp4|m4a|wav|webm|ogg|flac|mov)\b|расшифр|транскриб|запись встречи/i, "/transcribe" ],
    [ qr/агент(а)? под|новый агент|new[- ]agent|исполнител(я|ь) под/i,                "/new-agent" ],
    [ qr/дефраг|почисти (memory|мемори|память)|актуализируй (memory|мемори)|defrag/i, "/memory-bank-defrag" ],
    [ qr/постав(ь|и) харнесс|установи харнесс|install (the )?harness/i,               "/setup" ],
    [ qr/не работает|сломал|ошибк|падает|упал|traceback|exception|stack ?trace|\berror\b|(?<![а-яё])баг/i, "/debug" ],
    [ qr/ревью|отревью|\breview\b|проверь (код|изменения|pr|пр)/i,                    "/review" ],
    [ qr/напиши (текст|пост|письм|сообщени|описани|readme|доку)|перепиши текст|тексты? для бота/i, "/anti-ai-slop-writing" ],
  );
  for my $x (@r) { if ($p =~ $x->[0]) { print $x->[1]; last } }
' 2>/dev/null || true)"

CTX="HARNESS ROUTER (auto, every prompt).
Writing, always — chat included: caveman compression + anti-AI-slop bans (.claude/skills/anti-ai-slop-writing/SKILL.md): no banned words/phrases (references/banned-words.md), no AI openers/closers, no fake balance (\"не просто X, а Y\"), no hedging stacks, em dash at most 1 per 500 words, no emoji bullets, no канцелярит (является/данный/осуществляет), concrete names and numbers, never invented specifics. Docs/reports/commit bodies/PR/bot copy/comments/UI strings: the full skill (+ references/ru-checklist.md for Russian, references/code-text.md for text inside code).
Skills fire from intent, the user never needs to type them: feature/task/«сделай»/«добавь» → /day (default) → /plan → /build → /review; «ночь» → /night; bug/error/«не работает» → /debug; «ресеч»/«найди» → /research; audio/video file → /transcribe; new stack → /new-agent; «почисти memory bank» → /memory-bank-defrag; install into another project → /setup; any text for people → /anti-ai-slop-writing. After every reply: Memory Bank Steward check. Questions only at checkpoints, options with плюсы/минусы."
[ -n "$hint" ] && CTX="$CTX
Likely skill for this prompt: $hint — invoke it (Skill tool) unless the request clearly means something else."

jq -nc --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$c}}'
