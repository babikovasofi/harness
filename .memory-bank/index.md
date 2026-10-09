# Memory Bank — index

> This is the source of truth for what the project is. The `/plan`, `/build`, `/review`, and `/debug` agents read this file FIRST. Replace the placeholders below with your real project. If you already keep a project knowledge base, point the agents at that instead.

## Project

- **What:** <one line — what you are building and for whom>
- **Goal:**
- **Stack:** <languages, frameworks, key services>

## Where to look

- What the product does, who it serves → `./product-overview/`
- How to work here → `./steerings/` (`development-conventions.md`, `testing-conventions.md`)
- Stack, architecture, module interactions → `./tech-details/`
- Current and planned work → `./tasks/`
- Decisions already made → `./decisions.md`

(Create these files as the project grows. Keep this index small — it is a table of contents, not a dump. If it gets bloated, ask the agent to reorganize it. Maintained by `/memory-bank` — see `.claude/skills/memory-bank/SKILL.md`.)
