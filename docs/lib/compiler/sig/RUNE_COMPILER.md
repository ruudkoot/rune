# signature RUNE_COMPILER

[Compiler](../README.md) &rsaquo; **RUNE_COMPILER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 17 of 17 entries documented |
| Tests | not listed |
| Source | [lib/compiler/api/compiler\_sig.sml](../../../../lib/compiler/api/compiler_sig.sml) |

## Synopsis

```sml
signature RUNE_COMPILER
structure RuneCompiler :> RUNE_COMPILER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`RuneCompiler`](../str/RuneCompiler.md) | Ordered static compilation with explicit execution and artifact I/O. | [lib/compiler/api/compiler.sml](../../../../lib/compiler/api/compiler.sml) |

The reusable Rune compiler. Compilation and queries are static;
execution is an explicit operation on a compiled unit.

## Interface

<pre>
signature RUNE_COMPILER =
sig
  type <a href="#type-session">session</a>
  type <a href="#type-compiled">compiled</a>
  type <a href="#type-diagnostic">diagnostic</a> = {<a href="#fld-diagnostic.severity">severity</a> : string, <a href="#fld-diagnostic.file">file</a> : string, <a href="#fld-diagnostic.start">start</a> : int, <a href="#fld-diagnostic.stop">stop</a> : int,
                     <a href="#fld-diagnostic.line">line</a> : int, <a href="#fld-diagnostic.column">column</a> : int, <a href="#fld-diagnostic.message">message</a> : string}
  exception <a href="#exn-failed">Failed</a> of diagnostic list
  exception <a href="#exn-closed">Closed</a>
  val <a href="#val-version">version</a> : string
  val <a href="#val-session">session</a> : {<a href="#fld-session.lib">lib</a> : string option, <a href="#fld-session.flags">flags</a> : string list} -&gt; session
  val <a href="#val-close">close</a> : session -&gt; unit
  val <a href="#val-compiletext">compileText</a> : session * {<a href="#fld-compiletext.file">file</a> : string, <a href="#fld-compiletext.text">text</a> : string} -&gt; compiled
  val <a href="#val-compilefile">compileFile</a> : session * string -&gt; compiled
  val <a href="#val-readunit">readUnit</a> : session * string -&gt; compiled
  val <a href="#val-readmid">readMid</a> : session * {<a href="#fld-readmid.basis">basis</a> : string, <a href="#fld-readmid.mid">mid</a> : string} -&gt; compiled
  val <a href="#val-run">run</a> : compiled -&gt; unit
  val <a href="#val-writeunit">writeUnit</a> : compiled * string -&gt; unit
  val <a href="#val-writemid">writeMid</a> : compiled * string -&gt; unit
  val <a href="#val-writeprogram">writeProgram</a> : compiled list * string -&gt; unit
  val <a href="#val-typeat">typeAt</a> : session * {<a href="#fld-typeat.file">file</a> : string, <a href="#fld-typeat.offset">offset</a> : int} -&gt; string option
end
</pre>

### <a name="type-session"></a>`session`

```sml
type session
```

An independent ordered compilation context.

### <a name="type-compiled"></a>`compiled`

```sml
type compiled
```

A unit's checked basis, bytecode, Mid and source snapshot.

### <a name="type-diagnostic"></a>`diagnostic`

```sml
type diagnostic = {severity : string, file : string, start : int, stop : int,
                   line : int, column : int, message : string}
```

A diagnostic uses UTF-8 byte offsets in its source snapshot; line and
column are one-based.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-diagnostic.severity"></a>`severity` | `string` |  |
| <a name="fld-diagnostic.file"></a>`file` | `string` |  |
| <a name="fld-diagnostic.start"></a>`start` | `int` |  |
| <a name="fld-diagnostic.stop"></a>`stop` | `int` |  |
| <a name="fld-diagnostic.line"></a>`line` | `int` |  |
| <a name="fld-diagnostic.column"></a>`column` | `int` |  |
| <a name="fld-diagnostic.message"></a>`message` | `string` |  |

### <a name="exn-failed"></a>`Failed`

```sml
exception Failed of diagnostic list
```

A compile or artifact operation failed with these diagnostics.

### <a name="exn-closed"></a>`Closed`

```sml
exception Closed
```

An operation requires an open compiler context.

### <a name="val-version"></a>`version`

```sml
val version : string
```

The compiler implementation version.

### <a name="val-session"></a>`session`

```sml
val session : {lib : string option, flags : string list} -> session
```

`session {lib, flags}` constructs an independent ordered context.

`NONE` selects the
language's initial basis; `SOME root` selects the Basis and requested
libraries under `root`. No absolute library path is built in.

Supported flags are `--target=registers`, `--target=stack`,
`--allow-prim`, `--unicode`, `--unicode=utf8`, `--unicode=latin1` and
`--library NAME`. Unknown flags raise [`Failed`](#exn-failed). The defaults are
register bytecode, ASCII source and no additional libraries.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-session.lib"></a>`lib` | `string option` |  |
| <a name="fld-session.flags"></a>`flags` | `string list` |  |

### <a name="val-close"></a>`close`

```sml
val close : session -> unit
```

`close session` releases its retained compilation history.

Repeated
calls do nothing. Operations requiring the context then raise [`Closed`](#exn-closed);
immutable compiled artifacts can still be written to disk.

### <a name="val-compiletext"></a>`compileText`

```sml
val compileText : session * {file : string, text : string} -> compiled
```

`compileText (session, {file, text})` compiles text and appends a unit
to the context's ordered history on success.

It uses the context's source mode.
Text is already decoded: Unicode text is UTF-8, also when source
files are Latin-1. Failure leaves the preceding history unchanged.
No user declarations, dynamic loads or compiler hooks are executed.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-compiletext.file"></a>`file` | `string` |  |
| <a name="fld-compiletext.text"></a>`text` | `string` |  |

### <a name="val-compilefile"></a>`compileFile`

```sml
val compileFile : session * string -> compiled
```

`compileFile (session, file)` reads a file in the configured source
mode and compiles it as [`compileText`](#val-compiletext) does.

### <a name="val-readunit"></a>`readUnit`

```sml
val readUnit : session * string -> compiled
```

`readUnit (session, file)` imports a unit and its checked basis/source
companions.

Its required units must already be available in the
context. For older CLI artifacts without a source companion, matching
original source must be available; mismatched source is rejected.

### <a name="val-readmid"></a>`readMid`

```sml
val readMid : session * {basis : string, mid : string} -> compiled
```

`readMid (session, {basis, mid})` reads a checked basis and unit Mid,
then generates the context's selected bytecode target.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-readmid.basis"></a>`basis` | `string` |  |
| <a name="fld-readmid.mid"></a>`mid` | `string` |  |

### <a name="val-run"></a>`run`

```sml
val run : compiled -> unit
```

`run unit` links and executes a unit with the runtime dependencies it
needs.

Unrelated units are not executed. Dependencies run once per
context; calling [`run`](#val-run) again executes this unit again. User exceptions
propagate unchanged, and a failed initializer can be retried.

Session execution uses separate unit namespaces, including for
identical input units. Artifact output retains deterministic portable
identities. Use this API to import units that depend on session units;
raw runtime loading does not rewrite their dependency identities.

RuneVM is required, and execution with libraries requires a host
program built with `--units` so its Basis identities can be shared.
A whole-program host raises [`Fail`](../../basis/sig/GENERAL.md#exn-fail) before linking any dependencies.
Native SML hosts support static compilation and
artifact output but raise [`Fail`](../../basis/sig/GENERAL.md#exn-fail) for execution. Host library units
captured when the adapter starts are reused; normal build order must
initialize those libraries before clients invoke the API. Their source
provenance must match the configured library; differing or unavailable
provenance raises [`Fail`](../../basis/sig/GENERAL.md#exn-fail) before dependencies execute. Explicit unit or
Mid imports cannot replace a colliding host library implicitly.
Replacing a shared host unit through raw runtime linking invalidates
its provenance; later runs needing it raise [`Fail`](../../basis/sig/GENERAL.md#exn-fail) before execution.

### <a name="val-writeunit"></a>`writeUnit`

```sml
val writeUnit : compiled * string -> unit
```

`writeUnit (unit, file)` writes a unit and its companion basis, Mid
and source metadata (`.rbi`, `.rbm`, `.rbs`).

Each file is replaced
atomically; the source integrity record is published last. Readers
reject a mismatched set.

### <a name="val-writemid"></a>`writeMid`

```sml
val writeMid : compiled * string -> unit
```

`writeMid (unit, file)` writes the unit's Mid representation.

### <a name="val-writeprogram"></a>`writeProgram`

```sml
val writeProgram : compiled list * string -> unit
```

`writeProgram (units, file)` links selected units, library finalizers
and required dependencies into a program file.

Units must belong to
one context. It does not execute the program.

### <a name="val-typeat"></a>`typeAt`

```sml
val typeAt : session * {file : string, offset : int} -> string option
```

`typeAt (session, {file, offset})` returns the checked type of an
annotated value occurrence, or `NONE` where none exists.

The offset is a UTF-8 byte offset in the latest ordered history.
The innermost occurrence is selected.
This initial implementation performs fresh static elaboration; it
does not retain a resident semantic snapshot or execute user code.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-typeat.file"></a>`file` | `string` |  |
| <a name="fld-typeat.offset"></a>`offset` | `int` |  |

---

<sub>Generated by runedoc from lib/compiler/api/compiler\_sig.sml; do not edit.</sub>
