# REPL and terminal race fixes, 2026-10-29

Worktree `repl-terminal-reports`, branch `fix/repl-terminal-reports`, based
on freshly fetched `origin/master` at `2d7b13370`. This starts from master;
no implementation from an earlier repair attempt was reused.

## Changes

1. **Resize wake-ups.** `runtime/sys/sys_posix.c` writes a nonblocking pipe
   from the resize handler and polls it alongside terminal input. A signal
   delivered while the editor draws therefore wakes its next read. The
   handler preserves `errno`, a full pipe already represents a wake-up,
   and both descriptors close on exec. A child recreates the pipe before
   using it, so it cannot consume its parent's notification; the resize
   counter also covers a child's signal before that recreation. Resume
   after a terminal stop uses the same notification path.
2. **REPL type-ahead.** `ReplFront.readEntry` retains the editor's quiet
   terminal for every accepted entry and records that it owns it. Commands
   and blank entries no longer briefly enable echo or translate Enter to
   Ctrl-J. `:sh` and `:edit` run through `shellLike`, giving the external
   program cooked input and restoring quiet mode afterwards, including on
   exceptions. The existing standard-input wrapper uses the same ownership.
3. **Resize probe readiness.** `tests/terminal/keys.sml` captures
   `Terminal.resizes ()` before printing its initial size, so the driver
   cannot resize before the signal handler and baseline are ready.

The original `edit-complete` screen and its early wait remain unchanged.
Waiting longer for the input would only hide some schedules of the runtime
bug.

## Regression evidence

`terminal/races` includes a native system-layer probe and a PTY REPL session:

* `tests/terminal/resize-read.c` delivers a signal before an indefinite
  read, and injects another at the `poll` boundary. A deadline makes a lost
  wake-up a bounded failure. It also exercises a burst large enough to fill
  the notification pipe, fork isolation, and input queued alongside a
  resize. This is compiled with the `poll` call redirected to the fixture;
  fortified header inlining is disabled for that fixture only.
* The REPL uses a source file that prints a readiness marker and waits on
  a separate file. While `:use` is still running, the driver checks that
  input is quiet, types `val typedAhead = 40 + 2;`, and releases the command.
  The expected result is `val typedAhead = 42 : int`. The same session
  checks that a shell and external editor receive cooked input and return
  to the REPL successfully. Input sent while the shell owns the terminal
  belongs to that shell, so the test waits for the REPL prompt afterwards.
* `terminal/edit-resize-input` sends the tail of an entry after narrowing
  the terminal, then widens it without sending any key. Both drawings must
  retain the entire entry.

The original runtime failed the native probe with
`resize did not wake a read without keys`. The original REPL image failed
the PTY assertion `command did not keep type-ahead quiet`. Both pass with
the fixes. A mutation that disables the pipe in `poll` while retaining the
counter check fails at the injected wait boundary, proving that merely
narrowing the race is insufficient. The native probe also passes as C99
and under ASan/UBSan with leak checking. The initial sanitizer attempt was
blocked by LeakSanitizer's inability to inspect the sandbox's processes;
the unrestricted rerun passed, and both receipts are retained.

The abbreviated historical `repl-debug` failure at `7a0afbf0c` still lacks
enough transcript to establish its cause, as the original report notes.
The current debugger scenario passes the loaded repetitions below; that
does not retrospectively prove the cause of that older occurrence.

Receipts are retained in `build/repl-terminal-evidence/` in the worktree.
The first suite run exposed a synchronization error in the new shell test;
its failed receipt is retained in `focused.log`. After correcting that
test, the two new cases and their preparation/canaries passed (8/8), and
the REPL tier passed (9/9).

## Acceptance

* `make check JOBS=8`: 21,255 PASS, three SKIP, zero FAIL. The skips were
  the two documented native-interrupt cases and the optional pinned native
  GMP dependency, which was not installed in this fresh worktree.
* Complete terminal tier: 30/30 PASS (`terminal-final.log`). REPL tier:
  9/9 PASS (`focused.log`).
* `bin/rune-test run terminal/edit-complete terminal/edit-resize-input
  terminal/term-resize terminal/repl-debug terminal/repl-colours
  terminal/races --repeat 40 --until-fail --under-load -j 4`: all 40 rounds
  passed, 480/480 checks including preparation and canaries. Each of the
  six terminal cases passed 40 times. This ran alongside the fresh full
  check's compiler builds; `load.log` retains all 40 results.
* `make vm-asan JOBS=4` and `bin/rune-suite --vm bin/runevm-stack-asan`:
  915/915 PASS.
* `make test-stress JOBS=8`: 3,238/3,238 PASS.
* `make windows JOBS=4`: all four VMs built.
* `make test-windows JOBS=8`: passed. Main inventory: 2,549 PASS, four
  optional Win32 SDK cases skipped because `RUNEFFI_WINDOWS_SDK` and
  `RUNEFFI_MSVC_INCLUDE` were not configured. Windows Basis matrix:
  1,934/1,934 PASS. Windows DAP and kernel protocol checks passed.
* `make docs JOBS=4`: passed; generated documentation was unchanged.

Implementation/test source hashes are recorded in
`build/repl-terminal-evidence/sources.sha256` and were checked unchanged
after acceptance. The validation build reports version `2d7b13370-dirty`;
the commit afterwards records the same implementation and test sources.
