# AGENTS.md

## What this is

The Global Bible Tools Study App: an cross-platform mobile application for
reading and studying scripture in Hebrew and Greek.

## Documentation map

Read these when relevant to your task. They are not loaded by default, so pull
them in yourself:

- `docs/DOMAIN.md` — terminology and the problems the app is solving. Use this 
  to understand the language from prompts and code that might have special
  meaning.
- `docs/ARCHITECTURE.md` — how the code is organized, how domains are isolated,
  and how data flows through the application. This governs how could should be
  written, not necessarily how it is today.
- `docs/DEVELOPMENT.md` — practical details for day-to-day work. Use this when
  you need to understand how tools are used or how work is done.
- `docs/decisions/` — numbered decision records explaining why significant
  changes were made. Reference these before making any kind of architectural
  change or cleanup.

## Ground rules

- Verify changes with the test command listed in `docs/DEVELOPMENT.md` before
  considering a task complete.
- When you make a decision that a future reader would ask "why?" about, record
  it in `docs/decisions/` (see the numbering convention there).
- If this file and another doc disagree, trust the more specific doc and fix
  this file.
- Keep this file concise. Instead put new context in other files and point to
  them from here.
