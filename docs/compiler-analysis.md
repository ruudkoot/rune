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
