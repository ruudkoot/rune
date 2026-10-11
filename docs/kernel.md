# The Jupyter kernel

`rune-kernel` runs Standard ML in Jupyter's notebooks and consoles
([plans/repl.md](plans/repl.md), D21 and M11). It is a bridge in SML: it
owns the kernel's five sockets -- lib/jupyter, over lib/zmtp's ZMTP 3.1
and lib/digest's HMAC-SHA256 -- and drives the REPL's engine as its child
(`rune-repl --engine`, [repl-protocol.md](repl-protocol.md)), so that a
crash of the code a cell runs takes the engine and not the kernel, which
starts another and says so.

## Installing

```
bin/rune-kernel --install --user          # ~/.local/share/jupyter/kernels/rune
bin/rune-kernel --install --prefix DIR    # DIR/share/jupyter/kernels/rune
```

`make install` installs `rune-kernel` beside `rune` where it is built
(`make kernel`); `rune-kernel --install --user` then writes a kernelspec
that runs the installed one.

writes the kernelspec: `argv` runs `runevm` on `rune-kernel.rbc` with the
REPL's image beside it, the language is `sml`, and `interrupt_mode` is
`signal`. `jupyter notebook`, `jupyter lab` and `jupyter console --kernel
rune` then offer "Rune (Standard ML)".

## What a cell does

A cell is an entry of the REPL: its declarations compiled against those
of the cells run before it and run, a `;` added after the last where it
has none. What the program writes on its standard output and error comes
as the cell's stream output while it runs; what the REPL says of the
declarations -- `val x = 3 : int`, `datatype t = ...` -- is the cell's
result, as text and as HTML in the palette's styles (its roles' rules with
it, light and dark); a compile error is the cell's error with the line it
is about, and an uncaught exception its error with the frames it left. A
read of `TextIO.stdIn` asks the notebook for a line. `Display.display`
shows an output in several MIME types (`[("text/html", ...), ("text/plain",
...)]`) as the cell's display data, `Display.displayAs` and `Display.update`
one that a later update replaces, and `Display.clear` clears the cell.

Tab completes as at the REPL, and Shift-Tab shows what `:info` and `:doc`
say of the name under the cursor. Jupyter's interrupt (`interrupt_mode
signal`) reaches the kernel as `SIGINT` -- on Windows as the event
`JPY_INTERRUPT_EVENT` names, which Jupyter sets -- and the kernel gives it to
the engine: the cell ends with `Interrupt`, and the session goes on.

The engine is the kernel's child on its descriptors 3 and 4 where the system
forks, and on Windows on a connection of the loopback that the kernel
listens on, whose first line is a token only the two know
(`--engine-connect`, `src/front/engine.sml`; `RUNE_ENGINE_CONNECT` asks for
it elsewhere too).

## The debugger

The kernel says it has one (`kernel_info`'s `debugger`), and JupyterLab's
debugger drives it as it drives ipykernel's: a `debug_request` on the
control channel is a request of the Debug Adapter Protocol, which the kernel
answers from the engine's debugger as [dap.md](dap.md)'s adapter does
(`src/dap/translate.sml`; [repl-protocol.md](repl-protocol.md), *The
debugger*), and a stop is a `debug_event` on iopub. The control channel is
answered while a cell runs (`Jupyter.request`'s `idle`), so that a cell
stopped at a breakpoint can be looked into and sent on.

* **Cells as files.** Once a debugger is attached, a cell is compiled under
  the file its code names -- `tmpFilePrefix`, the code's MurmurHash2
  (`lib/digest`, the seed ipykernel's), `tmpFileSuffix` (`debugInfo`) --
  into which the kernel writes it (`dumpCell`): the notebook works out the
  same name for a cell to set its breakpoints, and finds the cell of a
  frame by it.
* **JupyterLab's own.** `debugInfo` (whether a debugger is attached, the
  hash and the files, the breakpoints, the stopped thread), `dumpCell`,
  `source` (a file's text), `inspectVariables` (empty: the session's values
  are the notebook's own) and `modules` (none).
* **Interrupts.** With a debugger attached, the engine pauses at the
  front's `SIGINT`; the notebook's interrupt is told from a pause the
  debugger asked for, and ends the cell with `Interrupt` as before.

## Limits

* No widgets or comms. A type's own
  renderers registered by its type, as `addPrettyPrinter` registers a
  printer, are not built: a cell's rich output is the HTML of its values
  and what it shows with `Display`.
* `history_request` is answered empty.

## Tests

`tests/kernel/run.sh` (`make test-kernel`) drives the kernel with a client
written from Jupyter's messaging specification with Python's standard
library: the heartbeat, `kernel_info`, executions with their results as
text and HTML, streams, a compile error, an uncaught exception,
`is_complete`, `complete`, `inspect`, input from the notebook, the
debugger -- `debugInfo`, a cell dumped under the name its hash gives,
a breakpoint in it, the stop as a `debug_event` while the cell runs, its
frames, variables and an expression in the frame, `continue` -- an
interrupt, and a shutdown. Where Python's `jupyter_client` is installed,
`tests/kernel/notebook_client.py` does the same through it. `make
test-kernel` runs both again with the engine on a connection, and `make
test-windows` runs the client on Windows, where Windows has a Python, against
`runevm.exe`'s kernel, interrupting it by its event
(`tests/kernel/windows.py`).
