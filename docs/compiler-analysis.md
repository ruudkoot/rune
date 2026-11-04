# Static compiler analysis

`CompilerApi.Analysis` checks captured source snapshots through the public
compiler library. It never calls `run`, executes initializers, evaluates
`use`, or loads user dynamic modules. The CLI and analysis share scoped
build visibility through `CompilerBuildContext`.

```sml
structure C = CompilerApi
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

For a project, call `CompilerApi.Project.read` with the same compiler
session, and the workspace `CompilerApi.Workspace.find` gives above its
build, and supply its source occurrences in order, with matching modes
and annotations. Group-discovery text must still match the captured plan.
The library validates these conditions instead of silently analyzing a
different build. Project library headers supplement configured libraries.
Library source is captured separately in `dependencies`.

A context keeps what it has worked out between checks, in a compiler state of
its own, a world: each unit stays loaded, with the place it was reached at
(its environment, fixity, signatures, functors and binders). It loads a unit
as elaboration reads one: the static layer of its basis, and of the ABI layer
the names of the values the static layer holds, nothing else
(`UnitBasis.staticOnly`); and a unit's identity is its static layer's,
`NAME@HASH` of that layer, so that an edit of a body moves none, and a
compile's basis and an analysis's of the same text load the same. A later check
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
unit that fails leaves what is kept as it was, and its place stands. It fails
as a compile does (`docs/units.md`, *Errors*): each top-level declaration that
does not elaborate is reported, undone and gone past, as is each syntax error,
so that a unit reports every independent error and not only its first. What it
declared past them is in the snapshot, and answers a question about the unit,
but it is not kept, and nothing after it is reached: the walk stops after the
unit, which is elaborated again wherever it is reached, since a name it found
unbound is not among its usages. A unit whose error left a flexible record
open (`tests/units/flex`) has no basis to write, and reports the error as a
compile does. `route`
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
more), its view of the Basis Library is the same (D12; a build's `view` is
selected as a compile selects it), no input's set of names moved and no
MANIFEST or library file changed. A file's stamp is its time and size, and is
trusted only of a file older than the time's grain when it was stamped.

`share (context, true)` lets contexts take a library's units from one another.
A unit of a library is the same unit in every build over it (its name is
`LIBRARY:PATH`, `docs/units.md`, *Names*), so a context reaching a library's
unit it has never held takes the one another context that shares, under the
same compiler configuration, checked last: by its usages, as a walk takes a
unit, loaded from its pickle where they hold and elaborated where they do not.
What is shared is a unit's entry without its place, which is a world's, so a
closed context keeps nothing alive. A program's own units are never shared,
and nor is a unit of an open file, which a walk elaborates in any case. The
language server's contexts share; `tools/lsp/oracle.sml --share` holds a
context that does to a fresh one that does not.

`focus (context, SOME files)` closes every unit but those of files, for the
checks after it: a closed unit keeps its pickle, sidecar, text and types, and of
its uses those whose definition is not their declaration, which is what
`implementationsOf` reads, and its notes: its facts, occurrences and types as
bytes, with each type name its facts printed and the path that printed it. A
query of its facts or occurrences reads the notes where they hold: each such
type name prints by the same path from where the unit stands now, which no
usage says, since a path depends on the whole environment; and each unit whose
places its occurrences hold by span alone, not by reference, has the text it
had. A query of its syntax or typing, or one whose notes do not hold, opens the
unit at its place, which costs that unit's elaboration; the last few opened are
kept. The flat lists hold no closed unit's facts or occurrences. The default is every file open, so that
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

`store (context, SOME dir)` has a context read a compile's store
(`Workspace.store` says where a compile of a file keeps it; `docs/units.md`,
*The store*). A unit that no context holds and whose file is not open is
taken from it where two things are there: a compile's entry of the unit whose
usages hold where the unit is reached, by their binders, of any configuration
whose static settings are the context's (the compiler, the formats, the hash
and the language's settings: `UnitCache.staticSettings`), in the store and
then its layers; and the unit's sidecar, by the hash of its text, which an
analysis of the same text wrote, of the same compiler, the same static
identity, its usages' binders the same here, and the places it holds by span
in texts that are the same. The entry gives its static layer, under its static
identity, and the compile's identity of it names it too (`UnitBasis.alias`);
the sidecar gives the origins of its names, which a compile does not record,
its notes, its types, and the names its text mentions, which the selection of
the libraries reads in place of a parse. A unit elaborated from the text its
file has gets its sidecar written. A unit taken so holds its usages by the
compile's fingerprints, which an analysis's never equal: where the identity
of a unit it used is about to move, a walk first works out again, where that
unit still stands, what each unit after it used of it, in the analysis's
terms, so that a unit whose names are the same is taken and not elaborated.
`store (context, NONE)` is the default.
`route` counts the units taken so as `stored`; an observation `store-missed`
says why one was not (1, no entry held; 2, no sidecar; 3, another compiler's;
4, another unit's; 5, a binder another; 6, a place another; 7, it did not load).

### Loading by need

`lazy (context, true)`, the default, has a context load its units by need, as
a compile's warm path does (`docs/units.md`, *A warm build*). A unit taken
without being elaborated, from a store or from its own pickle again after a
walk, whose usages hold by the units that bound their names, is registered and
its names bound by the keys its basis binds, and its basis is not read: it is
read when a later unit names what it declared. The keys, and the paths its
top-level names reach (below), are kept with the unit and in its sidecar.
Until a walk takes a unit so the environment is whole, and nothing differs.
After, a unit elaborated sees a view: the initial environment, less what a
unit has bound since, and of each name its text has the binding its binder
gave (`UnitBasis.lazyView`). What it looked up must be in the view and what its
basis names loaded; else the context loads every basis from then on and checks
again so, which an observation `lazy-refused` reports with the reason. A
question of what is visible at a place sees every name. Three things keep the
answers a whole environment's:

* A unit that registers an overloading, which the units after it use by no
  name, is loaded whole at its place, and a walk enters its registrations
  again as it goes, so that those of the units before a place, and only those,
  stand there. E24's `type mismatch between int and int` on HOL4 was such a
  registration lost.
* A type is printed by the path the whole environment has (`Env.pathOf`): the
  least, by a key, of the paths that reach it through at most four
  structures, which is the least of the paths through each top-level name. A
  view's own paths are compared with those of the top-level names it does not
  hold, which an index of what each unit's top-level names reach gives by the
  type's stamp (`UnitBasis.unitPaths`, `Env.beyond`). So a view prints
  `RuneStatus.status`, as the whole does, and not `OS.Process.status`.
* A walk that takes units out of the compiler state takes them out of the
  tables of loading by need too.

`route` counts the units taken without their basis as `byNeed`.
`lazy (context, false)` loads every unit's basis; `tools/lsp/oracle.sml`'s
fresh contexts, which are the truth, do.

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

Build-document queries belong to `CompilerApi.Project.buildSyntax` and
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
uninterruptible phases. The API sets no bound of its own on a check's
inputs, their number or their text: what an analysis holds is the scale
target's (`docs/language-server.md`, *The scale target*), and the worker's
heap and the documents' limits are a server's. `Busy` rejects re-entry of
an active analysis context.

Occurrence ranges describe compiler syntax constructs and can include
more than an identifier. Editing consumers derive exact token selections
and validate edits through fresh analysis. The server's rename and other
editing providers remain unadvertised until their own acceptance gates.
