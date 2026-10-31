# A line typed while a REPL command runs is not run

Found 2026-10-26, from two failures of `terminal/repl-debug` in `make check`
during the functors-units roadmap. Status: fixed 2026-10-29;
[fix and regression](../terminal-races-fixed.md).

## What happens

At the REPL on a terminal, type a line while a `:` command is still running
-- right after `:set pause on`, `:break 3`, `:help`. The line is echoed where
it is typed, drawn again at the next prompt, and not run: the REPL answers
with its continuation prompt `=`, as if the line were incomplete.

From `make check` at `baba685db` (2026-10-26 04:16, load about 5 to 8), the
screen `terminal/repl-debug` was left with:

```
- :break 3
error: which file? (:break FILE:LINE)
:break stdIn#1:3
- :break stdIn#1:3
=
```

From `make check` at `7a0afbf0c` (2026-10-25 03:43, load about 1 to 6), the
same test, after another command:

```
- :set pause on

- fun loop (n : int) = if n = 0 then 0 else loop (n - 1);
=
```

In both, the line the script typed next (`:break stdIn#1:3`, `fun loop ...;`)
was typed while the command before it ran: it is echoed once on a line of
its own, drawn again by the editor at the prompt, and left unfinished. The
test then waited out its 20 s for the line's answer. Run again, the test
passed: it depends on when the keys arrive.

## Why

`ReplFront.readEntry` (`src/repl/front.sml`) puts the terminal back to how it
was -- cooked -- when the line the editor accepted is a command or blank:

```sml
(* a line that will run is already quiet; a blank line or a
   command is put back, since nothing else makes it quiet *)
(if CharVector.all Char.isSpace t orelse isCommand t then Terminal.leave () else ();
```

A line of code is held quiet while it runs (`ReplFront.hold`: echo off, a
return left as typed; `docs/plans/repl.md`, D18), so that keys typed ahead
"are neither echoed nor lost". A command is not: while it runs the terminal
is cooked, so the kernel echoes what is typed (the line on its own) and
translates its return to a newline (`ICRNL`). When the editor next reads,
the line ends in `\n`, which is Ctrl-J, and Ctrl-J is the editor's `Newline`
(`lib/terminal/line_edit_fn.sml`, the default bindings: `(ctrlKey #"j",
Newline)`), not `AcceptOrNewline`: a newline is put in the input, and the
continuation prompt shown. It came in with `54f408081` (2026-10-13, "Keep the
terminal quiet from the prompt mark until code runs"), which made code
quiet and left commands as they were.

## Reproduced

`typeahead.py` (beside this file) starts `bin/rune-repl` in a pty, sends a
command, waits `DELAY` seconds, types `val typedAhead = 40 + 2;` and a return,
and says whether it ran. On functors-units' REPL of 2026-10-26, whose
`readEntry` puts a command back as `54f408081` made it, 8 runs each, at a
load of about 16:

| entry | delay 0 | 2 ms | 10 ms | 30 ms |
|---|---:|---:|---:|---:|
| `:set pause on` | 0 lost | 7 lost | 0 lost | 0 lost |
| `:help` | 0 lost | 4 lost | 0 lost | 0 lost |
| `val c = 1;` (code) | 0 lost | 0 lost | 0 lost | 0 lost |

With no delay the keys come while the editor is still raw; after 10 ms the
command is done and the editor raw again; at 2 ms they come while the
command runs. Code is held quiet and loses nothing.

It is not only the tests': a person who types ahead after a command loses
the line's return and sees it echoed twice.

## A fix

Hold a command quiet as code is held: in `readEntry`, put the terminal back
for a blank line alone (or not at all, since the next prompt makes it raw
again), and let the commands that hand the terminal to something else
release it themselves, as `:shell` does already (`ReplCommands.shell` calls
`ReplFront.release`; `:edit` and anything that runs a program or reads the
standard input need the same, or `ReplFront.shellLike`). A test: a terminal
script that types the next line before the command's answer is on the
screen, and wants it run.

## Not this bug

Other `terminal/*` failures in the same runs had other causes:
`terminal/term-resize` and `terminal/edit-complete`
(`../terminal-tests-resize-races`), and `repl-prompt`, `repl-commands` and
`repl-errors` at `6f92789f0`, whose screens differed only in the version
line, the check's tree having been edited while it ran. The failures of
`terminal/*` in other sessions' transcripts (2026-10-10, -12, -19 and -20)
were tests being written, `lib/terminal`'s units under development, and
mutation runs, none of them this.
