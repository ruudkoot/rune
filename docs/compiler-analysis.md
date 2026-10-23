# Static compiler analysis

`RuneCompiler.Analysis` checks captured source snapshots through the public
compiler library. It never calls `run`, executes initializers, evaluates
`use`, or loads user dynamic modules. The CLI and analysis share scoped
build visibility through `CompilerBuildContext`.

```sml
structure C = RuneCompiler
structure A = C.Analysis
val compiler = C.session {lib = NONE, flags = []}
val context = A.create (compiler, {context = "application"})
val snapshot = A.check (context,
  {project = NONE,
   inputs = [{file = "example.sml", text = "val answer=42\n",
              mode = "ascii", annotations = [], revision = "1"}],
   cancelled = fn () => false})
val answerType = A.typeAt (snapshot, {file = "example.sml", offset = 4})
val saved = A.checkpoint context
val () = A.restore (context, saved)
val () = A.close context
val () = C.close compiler
```

The snapshot remains readable after both contexts close. Its ordered
inputs retain the caller's revision strings; its context, project
fingerprint and unique result ID identify the analysis that produced it.
Each input's text is decoded UTF-8, including Latin-1 overlays. Source
modes still control literal semantics and representability.

For a project, call `RuneCompiler.Project.read` with the same compiler
session and supply its source occurrences in order, with matching modes
and annotations. Group-discovery text must still match the captured plan.
The library validates these conditions instead of silently analyzing a
different build. Project library headers supplement configured libraries.
Library source is captured separately in `dependencies`.

Each check owns a fresh compiler state. Unchanged validated input prefixes
replay serialized checked bases; comparisons include actual source text,
mode, primitive permission, source occurrence and the scoped plan. The
first changed unit ends semantic prefix reuse. Syntax can still reuse
unchanged tokens/declarations against the new incoming fixities. New
elaboration always receives fresh annotation slots. No mutable compiler
type or AST reference escapes in query results.

Lexical bindings and runtime identities serve different purposes. An
exception alias has its own lexical declaration while sharing the
exception's runtime identity. Signature constraints retain declaration
and implementation locations. Copied functor bodies keep their lexical
owner; `derived` identifies their copied occurrences and type facts.
Generative and opaque type-constructor identities remain distinct through
basis replay. This metadata is stored in the version-7 basis format;
ordinary batch compilation leaves provenance tracking disabled.

`unitAt` supplies an opaque identity for each primary source occurrence;
clients compare it with fact/occurrence unit fields instead of constructing
identities from filenames. `typeAtOccurrence` selects an ordered source
occurrence explicitly when a file appears several times in a build.
`syntaxAt` retains each attempted primary input's current parser snapshot,
including recovery diagnostics after a failed parse and its actual incoming
project fixities. Inputs not reached after an earlier failure have no captured
syntax. These trees remain readable after the owner closes.
`typeHints` joins captured pattern syntax, lexical definitions and exact frozen
type facts for one source ordinal. It returns the inferred types and name-token
locations of unannotated variable and alias patterns, including parameters and
case rules. Explicit pattern annotations suppress contained hints. Constructors,
function declaration heads and copied functor bodies contribute no inferred
pattern hints. Hint positions use decoded byte offsets and inclusive query
bounds; this query neither rechecks source nor accesses disk or live compiler
state, and it remains usable after its owner closes.
`visibleAt` replays the captured
prefix and asks the compiler for the lexical environment at a byte cursor,
or for members of a qualified structure path. Its frozen names, kinds,
types and definition locations remain queryable after the context closes.
The selected library plan is captured too: later manifest changes or
deletion of the original library cannot change an old snapshot's query.
Whitespace between declarations sees only preceding bindings. An unfinished
expression can use a bounded private syntax probe; probe facts and errors
are never published as analysis of the original text. No mutable environment
escapes, and a query never executes declarations or writes files.

`completionAt` also returns the compiler syntax role and concrete record
fields where the operand or pattern has a checked record type. It returns
no guessed labels for an unresolved flexible record. `signatureAt` derives
the named callee and active curried/tuple argument from compiler application
syntax, including infix desugaring; its domains and types are frozen data.
`documentationAt` reads the leading comment of the owning declaration from
captured syntax/source, including dependencies whose disk files are gone.

Build-document queries belong to `RuneCompiler.Project.buildSyntax` and
`pathCompletions`. They share the batch build lexer/parser and preserve path
roles, token ranges and required quoting. Strict parsing returns located
diagnostics; recovery retains unfinished paths and variables. Path queries
read directory metadata using the session's library root and supplied path
variables, preserve native filename bytes, and never execute a project.

Checkpoints contain committed unit entries and visibility-plan metadata,
rather than a rollback copy of mutable unification cells. They belong to
one analysis context and never rewind its result-ID counter. Cancelled or
exceptional attempts retain the previous cache. A rejected unit returns
diagnostics and facts for its validated prefix; subsequent units are
unavailable. Recovery within a rejected unit remains a later extension.

Cancellation is polled between capture, parsing, elaboration, export and
unit boundaries. A language server supervises the worker process to bound
uninterruptible phases. The API currently bounds user inputs to 10,000
occurrences and 128 MiB of decoded text; worker and document limits are
separate. `Busy` rejects re-entry of an active analysis context.

Occurrence ranges describe compiler syntax constructs and can include
more than an identifier. Editing consumers derive exact token selections
and validate edits through fresh analysis. The server's rename and other
editing providers remain unadvertised until their own acceptance gates.
