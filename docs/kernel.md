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
signal`) reaches the kernel as `SIGINT`, which it gives to the engine: the
cell ends with `Interrupt`, and the session goes on.

## Limits

* POSIX only: the kernel starts its engine with `fork` and two pipes as the
  engine's descriptors 3 and 4. On Windows, where neither is, the engine's
  `--engine-connect` is the channel to use, and the kernel does not use it
  yet.
* No widgets or comms, and no debugger (`debug_request`). A type's own
  renderers registered by its type, as `addPrettyPrinter` registers a
  printer, are not built: a cell's rich output is the HTML of its values
  and what it shows with `Display`.
* `history_request` is answered empty.

## Tests

`tests/kernel/run.sh` (`make test-kernel`) drives the kernel with a client
written from Jupyter's messaging specification with Python's standard
library: the heartbeat, `kernel_info`, executions with their results as
text and HTML, streams, a compile error, an uncaught exception,
`is_complete`, `complete`, `inspect`, input from the notebook, an
interrupt, and a shutdown. Where Python's `jupyter_client` is installed,
`tests/kernel/notebook_client.py` does the same through it.
