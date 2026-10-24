# structure RuneCompiler.Analysis

[Compiler](../README.md) &rsaquo; [Structures](../structures.md) &rsaquo; **RuneCompiler.Analysis**

|  |  |
| --- | --- |
| Signatures | none: [`RUNE_COMPILER`](../sig/RUNE_COMPILER.md) specifies it inside [`RuneCompiler`](../str/RuneCompiler.md) |
| Status | required |
| Members | 39 |
| Tests | not listed |
| Source | [lib/compiler/api/compiler.sml](../../../../lib/compiler/api/compiler.sml) |

## Members

What each means is on [`RUNE_COMPILER`](../sig/RUNE_COMPILER.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`call`](../sig/RUNE_COMPILER.md#type-analysis.call) | `{argument : int, arguments : string list list, detail : string, name : string, parameter : int, path : string list}` |
| type | [`candidate`](../sig/RUNE_COMPILER.md#type-analysis.candidate) | `{arguments : string list list, definition : location option, detail : string option, kind : string, name : string}` |
| type | [`checkpoint`](../sig/RUNE_COMPILER.md#type-analysis.checkpoint) | *a type of its own* |
| type | [`fact`](../sig/RUNE_COMPILER.md#type-analysis.fact) | `{arguments : string list list, constructors : string list, derived : bool, file : string, start : int, stop : int, ty : string, unit : string}` |
| type | [`input`](../sig/RUNE_COMPILER.md#type-analysis.input) | `{annotations : string list, file : string, mode : string, revision : string, text : string}` |
| type | [`location`](../sig/RUNE_COMPILER.md#type-analysis.location) | `{file : string, start : int, stop : int}` |
| type | [`observation`](../sig/RUNE_COMPILER.md#type-analysis.observation) | `{checked : int, file : string, items : int, phase : string, reused : int}` |
| type | [`occurrence`](../sig/RUNE_COMPILER.md#type-analysis.occurrence) | `{binding : string option, declaration : location option, definition : location option, derived : bool, file : string, isDefinition : bool, kind : string, name : string, path : string list, start : int, stop : int, unit : string}` |
| type | [`snapshot`](../sig/RUNE_COMPILER.md#type-analysis.snapshot) | *a type of its own* |
| type | [`t`](../sig/RUNE_COMPILER.md#type-analysis.t) | *a type of its own* |
| type | [`typeDefinition`](../sig/RUNE_COMPILER.md#type-analysis.typedefinition) | `{declaration : location option, definition : location option, id : string, implementation : location option}` |
| type | [`typeHint`](../sig/RUNE_COMPILER.md#type-analysis.typehint) | `{binding : string, location : location, name : string, position : int, ty : string}` |
| exception | [`Busy`](../sig/RUNE_COMPILER.md#exn-analysis.busy) |  |
| exception | [`Cancelled`](../sig/RUNE_COMPILER.md#exn-analysis.cancelled) |  |
| val | [`check`](../sig/RUNE_COMPILER.md#val-analysis.check) | `t * {cancelled : unit -> bool, inputs : input list, project : RuneCompiler.Project.t option} -> snapshot` |
| val | [`checkpoint`](../sig/RUNE_COMPILER.md#val-analysis.checkpoint) | `t -> checkpoint` |
| val | [`close`](../sig/RUNE_COMPILER.md#val-analysis.close) | `t -> unit` |
| val | [`completionAt`](../sig/RUNE_COMPILER.md#val-analysis.completionat) | `snapshot * {offset : int, ordinal : int, path : string list} -> {candidates : candidate list, fields : (string * string) list, role : string}` |
| val | [`context`](../sig/RUNE_COMPILER.md#val-analysis.context) | `snapshot -> string` |
| val | [`create`](../sig/RUNE_COMPILER.md#val-analysis.create) | `RuneCompiler.session * {context : string} -> t` |
| val | [`dependencies`](../sig/RUNE_COMPILER.md#val-analysis.dependencies) | `snapshot -> input list` |
| val | [`diagnostics`](../sig/RUNE_COMPILER.md#val-analysis.diagnostics) | `snapshot -> {column : int, file : string, line : int, message : string, severity : string, start : int, stop : int} list` |
| val | [`documentationAt`](../sig/RUNE_COMPILER.md#val-analysis.documentationat) | `snapshot * location -> string option` |
| val | [`facts`](../sig/RUNE_COMPILER.md#val-analysis.facts) | `snapshot -> fact list` |
| val | [`id`](../sig/RUNE_COMPILER.md#val-analysis.id) | `snapshot -> string` |
| val | [`inputs`](../sig/RUNE_COMPILER.md#val-analysis.inputs) | `snapshot -> input list` |
| val | [`observe`](../sig/RUNE_COMPILER.md#val-analysis.observe) | `t * (observation -> unit) option -> unit` |
| val | [`occurrences`](../sig/RUNE_COMPILER.md#val-analysis.occurrences) | `snapshot -> occurrence list` |
| val | [`project`](../sig/RUNE_COMPILER.md#val-analysis.project) | `snapshot -> string option` |
| val | [`restore`](../sig/RUNE_COMPILER.md#val-analysis.restore) | `t * checkpoint -> unit` |
| val | [`signatureAt`](../sig/RUNE_COMPILER.md#val-analysis.signatureat) | `snapshot * {offset : int, ordinal : int} -> call option` |
| val | [`syntaxAt`](../sig/RUNE_COMPILER.md#val-analysis.syntaxat) | `snapshot * {ordinal : int} -> RuneCompiler.Syntax.t option` |
| val | [`typeAt`](../sig/RUNE_COMPILER.md#val-analysis.typeat) | `snapshot * {file : string, offset : int} -> string option` |
| val | [`typeAtOccurrence`](../sig/RUNE_COMPILER.md#val-analysis.typeatoccurrence) | `snapshot * {offset : int, ordinal : int} -> string option` |
| val | [`typeHints`](../sig/RUNE_COMPILER.md#val-analysis.typehints) | `snapshot * {ordinal : int, start : int, stop : int} -> typeHint list` |
| val | [`types`](../sig/RUNE_COMPILER.md#val-analysis.types) | `snapshot -> typeDefinition list` |
| val | [`unitAt`](../sig/RUNE_COMPILER.md#val-analysis.unitat) | `snapshot * {ordinal : int} -> string option` |
| val | [`visibleAt`](../sig/RUNE_COMPILER.md#val-analysis.visibleat) | `snapshot * {offset : int, ordinal : int, path : string list} -> candidate list` |
| val | [`work`](../sig/RUNE_COMPILER.md#val-analysis.work) | `snapshot -> {checked : int, reused : int}` |

---

<sub>Generated by runedoc from lib/compiler/api/compiler.sml; do not edit.</sub>
