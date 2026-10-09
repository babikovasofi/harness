# Text inside code

Human-readable text that lives in code: comments, docstrings, error and log messages, UI
strings, bot replies, commit and PR text. Same anti-slop rules, plus these. Comment rules
distilled from ayusavin/skills `spec/slop/code-comments.md`.

## Comments and docstrings
- Write a comment only for *why*: a non-obvious invariant, a workaround, a constraint the
  code cannot show. No comment that narrates *what* the next line does.
- Restatement test: if most words of the comment are the identifiers of the next line, the
  comment repeats the code — delete it.
- No diff history in code: `# removed the old validator`, `// added for issue #123`,
  `# used by the export step` belong in the commit message or PR, not in the file.
- Docstring: what the function promises and what it refuses (inputs, errors, side effects).
  No "This function is a robust, comprehensive solution for…".
- Match the comment density of the surrounding file.

## Error and log messages
- Say what failed, with the value that failed, and what to do next:
  `invalid chat_id "abc": expected a number` — not `An error has occurred`.
- No apology, no exclamation marks, no "Oops".
- Logs: machine-greppable first (`event=payment_failed order=42 reason=timeout`), prose last.

## UI strings and bot replies
- Short, active, second person, concrete next step: «Оплата не прошла: карта отклонена.
  Попробуйте другую карту» — not «К сожалению, произошла ошибка при обработке платежа».
- Russian copy: run `references/ru-checklist.md` (no канцелярит, no participle tails, verb
  first). One idea per message.
- Same term for the same thing everywhere (кнопка, экран, команда).

## Commit and PR text
- Subject: Conventional Commits (`AGENTS.md`). Body: *why*, in plain sentences, no bullet
  wall, no "This commit introduces…".
- PR body: what changed, why, how it was tested, with the real command and result.
