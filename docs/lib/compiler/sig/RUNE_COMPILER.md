# signature RUNE_COMPILER

[Compiler](../README.md) &rsaquo; **RUNE_COMPILER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 86 of 86 entries documented |
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
  structure <a href="#str-syntax">Syntax</a> :
  sig
    type <a href="#type-syntax.t">t</a>
    type <a href="#type-syntax.fixities">fixities</a>
    val <a href="#val-syntax.initial">initial</a> : fixities
    type <a href="#type-syntax.piece">piece</a> = {<a href="#fld-syntax.piece.kind">kind</a>:string,<a href="#fld-syntax.piece.start">start</a>:int,<a href="#fld-syntax.piece.stop">stop</a>:int,<a href="#fld-syntax.piece.text">text</a>:string}
    type <a href="#type-syntax.event">event</a> = {<a href="#fld-syntax.event.kind">kind</a>:string,<a href="#fld-syntax.event.start">start</a>:int,<a href="#fld-syntax.event.stop">stop</a>:int,<a href="#fld-syntax.event.values">values</a>:string list}
    type <a href="#type-syntax.work">work</a> = {<a href="#fld-syntax.work.lexedbytes">lexedBytes</a>:int,<a href="#fld-syntax.work.reusedtokens">reusedTokens</a>:int,<a href="#fld-syntax.work.parseddeclarations">parsedDeclarations</a>:int,<a href="#fld-syntax.work.reuseddeclarations">reusedDeclarations</a>:int}
    val <a href="#val-syntax.parse">parse</a> : {<a href="#fld-syntax.parse.file">file</a>:string,<a href="#fld-syntax.parse.text">text</a>:string,<a href="#fld-syntax.parse.mode">mode</a>:string,<a href="#fld-syntax.parse.orpatterns">orPatterns</a>:bool,<a href="#fld-syntax.parse.fixity">fixity</a>:fixities} -&gt; t
    val <a href="#val-syntax.edit">edit</a> : t * {<a href="#fld-syntax.edit.start">start</a>:int,<a href="#fld-syntax.edit.stop">stop</a>:int,<a href="#fld-syntax.edit.text">text</a>:string,<a href="#fld-syntax.edit.fixity">fixity</a>:fixities} -&gt; t
    val <a href="#val-syntax.text">text</a> : t -&gt; string
    val <a href="#val-syntax.fixities">fixities</a> : t -&gt; fixities
    val <a href="#val-syntax.pieces">pieces</a> : t -&gt; piece list
    val <a href="#val-syntax.events">events</a> : t -&gt; event list
    val <a href="#val-syntax.diagnostics">diagnostics</a> : t -&gt; diagnostic list
    val <a href="#val-syntax.work">work</a> : t -&gt; work
  end
  structure <a href="#str-project">Project</a> :
  sig
    type <a href="#type-project.t">t</a>
    type <a href="#type-project.source">source</a> = {<a href="#fld-project.source.file">file</a> : string, <a href="#fld-project.source.annotations">annotations</a> : string list, <a href="#fld-project.source.mode">mode</a> : string, <a href="#fld-project.source.ordinal">ordinal</a> : int}
    type <a href="#type-project.input">input</a> = {<a href="#fld-project.input.file">file</a> : string, <a href="#fld-project.input.text">text</a> : string, <a href="#fld-project.input.mode">mode</a> : string, <a href="#fld-project.input.kind">kind</a> : string, <a href="#fld-project.input.revision">revision</a> : string}
    type <a href="#type-project.buildreference">buildReference</a>={<a href="#fld-project.buildreference.kind">kind</a>:string,<a href="#fld-project.buildreference.value">value</a>:string,<a href="#fld-project.buildreference.start">start</a>:int,<a href="#fld-project.buildreference.stop">stop</a>:int,<a href="#fld-project.buildreference.quoted">quoted</a>:bool}
    type <a href="#type-project.pathcompletion">pathCompletion</a>={<a href="#fld-project.pathcompletion.label">label</a>:string,<a href="#fld-project.pathcompletion.text">text</a>:string,<a href="#fld-project.pathcompletion.kind">kind</a>:string,<a href="#fld-project.pathcompletion.start">start</a>:int,<a href="#fld-project.pathcompletion.stop">stop</a>:int}
    type <a href="#type-project.buildlink">buildLink</a>={<a href="#fld-project.buildlink.kind">kind</a>:string,<a href="#fld-project.buildlink.target">target</a>:string,<a href="#fld-project.buildlink.start">start</a>:int,<a href="#fld-project.buildlink.stop">stop</a>:int}
    val <a href="#val-project.buildsyntax">buildSyntax</a> : {<a href="#fld-project.buildsyntax.file">file</a>:string,<a href="#fld-project.buildsyntax.text">text</a>:string} -&gt; {references:buildReference list,diagnostics:diagnostic list}
    val <a href="#val-project.buildlinks">buildLinks</a> : session * {<a href="#fld-project.buildlinks.file">file</a>:string,<a href="#fld-project.buildlinks.text">text</a>:string,<a href="#fld-project.buildlinks.variables">variables</a>:(string*string) list,<a href="#fld-project.buildlinks.windows">windows</a>:bool} -&gt; buildLink list
    val <a href="#val-project.pathcompletions">pathCompletions</a> : session * {<a href="#fld-project.pathcompletions.file">file</a>:string,<a href="#fld-project.pathcompletions.text">text</a>:string,<a href="#fld-project.pathcompletions.offset">offset</a>:int,<a href="#fld-project.pathcompletions.variables">variables</a>:(string*string) list,<a href="#fld-project.pathcompletions.windows">windows</a>:bool} -&gt;
      {items:pathCompletion list,isIncomplete:bool}
    val <a href="#val-project.read">read</a> : session * {<a href="#fld-project.read.file">file</a> : string, <a href="#fld-project.read.variables">variables</a> : (string * string) list,
                          <a href="#fld-project.read.overlays">overlays</a> : {file : string, text : string} list, <a href="#fld-project.read.windows">windows</a> : bool} -&gt; t
    val <a href="#val-project.sources">sources</a> : t -&gt; source list
    val <a href="#val-project.inputs">inputs</a> : t -&gt; input list
    val <a href="#val-project.libraries">libraries</a> : t -&gt; string list
    val <a href="#val-project.cachedirectories">cacheDirectories</a> : t -&gt; string list
    val <a href="#val-project.fingerprint">fingerprint</a> : t -&gt; string
  end
  structure <a href="#str-analysis">Analysis</a> :
  sig
    type <a href="#type-analysis.t">t</a>
    type <a href="#type-analysis.snapshot">snapshot</a>
    type <a href="#type-analysis.checkpoint">checkpoint</a>
    type <a href="#type-analysis.input">input</a>={<a href="#fld-analysis.input.file">file</a>:string,<a href="#fld-analysis.input.text">text</a>:string,<a href="#fld-analysis.input.mode">mode</a>:string,<a href="#fld-analysis.input.annotations">annotations</a>:string list,<a href="#fld-analysis.input.revision">revision</a>:string}
    type <a href="#type-analysis.location">location</a>={<a href="#fld-analysis.location.file">file</a>:string,<a href="#fld-analysis.location.start">start</a>:int,<a href="#fld-analysis.location.stop">stop</a>:int}
    type <a href="#type-analysis.occurrence">occurrence</a>={<a href="#fld-analysis.occurrence.unit">unit</a>:string,<a href="#fld-analysis.occurrence.file">file</a>:string,<a href="#fld-analysis.occurrence.start">start</a>:int,<a href="#fld-analysis.occurrence.stop">stop</a>:int,<a href="#fld-analysis.occurrence.kind">kind</a>:string,<a href="#fld-analysis.occurrence.name">name</a>:string,<a href="#fld-analysis.occurrence.path">path</a>:string list,
      <a href="#fld-analysis.occurrence.binding">binding</a>:string option,<a href="#fld-analysis.occurrence.definition">definition</a>:location option,<a href="#fld-analysis.occurrence.declaration">declaration</a>:location option,<a href="#fld-analysis.occurrence.isdefinition">isDefinition</a>:bool,<a href="#fld-analysis.occurrence.derived">derived</a>:bool}
    type <a href="#type-analysis.fact">fact</a>={<a href="#fld-analysis.fact.unit">unit</a>:string,<a href="#fld-analysis.fact.file">file</a>:string,<a href="#fld-analysis.fact.start">start</a>:int,<a href="#fld-analysis.fact.stop">stop</a>:int,<a href="#fld-analysis.fact.ty">ty</a>:string,<a href="#fld-analysis.fact.derived">derived</a>:bool,<a href="#fld-analysis.fact.constructors">constructors</a>:string list,<a href="#fld-analysis.fact.arguments">arguments</a>:string list list}
    type <a href="#type-analysis.typedefinition">typeDefinition</a>={<a href="#fld-analysis.typedefinition.id">id</a>:string,<a href="#fld-analysis.typedefinition.definition">definition</a>:location option,<a href="#fld-analysis.typedefinition.declaration">declaration</a>:location option,<a href="#fld-analysis.typedefinition.implementation">implementation</a>:location option}
    type <a href="#type-analysis.candidate">candidate</a>={<a href="#fld-analysis.candidate.name">name</a>:string,<a href="#fld-analysis.candidate.kind">kind</a>:string,<a href="#fld-analysis.candidate.detail">detail</a>:string option,<a href="#fld-analysis.candidate.arguments">arguments</a>:string list list,<a href="#fld-analysis.candidate.definition">definition</a>:location option}
    type <a href="#type-analysis.call">call</a>={<a href="#fld-analysis.call.name">name</a>:string,<a href="#fld-analysis.call.path">path</a>:string list,<a href="#fld-analysis.call.detail">detail</a>:string,<a href="#fld-analysis.call.arguments">arguments</a>:string list list,<a href="#fld-analysis.call.argument">argument</a>:int,<a href="#fld-analysis.call.parameter">parameter</a>:int}
    type <a href="#type-analysis.typehint">typeHint</a>={<a href="#fld-analysis.typehint.name">name</a>:string,<a href="#fld-analysis.typehint.position">position</a>:int,<a href="#fld-analysis.typehint.ty">ty</a>:string,<a href="#fld-analysis.typehint.binding">binding</a>:string,<a href="#fld-analysis.typehint.location">location</a>:location}
    exception <a href="#exn-analysis.cancelled">Cancelled</a>
    exception <a href="#exn-analysis.busy">Busy</a>
    val <a href="#val-analysis.create">create</a> : session * {<a href="#fld-analysis.create.context">context</a>:string} -&gt; t
    val <a href="#val-analysis.close">close</a> : t -&gt; unit
    val <a href="#val-analysis.check">check</a> : t * {<a href="#fld-analysis.check.project">project</a>:Project.t option,<a href="#fld-analysis.check.inputs">inputs</a>:input list,<a href="#fld-analysis.check.cancelled">cancelled</a>:unit-&gt;bool} -&gt; snapshot
    val <a href="#val-analysis.checkpoint">checkpoint</a> : t -&gt; checkpoint
    val <a href="#val-analysis.restore">restore</a> : t * checkpoint -&gt; unit
    val <a href="#val-analysis.id">id</a> : snapshot -&gt; string
    val <a href="#val-analysis.context">context</a> : snapshot -&gt; string
    val <a href="#val-analysis.project">project</a> : snapshot -&gt; string option
    val <a href="#val-analysis.inputs">inputs</a> : snapshot -&gt; input list
    val <a href="#val-analysis.unitat">unitAt</a> : snapshot * {<a href="#fld-analysis.unitat.ordinal">ordinal</a>:int} -&gt; string option
    val <a href="#val-analysis.syntaxat">syntaxAt</a> : snapshot * {<a href="#fld-analysis.syntaxat.ordinal">ordinal</a>:int} -&gt; Syntax.t option
    val <a href="#val-analysis.dependencies">dependencies</a> : snapshot -&gt; input list
    val <a href="#val-analysis.diagnostics">diagnostics</a> : snapshot -&gt; diagnostic list
    val <a href="#val-analysis.occurrences">occurrences</a> : snapshot -&gt; occurrence list
    val <a href="#val-analysis.types">types</a> : snapshot -&gt; typeDefinition list
    val <a href="#val-analysis.facts">facts</a> : snapshot -&gt; fact list
    val <a href="#val-analysis.work">work</a> : snapshot -&gt; {<a href="#fld-analysis.work.checked">checked</a>:int,<a href="#fld-analysis.work.reused">reused</a>:int}
    val <a href="#val-analysis.typeat">typeAt</a> : snapshot * {<a href="#fld-analysis.typeat.file">file</a>:string,<a href="#fld-analysis.typeat.offset">offset</a>:int} -&gt; string option
    val <a href="#val-analysis.typeatoccurrence">typeAtOccurrence</a> : snapshot * {<a href="#fld-analysis.typeatoccurrence.ordinal">ordinal</a>:int,<a href="#fld-analysis.typeatoccurrence.offset">offset</a>:int} -&gt; string option
    val <a href="#val-analysis.typehints">typeHints</a> : snapshot * {<a href="#fld-analysis.typehints.ordinal">ordinal</a>:int,<a href="#fld-analysis.typehints.start">start</a>:int,<a href="#fld-analysis.typehints.stop">stop</a>:int} -&gt; typeHint list
    val <a href="#val-analysis.visibleat">visibleAt</a> : snapshot * {<a href="#fld-analysis.visibleat.ordinal">ordinal</a>:int,<a href="#fld-analysis.visibleat.offset">offset</a>:int,<a href="#fld-analysis.visibleat.path">path</a>:string list} -&gt; candidate list
    val <a href="#val-analysis.signatureat">signatureAt</a> : snapshot * {<a href="#fld-analysis.signatureat.ordinal">ordinal</a>:int,<a href="#fld-analysis.signatureat.offset">offset</a>:int} -&gt; call option
    val <a href="#val-analysis.completionat">completionAt</a> : snapshot * {<a href="#fld-analysis.completionat.ordinal">ordinal</a>:int,<a href="#fld-analysis.completionat.offset">offset</a>:int,<a href="#fld-analysis.completionat.path">path</a>:string list} -&gt;
      {role:string,fields:(string*string) list,candidates:candidate list}
    val <a href="#val-analysis.documentationat">documentationAt</a> : snapshot * location -&gt; string option
  end
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

### <a name="str-syntax"></a>`Syntax`

Lossless editor syntax, separate from the compiler's batch parser.

#### <a name="type-syntax.t"></a>`t`

```sml
type t
```

An immutable syntax snapshot. No mutable compiler annotations escape.

#### <a name="type-syntax.fixities"></a>`fixities`

```sml
type fixities
```

An immutable lexical fixity environment, transferable between files.

#### <a name="val-syntax.initial"></a>`initial`

```sml
val initial : fixities
```

Standard ML's initial fixities.

#### <a name="type-syntax.piece"></a>`piece`

```sml
type piece = {kind:string,start:int,stop:int,text:string}
```

A lossless source piece. start/stop are half-open decoded byte offsets.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-syntax.piece.kind"></a>`kind` | `string` |  |
| <a name="fld-syntax.piece.start"></a>`start` | `int` |  |
| <a name="fld-syntax.piece.stop"></a>`stop` | `int` |  |
| <a name="fld-syntax.piece.text"></a>`text` | `string` |  |

#### <a name="type-syntax.event"></a>`event`

```sml
type event = {kind:string,start:int,stop:int,values:string list}
```

A structural syntax event. Constructor tags, spans, scalar fields and
list lengths distinguish full syntax, including signature constraints.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-syntax.event.kind"></a>`kind` | `string` |  |
| <a name="fld-syntax.event.start"></a>`start` | `int` |  |
| <a name="fld-syntax.event.stop"></a>`stop` | `int` |  |
| <a name="fld-syntax.event.values"></a>`values` | `string list` |  |

#### <a name="type-syntax.work"></a>`work`

```sml
type work = {lexedBytes:int,reusedTokens:int,parsedDeclarations:int,reusedDeclarations:int}
```

Measured work counters for this parse/edit, not elapsed-time estimates.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-syntax.work.lexedbytes"></a>`lexedBytes` | `int` |  |
| <a name="fld-syntax.work.reusedtokens"></a>`reusedTokens` | `int` |  |
| <a name="fld-syntax.work.parseddeclarations"></a>`parsedDeclarations` | `int` |  |
| <a name="fld-syntax.work.reuseddeclarations"></a>`reusedDeclarations` | `int` |  |

#### <a name="val-syntax.parse"></a>`parse`

```sml
val parse : {file:string,text:string,mode:string,orPatterns:bool,fixity:fixities} -> t
```

`parse request` parses decoded text with the selected mode and incoming
fixities. orPatterns enables Rune's optional pattern extension.

Malformed syntax is retained with diagnostics and bounded recovery.
It does not execute or elaborate declarations. Unknown modes raise Failed.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-syntax.parse.file"></a>`file` | `string` |  |
| <a name="fld-syntax.parse.text"></a>`text` | `string` |  |
| <a name="fld-syntax.parse.mode"></a>`mode` | `string` |  |
| <a name="fld-syntax.parse.orpatterns"></a>`orPatterns` | `bool` |  |
| <a name="fld-syntax.parse.fixity"></a>`fixity` | `fixities` |  |

#### <a name="val-syntax.edit"></a>`edit`

```sml
val edit : t * {start:int,stop:int,text:string,fixity:fixities} -> t
```

`edit (snapshot, change)` applies one byte-range replacement and updates
syntax. Incoming fixities can change after an earlier file is edited.

It reuses unchanged lexical suffixes and declarations only with matching
token boundaries and incoming fixities. Invalid byte ranges raise Subscript.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-syntax.edit.start"></a>`start` | `int` |  |
| <a name="fld-syntax.edit.stop"></a>`stop` | `int` |  |
| <a name="fld-syntax.edit.text"></a>`text` | `string` |  |
| <a name="fld-syntax.edit.fixity"></a>`fixity` | `fixities` |  |

#### <a name="val-syntax.text"></a>`text`

```sml
val text : t -> string
```

`text snapshot` returns exactly its decoded source bytes.

#### <a name="val-syntax.fixities"></a>`fixities`

```sml
val fixities : t -> fixities
```

`fixities snapshot` returns the environment exported to the next file.

#### <a name="val-syntax.pieces"></a>`pieces`

```sml
val pieces : t -> piece list
```

`pieces snapshot` returns nonoverlapping pieces whose concatenation is
the entire original text, including comments and malformed tokens.

#### <a name="val-syntax.events"></a>`events`

```sml
val events : t -> event list
```

`events snapshot` returns structural syntax events without annotation refs.

#### <a name="val-syntax.diagnostics"></a>`diagnostics`

```sml
val diagnostics : t -> diagnostic list
```

`diagnostics snapshot` returns parse/lexical errors in its own source.

#### <a name="val-syntax.work"></a>`work`

```sml
val work : t -> work
```

`work snapshot` reports lexical and declaration reuse for this operation.

### <a name="str-project"></a>`Project`

The compiler's immutable project model, shared with the CLI.

#### <a name="type-project.t"></a>`t`

```sml
type t
```

A scoped plan and the inputs captured while discovering it.

#### <a name="type-project.source"></a>`source`

```sml
type source = {file : string, annotations : string list, mode : string, ordinal : int}
```

An ordered source occurrence; repeated paths retain their separate
occurrences and annotations. mode is ascii, unicode or unicode=latin1.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.source.file"></a>`file` | `string` |  |
| <a name="fld-project.source.annotations"></a>`annotations` | `string list` |  |
| <a name="fld-project.source.mode"></a>`mode` | `string` |  |
| <a name="fld-project.source.ordinal"></a>`ordinal` | `int` |  |

#### <a name="type-project.input"></a>`input`

```sml
type input = {file : string, text : string, mode : string, kind : string, revision : string}
```

A captured build or group-analysis input. revision hashes decoded
text together with its source mode.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.input.file"></a>`file` | `string` |  |
| <a name="fld-project.input.text"></a>`text` | `string` |  |
| <a name="fld-project.input.mode"></a>`mode` | `string` |  |
| <a name="fld-project.input.kind"></a>`kind` | `string` |  |
| <a name="fld-project.input.revision"></a>`revision` | `string` |  |

#### <a name="type-project.buildreference"></a>`buildReference`

```sml
type buildReference={kind:string,value:string,start:int,stop:int,quoted:bool}
```

A build parser path occurrence. kind is source, build, directory or
library; the byte range includes any quotes and value excludes them.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.buildreference.kind"></a>`kind` | `string` |  |
| <a name="fld-project.buildreference.value"></a>`value` | `string` |  |
| <a name="fld-project.buildreference.start"></a>`start` | `int` |  |
| <a name="fld-project.buildreference.stop"></a>`stop` | `int` |  |
| <a name="fld-project.buildreference.quoted"></a>`quoted` | `bool` |  |

#### <a name="type-project.pathcompletion"></a>`pathCompletion`

```sml
type pathCompletion={label:string,text:string,kind:string,start:int,stop:int}
```

A bounded filesystem/path-variable completion. Its replacement range
and text include required build-language quoting.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.pathcompletion.label"></a>`label` | `string` |  |
| <a name="fld-project.pathcompletion.text"></a>`text` | `string` |  |
| <a name="fld-project.pathcompletion.kind"></a>`kind` | `string` |  |
| <a name="fld-project.pathcompletion.start"></a>`start` | `int` |  |
| <a name="fld-project.pathcompletion.stop"></a>`stop` | `int` |  |

#### <a name="type-project.buildlink"></a>`buildLink`

```sml
type buildLink={kind:string,target:string,start:int,stop:int}
```

A build reference expanded through the compiler's actual path rules.
target preserves read-path arcs; its existence is not inspected.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.buildlink.kind"></a>`kind` | `string` |  |
| <a name="fld-project.buildlink.target"></a>`target` | `string` |  |
| <a name="fld-project.buildlink.start"></a>`start` | `int` |  |
| <a name="fld-project.buildlink.stop"></a>`stop` | `int` |  |

#### <a name="val-project.buildsyntax"></a>`buildSyntax`

```sml
val buildSyntax : {file:string,text:string} -> {references:buildReference list,diagnostics:diagnostic list}
```

`buildSyntax request` returns observed path roles and structured build
diagnostics through the compiler's own lexer/parser.

Recovery retains unfinished quoted paths and variables. No files are
read and no project declarations execute.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.buildsyntax.file"></a>`file` | `string` |  |
| <a name="fld-project.buildsyntax.text"></a>`text` | `string` |  |

#### <a name="val-project.buildlinks"></a>`buildLinks`

```sml
val buildLinks : session * {file:string,text:string,variables:(string*string) list,windows:bool} -> buildLink list
```

`buildLinks (session, request)` expands complete build path tokens.

Source/build/cache paths use the build directory and configured path
variables. Libraries use the same directory resolver as the compiler.
Unfinished quotes and unresolved variables are omitted. This query
performs no filesystem reads or execution; offsets include quotes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.buildlinks.file"></a>`file` | `string` |  |
| <a name="fld-project.buildlinks.text"></a>`text` | `string` |  |
| <a name="fld-project.buildlinks.variables"></a>`variables` | `(string*string) list` |  |
| <a name="fld-project.buildlinks.windows"></a>`windows` | `bool` |  |

#### <a name="val-project.pathcompletions"></a>`pathCompletions`

```sml
val pathCompletions : session * {file:string,text:string,offset:int,variables:(string*string) list,windows:bool} ->
  {items:pathCompletion list,isIncomplete:bool}
```

`pathCompletions (session, request)` lists matching paths or variables
at a build cursor without building or executing the project.

Byte ranges refer to captured text. Windows roots/UNC and configured
path variables follow the compiler project rules. Directory scanning
is bounded to 8192 entries and results to 512; isIncomplete reports
truncation. Native filename bytes are preserved in returned strings.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.pathcompletions.file"></a>`file` | `string` |  |
| <a name="fld-project.pathcompletions.text"></a>`text` | `string` |  |
| <a name="fld-project.pathcompletions.offset"></a>`offset` | `int` |  |
| <a name="fld-project.pathcompletions.variables"></a>`variables` | `(string*string) list` |  |
| <a name="fld-project.pathcompletions.windows"></a>`windows` | `bool` |  |

#### <a name="val-project.read"></a>`read`

```sml
val read : session * {file : string, variables : (string * string) list,
                      overlays : {file : string, text : string} list, windows : bool} -> t
```

`read (session, request)` resolves a build through compiler rules,
preserving scopes, order, annotations, virtual implementations and use.

Variables are path-variable bindings. Overlays are already decoded
UTF-8, also for Latin-1 source files. windows selects Windows drive/UNC
syntax independently of the host operating system. No user declarations execute and no cache
files are written. Failure is reported through Failed.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-project.read.file"></a>`file` | `string` |  |
| <a name="fld-project.read.variables"></a>`variables` | `(string * string) list` |  |
| <a name="fld-project.read.overlays"></a>`overlays` | `{file : string, text : string} list` |  |
| <a name="fld-project.read.windows"></a>`windows` | `bool` |  |

#### <a name="val-project.sources"></a>`sources`

```sml
val sources : t -> source list
```

`sources project` lists source occurrences in compiler order.

#### <a name="val-project.inputs"></a>`inputs`

```sml
val inputs : t -> input list
```

`inputs project` is the captured build and group-discovery text.
Normal ordered sources need not be parsed to discover membership.

#### <a name="val-project.libraries"></a>`libraries`

```sml
val libraries : t -> string list
```

`libraries project` lists library-header dependencies in source order.

#### <a name="val-project.cachedirectories"></a>`cacheDirectories`

```sml
val cacheDirectories : t -> string list
```

`cacheDirectories project` lists declared cache paths. Reading a
project does not create or write these directories.

#### <a name="val-project.fingerprint"></a>`fingerprint`

```sml
val fingerprint : t -> string
```

`fingerprint project` identifies the captured plan, configuration
and discovery inputs. It is not a persisted analysis snapshot.

### <a name="str-analysis"></a>`Analysis`

Versioned static analysis with immutable query data and replay checkpoints.

#### <a name="type-analysis.t"></a>`t`

```sml
type t
```

An analysis context belonging to one compiler session.

#### <a name="type-analysis.snapshot"></a>`snapshot`

```sml
type snapshot
```

A frozen result. It remains readable after either context is closed.

#### <a name="type-analysis.checkpoint"></a>`checkpoint`

```sml
type checkpoint
```

A validated unit-cache checkpoint belonging to one analysis context.

#### <a name="type-analysis.input"></a>`input`

```sml
type input={file:string,text:string,mode:string,annotations:string list,revision:string}
```

An ordered decoded source occurrence.

revision is the caller's source
identity/version; an empty mode selects the compiler session's mode.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.input.file"></a>`file` | `string` |  |
| <a name="fld-analysis.input.text"></a>`text` | `string` |  |
| <a name="fld-analysis.input.mode"></a>`mode` | `string` |  |
| <a name="fld-analysis.input.annotations"></a>`annotations` | `string list` |  |
| <a name="fld-analysis.input.revision"></a>`revision` | `string` |  |

#### <a name="type-analysis.location"></a>`location`

```sml
type location={file:string,start:int,stop:int}
```

A half-open source byte range, before LSP position conversion.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.location.file"></a>`file` | `string` |  |
| <a name="fld-analysis.location.start"></a>`start` | `int` |  |
| <a name="fld-analysis.location.stop"></a>`stop` | `int` |  |

#### <a name="type-analysis.occurrence"></a>`occurrence`

```sml
type occurrence={unit:string,file:string,start:int,stop:int,kind:string,name:string,path:string list,
  binding:string option,definition:location option,declaration:location option,isDefinition:bool,derived:bool}
```

An actual compiler-resolved binding occurrence.

The range can cover
its enclosing syntax, so editing clients must locate identifier tokens.
derived marks a copied functor body rather than original source syntax.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.occurrence.unit"></a>`unit` | `string` |  |
| <a name="fld-analysis.occurrence.file"></a>`file` | `string` |  |
| <a name="fld-analysis.occurrence.start"></a>`start` | `int` |  |
| <a name="fld-analysis.occurrence.stop"></a>`stop` | `int` |  |
| <a name="fld-analysis.occurrence.kind"></a>`kind` | `string` |  |
| <a name="fld-analysis.occurrence.name"></a>`name` | `string` |  |
| <a name="fld-analysis.occurrence.path"></a>`path` | `string list` |  |
| <a name="fld-analysis.occurrence.binding"></a>`binding` | `string option` |  |
| <a name="fld-analysis.occurrence.definition"></a>`definition` | `location option` |  |
| <a name="fld-analysis.occurrence.declaration"></a>`declaration` | `location option` |  |
| <a name="fld-analysis.occurrence.isdefinition"></a>`isDefinition` | `bool` |  |
| <a name="fld-analysis.occurrence.derived"></a>`derived` | `bool` |  |

#### <a name="type-analysis.fact"></a>`fact`

```sml
type fact={unit:string,file:string,start:int,stop:int,ty:string,derived:bool,constructors:string list,arguments:string list list}
```

A frozen inferred type.

constructors are semantic type identities;
arguments contains curried domains, with tuple components grouped.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.fact.unit"></a>`unit` | `string` |  |
| <a name="fld-analysis.fact.file"></a>`file` | `string` |  |
| <a name="fld-analysis.fact.start"></a>`start` | `int` |  |
| <a name="fld-analysis.fact.stop"></a>`stop` | `int` |  |
| <a name="fld-analysis.fact.ty"></a>`ty` | `string` |  |
| <a name="fld-analysis.fact.derived"></a>`derived` | `bool` |  |
| <a name="fld-analysis.fact.constructors"></a>`constructors` | `string list` |  |
| <a name="fld-analysis.fact.arguments"></a>`arguments` | `string list list` |  |

#### <a name="type-analysis.typedefinition"></a>`typeDefinition`

```sml
type typeDefinition={id:string,definition:location option,declaration:location option,implementation:location option}
```

A named type's source relationships.

Abstract types retain their
specification separately from the known implementation.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.typedefinition.id"></a>`id` | `string` |  |
| <a name="fld-analysis.typedefinition.definition"></a>`definition` | `location option` |  |
| <a name="fld-analysis.typedefinition.declaration"></a>`declaration` | `location option` |  |
| <a name="fld-analysis.typedefinition.implementation"></a>`implementation` | `location option` |  |

#### <a name="type-analysis.candidate"></a>`candidate`

```sml
type candidate={name:string,kind:string,detail:string option,arguments:string list list,definition:location option}
```

A compiler-visible name and its frozen completion detail.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.candidate.name"></a>`name` | `string` |  |
| <a name="fld-analysis.candidate.kind"></a>`kind` | `string` |  |
| <a name="fld-analysis.candidate.detail"></a>`detail` | `string option` |  |
| <a name="fld-analysis.candidate.arguments"></a>`arguments` | `string list list` |  |
| <a name="fld-analysis.candidate.definition"></a>`definition` | `location option` |  |

#### <a name="type-analysis.call"></a>`call`

```sml
type call={name:string,path:string list,detail:string,arguments:string list list,argument:int,parameter:int}
```

A compiler-resolved application at the cursor. argument selects a
curried domain; parameter selects a tuple component of that domain.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.call.name"></a>`name` | `string` |  |
| <a name="fld-analysis.call.path"></a>`path` | `string list` |  |
| <a name="fld-analysis.call.detail"></a>`detail` | `string` |  |
| <a name="fld-analysis.call.arguments"></a>`arguments` | `string list list` |  |
| <a name="fld-analysis.call.argument"></a>`argument` | `int` |  |
| <a name="fld-analysis.call.parameter"></a>`parameter` | `int` |  |

#### <a name="type-analysis.typehint"></a>`typeHint`

```sml
type typeHint={name:string,position:int,ty:string,binding:string,location:location}
```

An inferred variable-pattern type at the end of its actual name token.
binding is an opaque lexical identity; location selects that token.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.typehint.name"></a>`name` | `string` |  |
| <a name="fld-analysis.typehint.position"></a>`position` | `int` |  |
| <a name="fld-analysis.typehint.ty"></a>`ty` | `string` |  |
| <a name="fld-analysis.typehint.binding"></a>`binding` | `string` |  |
| <a name="fld-analysis.typehint.location"></a>`location` | `location` |  |

#### <a name="exn-analysis.cancelled"></a>`Cancelled`

```sml
exception Cancelled
```

Cancellation discarded an attempt before publishing its cache.

#### <a name="exn-analysis.busy"></a>`Busy`

```sml
exception Busy
```

An operation re-entered or closed a context during an active check.

#### <a name="val-analysis.create"></a>`create`

```sml
val create : session * {context:string} -> t
```

`create (compiler, {context})` creates an isolated analysis history.

context identifies the caller's project/target. It does not append to
the compiler's executable history or execute user code.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.create.context"></a>`context` | `string` |  |

#### <a name="val-analysis.close"></a>`close`

```sml
val close : t -> unit
```

`close context` releases its retained caches; repeated calls do nothing.

#### <a name="val-analysis.check"></a>`check`

```sml
val check : t * {project:Project.t option,inputs:input list,cancelled:unit->bool} -> snapshot
```

`check (context, request)` checks captured inputs in compiler order.

A project must come from the same compiler session; inputs must match
its ordered occurrences, modes, annotations and group-discovery text.
Without a project the inputs form an ordered loose-file context.
No files or artifacts are written, and user initializers never run.

Valid unchanged prefixes replay checked bases. Changed units receive
fresh annotation slots in a fresh compiler owner. A failed unit returns
diagnostics and query data for its validated prefix; later units remain
unavailable. Cancellation is polled between analysis phases and units;
a supervisor must bound phases that cannot yet be interrupted.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.check.project"></a>`project` | `Project.t option` |  |
| <a name="fld-analysis.check.inputs"></a>`inputs` | `input list` |  |
| <a name="fld-analysis.check.cancelled"></a>`cancelled` | `unit->bool` |  |

#### <a name="val-analysis.checkpoint"></a>`checkpoint`

```sml
val checkpoint : t -> checkpoint
```

`checkpoint context` captures only committed, validated unit entries.

#### <a name="val-analysis.restore"></a>`restore`

```sml
val restore : t * checkpoint -> unit
```

`restore (context, checkpoint)` restores a cache from that same context.
The next check still validates its full configuration and inputs.

#### <a name="val-analysis.id"></a>`id`

```sml
val id : snapshot -> string
```

`id snapshot` is unique within this analysis context's lifetime.

#### <a name="val-analysis.context"></a>`context`

```sml
val context : snapshot -> string
```

`context snapshot` returns the caller's project/target identity.

#### <a name="val-analysis.project"></a>`project`

```sml
val project : snapshot -> string option
```

`project snapshot` returns its captured project fingerprint, if any.

#### <a name="val-analysis.inputs"></a>`inputs`

```sml
val inputs : snapshot -> input list
```

`inputs snapshot` returns the exact captured user source occurrences.

#### <a name="val-analysis.unitat"></a>`unitAt`

```sml
val unitAt : snapshot * {ordinal:int} -> string option
```

`unitAt (snapshot, position)` returns the opaque unit identity of a
primary source occurrence by its zero-based ordinal.

Compare it with occurrence/fact unit fields within this snapshot;
do not interpret its spelling. An invalid ordinal returns NONE.
It remains readable after closing the analysis context or session.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.unitat.ordinal"></a>`ordinal` | `int` |  |

#### <a name="val-analysis.syntaxat"></a>`syntaxAt`

```sml
val syntaxAt : snapshot * {ordinal:int} -> Syntax.t option
```

`syntaxAt (snapshot, position)` returns the captured syntax of an
attempted primary source occurrence, using its actual incoming fixities.

A failed parse retains its current text and recovery diagnostics. An
invalid ordinal, or an input not reached after an earlier failure,
returns NONE. The result is immutable and survives closing its owner.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.syntaxat.ordinal"></a>`ordinal` | `int` |  |

#### <a name="val-analysis.dependencies"></a>`dependencies`

```sml
val dependencies : snapshot -> input list
```

`dependencies snapshot` returns captured library source and identities.

#### <a name="val-analysis.diagnostics"></a>`diagnostics`

```sml
val diagnostics : snapshot -> diagnostic list
```

`diagnostics snapshot` returns source-addressed analysis diagnostics.

#### <a name="val-analysis.occurrences"></a>`occurrences`

```sml
val occurrences : snapshot -> occurrence list
```

`occurrences snapshot` returns frozen lexical binding relationships.

#### <a name="val-analysis.types"></a>`types`

```sml
val types : snapshot -> typeDefinition list
```

`types snapshot` returns semantic constructor identities and sources.

#### <a name="val-analysis.facts"></a>`facts`

```sml
val facts : snapshot -> fact list
```

`facts snapshot` returns inferred types without mutable compiler refs.

#### <a name="val-analysis.work"></a>`work`

```sml
val work : snapshot -> {checked:int,reused:int}
```

`work snapshot` reports checked and replayed units, including libraries.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.work.checked"></a>`checked` | `int` |  |
| <a name="fld-analysis.work.reused"></a>`reused` | `int` |  |

#### <a name="val-analysis.typeat"></a>`typeAt`

```sml
val typeAt : snapshot * {file:string,offset:int} -> string option
```

`typeAt (snapshot, position)` returns its innermost original-source type.

Copied-body facts are used only where no original fact is available.
A file with several source occurrences requires typeAtOccurrence.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.typeat.file"></a>`file` | `string` |  |
| <a name="fld-analysis.typeat.offset"></a>`offset` | `int` |  |

#### <a name="val-analysis.typeatoccurrence"></a>`typeAtOccurrence`

```sml
val typeAtOccurrence : snapshot * {ordinal:int,offset:int} -> string option
```

`typeAtOccurrence (snapshot, {ordinal, offset})` queries one ordered
source occurrence, preserving its incoming build context.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.typeatoccurrence.ordinal"></a>`ordinal` | `int` |  |
| <a name="fld-analysis.typeatoccurrence.offset"></a>`offset` | `int` |  |

#### <a name="val-analysis.typehints"></a>`typeHints`

```sml
val typeHints : snapshot * {ordinal:int,start:int,stop:int} -> typeHint list
```

`typeHints (snapshot, range)` returns checked, unannotated variable
patterns whose hint positions lie between start and stop, inclusively.

Offsets address one ordered source occurrence. Explicitly typed
patterns, constructors and copied bodies are excluded. Invalid ordinals
or reversed/negative ranges return no hints. No source is rechecked;
the result remains readable after closing the context or session.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.typehints.ordinal"></a>`ordinal` | `int` |  |
| <a name="fld-analysis.typehints.start"></a>`start` | `int` |  |
| <a name="fld-analysis.typehints.stop"></a>`stop` | `int` |  |

#### <a name="val-analysis.visibleat"></a>`visibleAt`

```sml
val visibleAt : snapshot * {ordinal:int,offset:int,path:string list} -> candidate list
```

`visibleAt (snapshot, position)` returns actual lexical bindings at a
source occurrence's byte offset, or members of path.

It replays validated prefixes and rechecks the requested unit. Only
frozen names/details escape; no mutable environment is published.
Incomplete expressions can use bounded private syntax probes whose
facts and diagnostics are never published as original-source data.
The snapshot remains queryable after its context closes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.visibleat.ordinal"></a>`ordinal` | `int` |  |
| <a name="fld-analysis.visibleat.offset"></a>`offset` | `int` |  |
| <a name="fld-analysis.visibleat.path"></a>`path` | `string list` |  |

#### <a name="val-analysis.signatureat"></a>`signatureAt`

```sml
val signatureAt : snapshot * {ordinal:int,offset:int} -> call option
```

`signatureAt (snapshot, position)` returns the enclosing named
application's checked callable type and argument position.

Application structure comes from compiler syntax, including derived
infix applications. Incomplete expressions use the same private
probes as visibleAt. Unavailable or non-callable names return NONE.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.signatureat.ordinal"></a>`ordinal` | `int` |  |
| <a name="fld-analysis.signatureat.offset"></a>`offset` | `int` |  |

#### <a name="val-analysis.completionat"></a>`completionAt`

```sml
val completionAt : snapshot * {ordinal:int,offset:int,path:string list} ->
  {role:string,fields:(string*string) list,candidates:candidate list}
```

`completionAt (snapshot, position)` returns lexical candidates and
the compiler syntax role at the cursor.

role is expression, pattern, type, field, structure, signature, declaration
or unknown. fields contains labels and types only where a checked
record operand/pattern supplies a concrete record type. A consumer
may filter namespaces without implementing a second parser.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-analysis.completionat.ordinal"></a>`ordinal` | `int` |  |
| <a name="fld-analysis.completionat.offset"></a>`offset` | `int` |  |
| <a name="fld-analysis.completionat.path"></a>`path` | `string list` |  |

#### <a name="val-analysis.documentationat"></a>`documentationAt`

```sml
val documentationAt : snapshot * location -> string option
```

`documentationAt (snapshot, location)` returns the leading source
comment of the declaration owning that captured location.

It uses captured source and syntax, including library dependencies;
it does not reread disk files. The comment delimiters are removed.

---

<sub>Generated by runedoc from lib/compiler/api/compiler\_sig.sml; do not edit.</sub>
