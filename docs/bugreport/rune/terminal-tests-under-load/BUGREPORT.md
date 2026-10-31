# Rune: four terminal tests fail now and then in `make check`, and pass alone

**Intermittent, and three bugs.** Each is a race that a loaded machine
makes likely. Two are in the REPL and its line editor, so users can meet
them; the third is in a test.
- **How often:** eight failures, in seven of about 30 runs of `make check`
  between 2026-10-25 and 2026-10-27 (the functors-units and linting
  campaigns). Each was on a different commit, and each test passed when
  run again alone.
- **Which tests:** `terminal/edit-complete` four times,
  `terminal/repl-debug` twice, `terminal/term-resize` once and
  `terminal/repl-colours` once.
- **The three causes:**
  - **`edit-complete`, a lost wake-up in the line editor:** a resize that
    comes while the editor draws is counted, but the editor's next read
    waits for a key and does not see it. The editor never redraws.
    Reproduced: in 100 rounds on a loaded machine, the test failed 4
    times and a variant of it 5 times.
  - **`repl-debug` and `repl-colours`, keys typed after a command:** after a command, the
    REPL puts the terminal back to cooked until the next prompt. Keys
    typed then are echoed, and their Enter becomes a line break in the
    entry instead of submitting it. Reproduced: in 40 rounds, each of two
    variants of the test failed once.
  - **`term-resize`, the test's own race:** its program says it is ready
    before it installs the handler of resizes. Found by reading.

## Status: fixed 2026-10-29

The runtime retains resize notifications for its next read, the REPL keeps
commands and blank entries quiet, and the keys probe starts counting before
announcing readiness. See [fixes and validation](../terminal-races-fixed.md).
The sections below preserve the original investigation and proposed work.

### Status when reported

- **None is fixed.** The fixes are proposed in each section below.
- **The variants used to reproduce them,** and the logs of the runs, are
  in `~/.cache/claude-rune-drafts/linting/results/terminal-flake/`, not in
  `tests/terminal`.

## The occurrences

| Run of `make check` | Date (UTC) | Commit | Load at its start | Test | What the screen lacked |
|---|---|---|---|---|---|
| functors-units `final-7a0afbf0c` | 2026-10-25 02:54 | `7a0afbf0c` | 1.0 | `repl-debug` | the debugger's later output (the log's excerpt ends at `:continue`) |
| functors-units `api-d551f19dd` | 2026-10-25 18:57 | `d551f19dd` | 9.6 | `term-resize` | `resized 100x30` (the program printed `size 80x24` and no more) |
| the same run | | | | `edit-complete` | the input drawn again at 20 columns: there was no redraw |
| functors-units `m11p1-baba685db` | 2026-10-26 03:31 | `baba685db` | 7.9 | `repl-debug` | `breakpoint 1 at stdIn#1:3`, after `:break stdIn#1:3` appeared twice |
| functors-units `m11-56c86ddd4` | 2026-10-26 09:40 | `56c86ddd4` | 16.1 | `edit-complete` | the same |
| linting `m11` | 2026-10-26 15:37 | `e5f448acc` | about 20 (31 at its end) | `edit-complete` | the same |
| linting `tip5` | 2026-10-26 21:08 | `b5198615e` | 15.4 | `edit-complete` | the same |
| linting `m6` | 2026-10-26 21:47 | `ed7cf1dc9` | 25.5 | `repl-colours` | the answer to `:browse Option`, after it appeared twice and then `=` |

The logs are in the campaigns' drafts:
- `~/.cache/claude-rune-drafts/functors-units/impl/checks/*.log`;
- `~/.cache/claude-rune-drafts/linting/impl/checks/{m11,tip5,m6}.log`.

The load given is the one at the run's start; the machine was shared, and
the load moved between about 5 and 39 during the runs. Three more terminal
failures in one functors-units run (`lint2-6f92789f0`: `repl-commands`,
`repl-errors`, `repl-prompt`) are not counted. They were a real bug of
that day: the REPL's units were linted without the schemes of the earlier
units' globals, since fixed in `UnitBasis.startSession`.

## `terminal/edit-complete`: a lost wake-up in the line editor

`tests/terminal/edit-complete.script`, run by `bin/rune-terminal` on the
REPL's line editor (`lib/terminal`) inside the harness's own terminal
emulator (`lib/terminal/emulator.sml`), 40 columns by 12 rows:

```
send abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH
wait ^> abcdefghij
resize 20 12
wait ^> abcdefghijklmnopqr\nstuvwxyz0123456789AB\nCDEFGH$
```

**What it expects.** After the window narrows to 20 columns, the editor
draws the input again, on a line of its own below what it drew before
(`redraw`, `lib/terminal/line_edit_fn.sml:1252-1259`), as three rows:

```
> abcdefghijklmnopqr
stuvwxyz0123456789AB
CDEFGH
```

**What it got, every time:** the whole screen was the two rows drawn at
40 columns, which the emulator cut to 20 on the resize, and nothing
below them:

```
> abcdefghijklmnopqr
CDEFGH
```

So the editor never drew again: it did not see the resize. (At a glance
the screen looks like the redrawn input with its middle row missing; it
is not.) Each failure took 20.1 s, the wait's time limit.

**The cause.** The editor's loop reads first and asks about resizes after
(`loop`, `lib/terminal/line_edit_fn.sml:1281-1285`):

```
val got = Device.read wait
val r = Device.resizes ()
```

and the read, `sys_term_read` (`runtime/sys/sys_posix.c:1652-1663`), is a
plain `poll`. A `SIGWINCH` that comes while `poll` waits ends it (`EINTR`),
the read returns nothing, and the loop sees the new count. A `SIGWINCH`
that comes after the loop's `Device.resizes ()` and before the next `poll`
starts (while the editor handles the keys and draws them) is counted by
the handler, but nothing looks at the count: `poll` then waits for the
next key, and with no key pending it waits for ever. This is the classic
lost wake-up of a signal and a blocking call.

The test makes that window likely: it resizes as soon as the screen shows
what the editor drew, which is just when the editor has finished drawing
and is on its way back to `poll`. Under load the editor is often not
scheduled again until the signal has come.

**The runs that show it** (2026-10-26, `lint-mut` at functors-units
`d551f19dd`, the three scripts side by side, `bin/rune-test run ...
--repeat N`; the logs are in
`~/.cache/claude-rune-drafts/linting/results/terminal-flake/`):

| Script | What it waits for before the resize | Load 20 to 25, 60 rounds | Pinned, 40 rounds |
|---|---|---:|---:|
| `edit-complete` | the first ten characters of the input | 4 | 0 |
| `zz-edit-fullwait` | the whole input drawn | 3 | 2 |
| `zz-edit-nowait` | nothing: it resizes while the input is still arriving | 0 | 1 |

- **"Pinned"** is the tests on two CPUs, each shared with a busy loop
  (`pinned.sh` there).
- **Every failure** has the screen above: the input drawn at 40 columns,
  never drawn again.
- **At a load of about 14,** `edit-complete` and `zz-edit-fullwait` did not
  fail in 100 rounds, run until one failed. The window needs a loaded
  machine.

Waiting for the whole input makes it no rarer; resizing at once makes it
rare, but not impossible. A resize that comes with the input usually
comes before the read that returns the input, and is seen after it. It
is lost only when the editor has already read the input and is drawing
it as the signal comes. That rules out the other explanation, that the
test raced its own input: the editor loses the resize even when the
input is all drawn before the resize is sent.

**The fix** is in the runtime, so that a resize always ends the read:
- **The self-pipe:** the handler also writes a byte to a non-blocking
  pipe, and `sys_term_read` polls the pipe with the terminal and empties
  it. `Terminal.resizes ()` keeps its meaning.
- **`ppoll`:** `SIGWINCH` blocked, except within a `ppoll` that unblocks
  it, so that a signal that came before the read ends it at once. But then
  the count moves only during a read.

Checking `Device.resizes ()` again before the read would narrow the
window, but not close it.

## `terminal/term-resize`: a race, found by reading

`tests/terminal/term-resize.script` starts `tests/terminal/keys.sml`,
waits for `size 80x24`, resizes the window to 100x30, and waits for
`resized 100x30`. Once, the program printed `size 80x24` and never saw the
resize.

**The cause is a lost signal, and the fault is the test's.**
- `keys.sml` prints its size and only then calls `Terminal.resizes ()`
  for the first time (`tests/terminal/keys.sml:46-47`):

  ```
  val () = say ("size " ^ sizeText ())
  val () = loop (Terminal.resizes ())
  ```

- The first call of `Terminal.resizes ()` is what installs the handler of
  `SIGWINCH` (`sys_term_resizes`, `runtime/sys/sys_posix.c:1599-1614`).
  That is the documented contract: `term_resizes` counts "how often the
  window has changed its size since the first call"
  (`docs/bytecode.md`, the row of Terminal).
- The harness resizes as soon as it sees the size printed.

So a resize that comes between the print and that first call meets no
handler. `SIGWINCH`'s default action is to ignore it, so it is never
counted, and the program waits for ever.

The line editor does not have this hole: it calls `Device.resizes ()`
at the start of each read, before it draws the prompt
(`lib/terminal/line_edit_fn.sml:1225`).

**The fix:** in `keys.sml`, call `Terminal.resizes ()` once before
printing the size. Installing the handler in `Terminal.enter` instead
would close the hole for every program in raw mode, but it changes the
documented contract, so it is a choice for the owner, not a bug fix.

## `terminal/repl-debug` and `terminal/repl-colours`: keys typed after a command, while the terminal is cooked

`tests/terminal/repl-debug.script` types `:break 3`, waits for
`which file`, then types `:break stdIn#1:3` and waits for
`breakpoint 1 at stdIn#1:3`.

**Once** (`baba685db`), the screen showed the second command twice: once
under the error, and once after the prompt. The answer never came:

```
- :break 3
error: which file? (:break FILE:LINE)
:break stdIn#1:3
- :break stdIn#1:3
```

**The cause, found by reading:**
- **While code runs, the terminal is quiet.** Echo is off, and Enter stays
  a carriage return (`term_raw`, `runtime/sys/sys_posix.c:1517-1535`). So
  keys typed ahead are "neither echoed into what it writes nor lost"
  (`docs/repl.md:162-166`).
- **A command is not held quiet; it is put back.** After a blank line or
  a command, `readEntry` calls `Terminal.leave ()`
  (`src/repl/front.sml:323-326`), and the REPL does not `hold` a command
  (`src/repl/repl.sml:591`). Until the next prompt makes the terminal raw
  again, it is cooked: echo on, and `ICRNL` on.
- `which file` is the command's own answer, written in that window. The
  test types the next command as soon as it sees the answer, which under
  load is before the prompt that follows.

Keys that come in that window are:
- **echoed by the terminal driver:** the first copy, under the error;
- **then read by the editor at the prompt:** the second copy;
- **but their Enter, a carriage return, was turned into a line feed** as
  it arrived. A line feed is Ctrl-J, which the editor binds to `Newline`,
  a line break in the entry (`lib/terminal/line_edit_fn.sml:65`), not to
  `AcceptOrNewline`. So the entry is never submitted, and the REPL waits.

That is the screen above, key for key. A user who types ahead after a
command meets the same thing: the keys are echoed into the output, and
their Enter does not submit.

**Reproduced** (2026-10-26, `lint-mut`, load 10 to 14, 40 rounds of
`repl-debug` beside two variants of its start, in
`~/.cache/claude-rune-drafts/linting/results/terminal-flake/`):
- **`zz-repl-ahead-wait`,** `repl-debug`'s first two commands alone:
  1 failure in 40;
- **`zz-repl-ahead`,** the second command typed without waiting for the
  first's answer: 1 in 40;
- **`repl-debug`** itself: 0 in 40.

Both failures show the screen of `baba685db`, and one more row: `=`, the
REPL's continuation prompt. So the Enter did become a line break in the
entry:

```
- :break 3
error: which file? (:break FILE:LINE)
:break stdIn#1:3
- :break stdIn#1:3
=
```

**The fix:** after a command or a blank line, keep the terminal quiet
until the next prompt, as after a line that runs, and not put it back.
`shellLike` (`src/repl/front.sml`) already gives a program that reads the
standard input a terminal as at a shell, for that read.

**`repl-colours` once** (`ed7cf1dc9`), the same way. It types `:type f`,
waits for the answer, then types `:browse Option`
(`tests/terminal/repl-colours.script:27-32`). The screen ended:

```
- :type f
f : int -> int * string * real * shape
:browse Option
- :browse Option
=
```

**`repl-debug`'s other time** (`7a0afbf0c`), the log's excerpt shows the session as
far as `:continue`, so the failure was later in the script. `:continue` is
a command too, and the program it continues runs with the terminal
cooked, but the script waits for the prompt before it types again. Not
explained.

## To do

- **Fix the three:**
  - the runtime's read of the terminal, so that a resize ends it;
  - the REPL, so that it keeps the terminal quiet after a command;
  - `keys.sml`, so that it counts resizes before it says its size.
- **Check each fix with its variant,** run many times on a loaded
  machine. `pinned.sh` in the results directory runs the terminal tests on
  two CPUs, each shared with a busy loop, a narrow form of the runner's
  `--under-load` (which loads every CPU).
- **Whether to keep the variants as tests:** they fail only sometimes, so
  as regression tests they would catch a return of these bugs only now
  and then.
- **`repl-debug`'s other failure** (`7a0afbf0c`) is not explained.
- **Two things that made this harder to find:**
  - the runner keeps its five latest runs (`keepRuns`,
    `lib/test/runner/run.sml:110`), so a failure early in a
    `--repeat` run is deleted before it ends; `--until-fail` keeps it;
  - a failed terminal test keeps only the harness's output and the screen
    as text, not the bytes the program wrote.

## Related

- `docs/bugreport/runevm/heap-corruption-once/` (on branch `linting`): a
  different intermittent failure, an abort of `runevm` on a corrupt C
  heap, once in about 25,000 compiles under load.
