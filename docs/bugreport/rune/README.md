# Rune bug reports

Bugs of Rune itself found while working on something else, one directory per
bug, each with a `BUGREPORT.md` and, where there is one, what reproduces it.
A bug fixed when it was found is written down with its fix instead (for the
cache, [plans/build-cache-issues.md](../../plans/build-cache-issues.md)).

* [repl-type-ahead-after-command](repl-type-ahead-after-command/BUGREPORT.md):
  a line typed while a REPL command runs is echoed twice and not run; the
  terminal is cooked while a command runs (2026-10-26, open; `typeahead.py`
  reproduces it).
* [terminal-tests-resize-races](terminal-tests-resize-races/BUGREPORT.md):
  `terminal/term-resize` and `terminal/edit-complete` resize before the
  program is ready (2026-10-25, fixed: `keys.sml` arms the count before it
  says its size, and a resize ends a read that has not reached `poll`).
