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
session, and the workspace `RuneCompiler.Workspace.find` gives above its
build, and supply its source occurrences in order, with matching modes
and annotations. Group-discovery text must still match the captured plan.
The library validates these conditions instead of silently analyzing a
different build. Project library headers supplement configured libraries.
Library source is captured separately in `dependencies`.

A context keeps what it has worked out between checks, in a compiler state of
its own, a world: each unit stays loaded, with the place it was reached at
(its environment, fixity, signatures, functors and binders). A later check
compares each input with what is kept, by its unit's name, and elaborates what
changed at its own place, touching nothing else while the unit's identity
stands: the rest of the build does not know it changed. Where an identity
moves, a walk goes from the start: each closed unit after the change is taken
by its usages, as a build takes an entry of the cache, loaded again from its
pickle against the new unit (`UnitBasis.remappingBasis`), and elaborated again
where a usage says no. An open unit after it is elaborated again in any case:
its facts print a type by a path that reaches it where the unit stands, which
no usage covers. A plan or a selection of libraries that changed, or a scope a
library is compiled in or its boundary (`LibraryScope`), walks the same way. A
unit that fails leaves what is kept as it was, and its place stands. `route`
reports how a check went; whichever way, the results are a fresh
analysis's, and `tools/lsp/oracle.sml` holds them to one
(`docs/language-server.md`, *Keeping what is computed*).

Syntax is edited from the kept syntax against the incoming fixities. New
elaboration always receives fresh annotation slots, and no mutable compiler type
or AST reference escapes in query results; a failed or cancelled elaboration
is undone before anything else is done, and a load that fails part of the way
gives the world up, which the next check rebuilds from the entries.

A snapshot holds what the check left, and works out what is asked of it: a
unit's occurrences are projected when first asked for, and every unit's flat
lists only by `occurrences`, `facts` and `types`, so that a question about one
unit costs that unit. Type-name qualification is memoized only within one
unit's fixed outgoing environment. Prelude name sets are kept by exact source
text, mode and path, and an input lexed only where its text is new; a plan of
libraries stands while the build checked is the same (a library's friend sees
more), no input's set of names moved and no MANIFEST or library file changed. A
file's stamp is its time and size, and is trusted only of a file older than the
time's grain when it was stamped.

`focus (context, SOME files)` closes every unit but those of files, for the
checks after it: a closed unit keeps its pickle, sidecar, text and types, and of
its uses those whose definition is not their declaration, which is what
`implementationsOf` reads. A query that needs more opens the unit at its place,
which costs that unit's elaboration, and keeps the last few. The flat lists hold
no closed unit's facts or occurrences. The default is every file open, so that
an analysis left alone never takes a unit by its usages. `compact` gives up the
compiler state and loads the units into a new one, which a check does itself
after 256 walks: what the tables hold of units long replaced goes with it.

Another unit's origin is held by reference: its kind and path in what that
unit declares, resolved when it is read. So a span that moves under a unit
reused as it stands does not leave the unit's bindings stale. The binding a
client shows is the definition's now, as a fresh analysis would say.

A query of the latest snapshot goes to its unit's place, and ends when that unit
is elaborated: nothing after it is touched. A query of an older snapshot, or one
whose context has closed, walks the snapshot's own entries in a compiler state
of its own.

`observe (context, SOME callback)` enables synchronous phase observations
between checks. Events identify phases, source units and work counts; callers
supply clocks and host allocation measurements. `NONE` disables observation.
Callbacks receive no mutable compiler state. A callback exception aborts the
attempt and releases the busy context; already published snapshots remain
readable. Observation is disabled by default.

Lexical bindings and runtime identities serve different purposes. An
exception alias has its own lexical declaration while sharing the
exception's runtime identity. Signature constraints retain declaration
and implementation locations. Copied functor bodies keep their lexical
owner; `derived` identifies their copied occurrences and type facts.
Generative and opaque type-constructor identities remain distinct through
basis replay. This metadata is stored in a sidecar beside the basis,
outside every hash, so that a comment that moves spans moves no unit's
identity ([units.md](units.md), *The export basis*); ordinary batch
compilation leaves provenance tracking disabled and its sidecar empty.

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
diagnostics; recovery retains unfinished paths and variables. Completion queries
read directory metadata using the session's library root and supplied path
variables, preserve native filename bytes, and never execute a project.

`buildLinks` expands complete source, included-build and cache paths through
the compiler's directory/variable expansion, and library targets use its actual
library resolver. Unfinished quotes and unresolved variables are omitted.
Returned targets retain read-path arcs and are not inspected on disk. The
adapter resolves an existing target through `OS.FileSys.fullPath` when the link
is followed, preserving native paths, object identity and symbolic-link rules.

Checkpoints contain committed unit entries and visibility-plan metadata,
rather than a rollback copy of mutable unification cells. They belong to
one analysis context and never rewind its result-ID counter; restoring one
loads its units again. Cancelled or exceptional attempts keep what they
reached, and the next check goes on from it. A rejected unit returns
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
