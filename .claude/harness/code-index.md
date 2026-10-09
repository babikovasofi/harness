# Code index: ast-index

Search code through the index, not by reading files one after another. `ast-index`
(Rust CLI, SQLite + FTS5) answers in milliseconds and returns structured results for
Python, TypeScript/JavaScript, Go, Kotlin/Java, Swift, Dart, Rust, Ruby, C#, PHP, C++ and
more. Install: `brew tap defendend/ast-index && brew install ast-index`.

## Order of tools
1. `ast-index` first for any "where is / who uses / what calls / how is it built".
2. Read only the files and line ranges it points to.
3. `Grep` / `rg` only for string literals, regexes, comments, or when the index is empty.
Do not re-run grep "for completeness" after the index answered.

## Commands you need
| Need | Command |
|------|---------|
| Understand an area in one call (symbols, source, callers, tests) | `ast-index explore "<question or names>" --rwr` |
| Anything by name (files, symbols, modules) | `ast-index search "<name>"` |
| Symbol / class definition | `ast-index symbol "<name>"`, `ast-index class "<name>"` |
| Who uses it | `ast-index usages "<name>"`, `ast-index refs "<name>"` |
| Who calls a function | `ast-index callers "<fn>"` |
| Implementations / hierarchy | `ast-index implementations "<base>"`, `ast-index hierarchy "<class>"` |
| File structure without reading it | `ast-index outline "<file>"` |
| Project map / conventions (planning) | `ast-index map`, `ast-index conventions` |
| Index health | `ast-index stats` |

## Index lifecycle
- First time in a project: `ast-index rebuild` — the SessionStart hook starts it in the
  background when `ast-index stats` finds no index. The index lives in
  `~/Library/Caches/ast-index/` (macOS), not in the repo.
- The SessionStart hook runs `ast-index update` in the background on every session start.
- After big changes (branch switch, mass refactor): `ast-index update`.
