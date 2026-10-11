# The REPL engine's protocol, version 1

`rune-repl --engine` is the REPL's session for a front in another process
-- an editor, the Jupyter kernel, a debug adapter -- in the place of the
terminal ([plans/repl.md](plans/repl.md), D20 and M10). It speaks JSON-RPC
2.0 in rune-ide's manner ([rune-ide's docs/ide-protocol.md](../../rune-ide/docs/ide-protocol.md)),
and evaluates as the REPL does: each `eval` is an entry, compiled against
the session and run, its declarations extending it.

## The channel

The protocol has a channel of its own, so that what the program writes
stays on its standard output and error:

* **`rune-repl --engine`** reads messages on the descriptor 3 and writes them
  on 4, which a front that starts the engine as its child gives it
  (`tests/repl-protocol/run.py` does, with two pipes).
* **`rune-repl --engine-connect PORT`** connects to `127.0.0.1:PORT` and
  writes the token in `RUNE_ENGINE_TOKEN` as its first line, then speaks
  the protocol on the connection: for a front that cannot pass
  descriptors (Windows). The front listens only on `127.0.0.1`, makes a
  token of at least 128 random bits, compares it in constant time, and
  closes a connection whose first line is not the token or looks like
  HTTP.

Messages are framed one to a line, UTF-8, or behind `Content-Length`
headers, as the Language Server Protocol frames them: the first byte the
front sends chooses (`C` for headers), and the engine answers in the same
framing. Batches are read; the engine sends none.

The program's standard output and error stay on the engine's descriptors 1
and 2, pipes the front drains. The engine flushes them before it writes a
message, so a front that drains them before it reads one keeps what the
program printed in order with the answers. `print` writes through the VM's
slot for the descriptor 1, as `TextIO.stdOut` does.

## Requests

`initialize` comes first; before it every other method but `ping` is
refused. Positions are bytes of the text the request gave, from 0.

| Method | Parameters | Result |
|---|---|---|
| `initialize` | `{protocol: 1, width?: number}` | `{protocol: 1, implementation: string, methods: string[]}` |
| `ping` | any | the same |
| `eval` | `{text}` | an *outcome* |
| `use` | `{path}` | an *outcome* |
| `reload` | `{force?: boolean}` | an *outcome*; `force` is `:reload!` |
| `isComplete` | `{text}` | `{status: "complete" \| "incomplete" \| "invalid", indent?: number}` |
| `complete` | `{text, offset}` | `{start, candidates: string[]}` |
| `inspect` | `{name}` | `{info: string \| null, doc: string \| null}`: what `:info` and `:doc` say |
| `typeAt` | `{text, offset}` | `{name, type, start, stop}` of the innermost variable at the offset, or `null`; the text elaborated against the session and not run |
| `check` | `{text}` | `{diagnostics}` of the text elaborated against the session and not run |
| `value/children` | `{handle}` | `{label, shown, handle, more}[]`: a value opened a level |
| `value/release` | `{handles: number[]}` | `null` |
| `interrupt` | `{}` | `null`: nothing runs while the engine can read it (below) |
| `shutdown` | `{}` | `null`, and the engine ends |

An *outcome* is

```
{ok: boolean,
 bindings: [{name, type, shown, handle}],
 declared: string[],              -- datatypes, types, exceptions, structures, as the REPL says them
 messages: string[],              -- what the REPL would have said (reload's)
 diagnostics: [diagnostic],
 exception: {name, message, trace: [{function, file, line, column}]} | null}
```

`shown` is the value laid out at the width `initialize` gave (80), as the
REPL prints it, with its limits (`printDepth` and the rest). A *diagnostic*
is rune-ide's: `{severity: "error" | "warning", message, path, startByte,
endByte, range, rendered}`, `range` Monaco's (`startLineNumber`,
`startColumn`, `endLineNumber`, `endColumn`, from 1, columns in UTF-16
units) or `null`, `rendered` the text the compiler would print with its
excerpt. An entry's source is named `stdIn#k`, the k-th entry.

A handle names a value's document until `value/release`; `value/children`
gives its parts -- a list's items, a tuple's components, a record's fields
by their labels, a constructor's argument -- each with a handle of its own
and whether it has parts.

## From the engine

* `status` `{state: "busy" | "idle"}`, a notification around each request.
* `input` `{}`, a request of the engine's own when the program reads its
  standard input: its result is the text to give the program, a string,
  or `null` for the end of the input. While it waits, the engine refuses
  any request but the answer, with `-32000`.

## Interrupts

The engine has no thread: while an `eval` runs, it reads nothing. A front
interrupts it with `SIGINT` to its process, as Ctrl-C does at the terminal;
the evaluation ends with the exception `Interrupt`, and the session goes on.
Idle, an interrupt is dropped. `$/cancelRequest` notifications are read and
ignored, there being nothing to cancel by the time one is read.

## Errors

As rune-ide's: `-32001` a protocol of another version, `-32002` a request
before `initialize`, `-32601` an unknown method, `-32602` parameters of the
wrong kind, `-32700` text that is no JSON (with a `null` id), `-32800` an
evaluation the user interrupted, `-32000` a failure of the engine. Text
that is no JSON does not end the session.

## Tests

`tests/repl-protocol/run.py` (`make test-repl-protocol`) plays each
`NAME.script` to the engine and wants `NAME.expected`: evaluation, values
opened and released, diagnostics, an exception's trace, completeness,
completion, inspection, the type at a position, a check, a file used, the
program's output in order with the answers, the program's input, an
interrupt, the protocol's errors, and `Content-Length` framing.
