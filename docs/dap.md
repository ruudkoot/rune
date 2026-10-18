# rune-dap: the Debug Adapter Protocol for Standard ML

`rune-repl --dap` -- `bin/rune-dap` -- is the debugger of an editor that
speaks the Debug Adapter Protocol: VS Code's, Emacs's dape, Neovim's
nvim-dap ([plans/repl.md](plans/repl.md), D22 and M12). The editor speaks DAP
to it on its standard input and output; it drives the REPL's engine, a
child of its own (`rune-repl --engine`, [repl-protocol.md](repl-protocol.md)),
as the Jupyter kernel does ([kernel.md](kernel.md)), and the program runs
in the engine's session with the REPL's debugger ([repl.md](repl.md), *The
debugger*). It is SML over `lib/dap` (`src/dap/adapter.sml`), with what it
shares with the kernel's debugger in `src/dap/translate.sml`.

## A session

* `launch` names the program: `{"program": "path/to/main.sml"}`, a file
  the engine uses once the editor has set its breakpoints
  (`configurationDone`). It ends where the file's last declaration ends,
  with `exited` -- 1 where one did not compile or raised what nothing
  handled, 0 else -- and `terminated`; its errors and an uncaught exception
  are `output` on `stderr`.
* `setBreakpoints` by a file's path, as the program names it: the path
  given to `launch`, or one of the files it uses. A breakpoint is
  `verified` where code begins its line already; one of a file not used
  yet stops once it is.
* `setExceptionBreakpoints`: the filters `uncaught` (a raise nothing of the
  program's handles) and `all` (every raise).
* A stop is `stopped`, with the reason `breakpoint`, `step`, `pause` or
  `exception` (and the exception's message); `stackTrace`, `scopes` (the
  frame's variables), `variables` (a value's parts a level at a time) and
  `evaluate` (in the frame) answer from it -- a frame's column in UTF-16
  units, as DAP counts them by default -- and `continue`, `next`,
  `stepIn` and `stepOut` end it. `evaluate` while nothing is stopped is an
  entry of the session.
* `pause` is `SIGINT` to the engine, which pauses rather than interrupts
  (the engine's `debug/configure`). There is one thread.
* What the program writes is `output`, on `stdout` and `stderr` as it wrote
  it; the program reads no input (the end of it).
* `disconnect` and `terminate` end the engine, at a stop too.

While the program runs the engine reads nothing: `threads` and `pause` are
answered by the adapter itself, and what is for the engine is sent when the
program stops or ends.

## An editor's configuration

VS Code, in a `launch.json`, with an extension that names `rune-repl --dap`
as the adapter of the type `rune`:

```json
{ "type": "rune", "request": "launch", "name": "Debug", "program": "${file}" }
```

## Tests

`tests/dap/run.py` (`make test-dap`) drives the adapter as an editor does,
with Python's standard library: `prog.sml` stopped at a breakpoint, its
frames, its variables, an expression in its frame and one that does not
elaborate, a step, a stop at a raise its own handler takes, its output and
its end; and `loop.sml` paused while it runs, in compiled code, and its
variable at the pause. `make test-dap` runs it again with the engine on a
connection (`RUNE_ENGINE_CONNECT`), as on Windows, and `make test-windows`
on `runevm.exe` (`--windows`).

## Limits

No conditional breakpoints, logpoints or data breakpoints; the variables
are a frame's, not the session's top level.
