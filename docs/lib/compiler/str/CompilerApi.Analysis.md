# structure CompilerApi.Analysis

[Compiler](../README.md) &rsaquo; [Structures](../structures.md) &rsaquo; **CompilerApi.Analysis**

|  |  |
| --- | --- |
| Signatures | none: [`COMPILER_API`](../sig/COMPILER_API.md) specifies it inside [`CompilerApi`](../str/CompilerApi.md) |
| Status | required |
| Members | 51 |
| Tests | not listed |
| Source | [lib/compiler/api/compiler.sml](../../../../lib/compiler/api/compiler.sml) |

## Members

What each means is on [`COMPILER_API`](../sig/COMPILER_API.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`call`](../sig/COMPILER_API.md#type-analysis.call) | `{argument : int, arguments : string list list, detail : string, name : string, parameter : int, path : string list}` |
| type | [`candidate`](../sig/COMPILER_API.md#type-analysis.candidate) | `{arguments : string list list, definition : location option, detail : string option, kind : string, name : string}` |
| type | [`checkpoint`](../sig/COMPILER_API.md#type-analysis.checkpoint) | *a type of its own* |
| type | [`fact`](../sig/COMPILER_API.md#type-analysis.fact) | `{arguments : string list list, constructors : string list, derived : bool, file : string, start : int, stop : int, ty : string, unit : string}` |
| type | [`input`](../sig/COMPILER_API.md#type-analysis.input) | `{annotations : string list, file : string, mode : string, revision : string, text : string}` |
| type | [`location`](../sig/COMPILER_API.md#type-analysis.location) | `{file : string, start : int, stop : int}` |
| type | [`observation`](../sig/COMPILER_API.md#type-analysis.observation) | `{checked : int, file : string, items : int, phase : string, reused : int}` |
| type | [`occurrence`](../sig/COMPILER_API.md#type-analysis.occurrence) | `{binding : string option, declaration : location option, definition : location option, derived : bool, file : string, isDefinition : bool, kind : string, name : string, path : string list, start : int, stop : int, unit : string}` |
| type | [`pool`](../sig/COMPILER_API.md#type-analysis.pool) | *a type of its own* |
| type | [`snapshot`](../sig/COMPILER_API.md#type-analysis.snapshot) | *a type of its own* |
| type | [`t`](../sig/COMPILER_API.md#type-analysis.t) | *a type of its own* |
| type | [`typeDefinition`](../sig/COMPILER_API.md#type-analysis.typedefinition) | `{declaration : location option, definition : location option, id : string, implementation : location option}` |
| type | [`typeHint`](../sig/COMPILER_API.md#type-analysis.typehint) | `{binding : string, location : location, name : string, position : int, ty : string}` |
| exception | [`Busy`](../sig/COMPILER_API.md#exn-analysis.busy) |  |
| exception | [`Cancelled`](../sig/COMPILER_API.md#exn-analysis.cancelled) |  |
| val | [`check`](../sig/COMPILER_API.md#val-analysis.check) | `t * {cancelled : unit -> bool, inputs : input list, project : CompilerApi.Project.t option} -> snapshot` |
| val | [`checkpoint`](../sig/COMPILER_API.md#val-analysis.checkpoint) | `t -> checkpoint` |
| val | [`close`](../sig/COMPILER_API.md#val-analysis.close) | `t -> unit` |
| val | [`compact`](../sig/COMPILER_API.md#val-analysis.compact) | `t -> unit` |
| val | [`completionAt`](../sig/COMPILER_API.md#val-analysis.completionat) | `snapshot * {offset : int, ordinal : int, path : string list} -> {candidates : candidate list, fields : (string * string) list, role : string}` |
| val | [`context`](../sig/COMPILER_API.md#val-analysis.context) | `snapshot -> string` |
| val | [`create`](../sig/COMPILER_API.md#val-analysis.create) | `CompilerApi.session * {context : string} -> t` |
| val | [`dependencies`](../sig/COMPILER_API.md#val-analysis.dependencies) | `snapshot -> input list` |
| val | [`diagnostics`](../sig/COMPILER_API.md#val-analysis.diagnostics) | `snapshot -> {column : int, file : string, line : int, message : string, severity : string, start : int, stop : int} list` |
| val | [`documentationAt`](../sig/COMPILER_API.md#val-analysis.documentationat) | `snapshot * location -> string option` |
| val | [`facts`](../sig/COMPILER_API.md#val-analysis.facts) | `snapshot -> fact list` |
| val | [`factsIn`](../sig/COMPILER_API.md#val-analysis.factsin) | `snapshot * string -> fact list` |
| val | [`focus`](../sig/COMPILER_API.md#val-analysis.focus) | `t * string list option -> unit` |
| val | [`id`](../sig/COMPILER_API.md#val-analysis.id) | `snapshot -> string` |
| val | [`implementationsOf`](../sig/COMPILER_API.md#val-analysis.implementationsof) | `snapshot * location -> occurrence list` |
| val | [`inputs`](../sig/COMPILER_API.md#val-analysis.inputs) | `snapshot -> input list` |
| val | [`lazy`](../sig/COMPILER_API.md#val-analysis.lazy) | `t * bool -> unit` |
| val | [`observe`](../sig/COMPILER_API.md#val-analysis.observe) | `t * (observation -> unit) option -> unit` |
| val | [`occurrences`](../sig/COMPILER_API.md#val-analysis.occurrences) | `snapshot -> occurrence list` |
| val | [`occurrencesIn`](../sig/COMPILER_API.md#val-analysis.occurrencesin) | `snapshot * string -> occurrence list` |
| val | [`pool`](../sig/COMPILER_API.md#val-analysis.pool) | `unit -> pool` |
| val | [`project`](../sig/COMPILER_API.md#val-analysis.project) | `snapshot -> string option` |
| val | [`restore`](../sig/COMPILER_API.md#val-analysis.restore) | `t * checkpoint -> unit` |
| val | [`route`](../sig/COMPILER_API.md#val-analysis.route) | `snapshot -> {broken : int, byNeed : int, cutoff : int, loaded : int, rebound : int, stored : int, walked : bool}` |
| val | [`share`](../sig/COMPILER_API.md#val-analysis.share) | `t * pool option -> unit` |
| val | [`signatureAt`](../sig/COMPILER_API.md#val-analysis.signatureat) | `snapshot * {offset : int, ordinal : int} -> call option` |
| val | [`store`](../sig/COMPILER_API.md#val-analysis.store) | `t * string option -> unit` |
| val | [`syntaxAt`](../sig/COMPILER_API.md#val-analysis.syntaxat) | `snapshot * {ordinal : int} -> CompilerApi.Syntax.t option` |
| val | [`typeAt`](../sig/COMPILER_API.md#val-analysis.typeat) | `snapshot * {file : string, offset : int} -> string option` |
| val | [`typeAtOccurrence`](../sig/COMPILER_API.md#val-analysis.typeatoccurrence) | `snapshot * {offset : int, ordinal : int} -> string option` |
| val | [`typeHints`](../sig/COMPILER_API.md#val-analysis.typehints) | `snapshot * {ordinal : int, start : int, stop : int} -> typeHint list` |
| val | [`types`](../sig/COMPILER_API.md#val-analysis.types) | `snapshot -> typeDefinition list` |
| val | [`unitAt`](../sig/COMPILER_API.md#val-analysis.unitat) | `snapshot * {ordinal : int} -> string option` |
| val | [`versionOf`](../sig/COMPILER_API.md#val-analysis.versionof) | `snapshot * string -> string option` |
| val | [`visibleAt`](../sig/COMPILER_API.md#val-analysis.visibleat) | `snapshot * {offset : int, ordinal : int, path : string list} -> candidate list` |
| val | [`work`](../sig/COMPILER_API.md#val-analysis.work) | `snapshot -> {checked : int, reused : int}` |

---

<sub>Generated by runedoc from lib/compiler/api/compiler.sml; do not edit.</sub>
