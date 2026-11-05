# The Rune Language Server

`runelsp` is the standalone LSP adapter for Rune. The current implementation
provides stdio transport, initialization, capability/position-encoding
negotiation, progress tokens, tracing, shutdown and versioned document
synchronization. Compiler-backed diagnostics, hover, navigation, symbols
and lexical completion are implemented. The server remains under
development: [the roadmap](plans/language-server.md) records outstanding
feature, performance and platform acceptance.

## Build and launch

For VS Code, `make dist-vscode` produces an installable VSIX containing
private Linux and Windows x86-64 runtimes and a fallback Basis. It supports
Remote WSL and does not use Rune executables from PATH or the workspace's
build outputs. See [the extension guide](../editors/vscode/README.md).
For Rune development, set `runelsp.libraryRoot` to the checkout's `lib`
directory as a file URI so analysis follows saved library edits: a
library's index follows its `library.build` and its files, with nothing to
run after an edit ([build.md](build.md), *A library's index*).

```
make lsp
bin/runelsp --stdio
```

Configure an LSP client to launch the worktree's `bin/runelsp` with
`--stdio`. Running without a transport option also selects stdio. The
generated wrapper supplies the library directory relative to the installed
tool layout; `--lib DIR` can override it for subsequent project analysis.
Use `--help` and `--version` outside a protocol session.

The incoming body limit is 16 MiB by default, configurable with
`--max-message-bytes N`; headers are limited to 8192 bytes. Messages use
Content-Length byte framing and UTF-8 JSON. Logs go to stderr; stdout
contains protocol frames only. A truncated or malformed transport closes
the connection with a failure status.

Open documents retain the client's URI and decoded UTF-8 text. Incremental
changes use the negotiated UTF-8, UTF-16 or UTF-32 coordinates. Changes in
one notification apply in order, atomically; malformed transitions retain
the last valid text and require a subsequent full replacement or reopen.
Save notifications never replace a newer overlay.

The current connection limits are 512 documents, 4 MiB per document
(also bounded by the incoming-message limit), 64 MiB total document text,
200,000 lines per document and 500,000 total indexed lines. Invalid or
over-limit updates are rejected before publication. Source analysis and
worker resource limits are separate.

## Static analysis and queries

Files listed by the configured library root's `basis/library.build` use
the Basis bootstrap context: they are checked in build order from the
initial environment, with primitives enabled for that context. The server
does not preload a sealed copy of the Basis before checking its own sources.
A configured program target that does not contain a Basis file does not
prevent selecting its owning Basis build. Ordinary programs retain their
normal primitive restrictions.

A supervised foreground child process owns program compiler sessions. Basis
sources use their own foreground worker, so switching between a program and
its Basis does not evict either analysis from the other's retention budget.
The connection continues
reading requests while analysis runs; foreground queries precede queued
background checks. Concurrent providers for one document revision and
workspace generation share a single check. Cancellation
receives one response and interrupts the child, with process termination as
a fallback; cancelling one provider preserves a check with other waiters.
Worker restart drops references to its old snapshots.
Automatic workspace diagnostic pulls use a separate supervised worker, so
they cannot evict foreground views or hold up navigation and document queries.
Each background context releases its compiler session and analysis snapshots
after producing its diagnostic reports. Cancellation replies immediately and allows each worker
250 milliseconds to acknowledge before process termination.
Workers start lazily: at most one for programs, one for Basis sources and
one for workspace diagnostics. A restart invalidates only its own results.
Read-only opens/closes whose text matches disk and identical inherited
configuration replies preserve the workspace generation. Unsaved opens,
discarded edits and actual configuration changes still invalidate it.
Unchanged per-file settings do not refresh every editor presentation.

Each worker uses Rune's optimizing JIT, with a 512 MiB VM heap cap and a
1.5 GiB process address-space cap
(including both copying spaces and native code). A job's deadline is a limit
on silence, not on work: a worker that reports no progress for 30 seconds is
lost, and one that goes on reporting is not cut short, however long a first
check at scale takes (*The scale target*, below). Planning reports that it goes
on every second or so, a check each unit it reaches.
A measurement at a scale over them says otherwise with `RUNE_LSP_HEAP_LIMIT`
(bytes), `RUNE_LSP_ADDRESS_SPACE_MB` and `RUNE_LSP_DEADLINE_SECONDS`.
A workspace sweep's contexts have the same limit, with none on the sweep as a
whole. Each context's diagnostic
or symbol results are collected before the next context is checked, so the
response does not keep evicted analysis snapshots alive.
The Rune Language Server Output channel shows the workspace context count,
each context as it starts, and progress about every five seconds: the current
file and phase, checked/reused unit counts, and elapsed time. Document checks
start reporting after two seconds. Completion is logged for reported work.
Clients supplying a work-done token receive these intermediate reports through
`$/progress` as well. Progress extends a job's deadline, and never cancellation's grace.
A client that asks for it hears what the server is doing as well, whether or
not a request brought a token: *Status for a client that asks*, below.
The background worker retains at most one diagnostic report cache, bounded
to 4 MiB of encoded reports. Unchanged workspace polls reuse those JSON
reports without retaining analysis snapshots or logging another sweep.
Captured source/build content, the content or absence of each
`library.build` above a source (whose index says what the source is to the
libraries), root build-file membership, settings and overlays guard reuse.
Saved changes are detected even without a watched-file notification;
previous result IDs still produce unchanged reports.
Acknowledged file watches let cached workspace polls skip content hashing
for covered SML, signature and build files. Watch notifications
invalidate those reports through the input generation. Coverage is trusted
only after registration succeeds and the cached content baseline is valid.
Unwatched paths and refused registrations retain content validation; a full
fingerprint validation also runs at least once per minute of polling.
Document pull reports are cached separately from semantic snapshots, with
at most 512 report identities and 4 MiB of encoded report bodies per connection.
Polling an unchanged document can return a full or unchanged report even
after its semantic view was evicted. Recomputing the same report for the
same input generation does not request another global diagnostic refresh.
Real input changes still refresh dependent diagnostics, including when the
active file's own diagnostics stay empty; changes during a pending refresh
coalesce into a follow-up after its acknowledgement.
Queries waiting on a freshly checked view run before another check can evict it.
Workspace diagnostic scope follows the workspace's project builds; merely
opening a Basis or loose file does not add another background context.
Those open files receive document diagnostics. Read-only buffer membership
and document context choices do not invalidate cached workspace reports;
buffer versions are refreshed when serving them. Content fingerprints use
the current overlay while a file is open and disk content after it closes.
Contexts and frozen views each retain at most four entries and charge at most
2 MiB of source text across entries; a single larger entry can occupy the
cache alone. Shared text is charged separately per view. These are retention
budgets, separate from the document and process limits. Unchanged unit
occurrence projections are reused with the compiler's validated unit keys.
Each view also retains at most eight frozen completion-scope answers with
a 1 MiB charge for strings and record overhead. Unchanged captured source
slots reuse position/token indexes only when file, mode and exact text match;
semantic syntax still comes from the new compiler snapshot.

Worker stderr is captured privately: at most 4 KiB is retained, a 64 KiB
stream terminates the worker, and heap exhaustion is classified immediately.
Infrastructure failure completes all waiting providers once. Further checks
of that failed document revision and workspace generation return the same
failure until an edit, dependency/configuration change, close/reopen or
`Rune: Restart Language Server` permits another attempt.
An unresolved build-context choice is a quiet server cancellation, rather
than an infrastructure failure. (The VS Code extension takes it as an empty
report: `vscode-languageclient` 10.1.2 stops pulling a document after such a
cancellation, so a later choice would show nothing.) Selecting a context invalidates foreground
providers and their cached cancellation without an edit or restart. It does
not invalidate unchanged closed-project inputs or other pending context prompts.

Infrastructure errors identify the worker PID, job ID and operation, request
method, document or snapshot, elapsed time and configured limit. Analysis
jobs also report their selected build context and last compiler phase/file,
with checked/reused unit counts. The progress age is measured at failure
time. For example:

```text
runelsp: analysis worker exceeded its deadline
  worker PID 12345, elapsed 95.003 s, limit 30.000 s with no progress, job 7 (check)
  document: file:///home/me/rune/src/main/rune-main.sml
  executable: /private-extension/server/bin/runevm
  context: rune (file:///home/me/rune/rune.build)
  last reported phase: unit-elaborated at /home/me/rune/lib/compiler/elab/elaborate.sml (checked 187, reused 0; 30.002 s before failure)
```

Progress travels over the private worker pipe. Error metadata is bounded; control characters and invalid native
filename bytes are escaped. Captured source contents are excluded.

The server supports push diagnostics and document/workspace pull reports,
unchanged result IDs, refresh, work progress and workspace partial reports.
Pull clients receive refresh instead of duplicate pushes. Publications must
match the current source revision and workspace generation. Workspace
queries check sources from configured or discovered build plans, including
closed sources and disk-only changes.

Hover and declaration/definition/type-definition/implementation navigation
use compiler type and binding records. Hover answers at every node of the
syntax: the first question about a declaration at top level works out the
type of each of its nodes from what the elaborator recorded of them
(`CompilerNodeTypes`, with AstLint's typer; the linting roadmap's M14), and
keeps them for the unit, with an index from positions to the innermost node.
Where an infix application and its tuple share a span, the application's
type is shown; a binder shows its type with the variables its own binding
generalised named first (`'a. 'a -> 'a`), and a lambda's variable, whose
type may name an enclosing binding's, none. One printer for the unit names
a type variable alike in every hover. Positions no node covers (a keyword)
keep the occurrence records' answer. Document and workspace symbols use
validated source tokens and compiler binding identities. Hierarchical document
symbols nest named lexical scopes, classify declared functions from captured
syntax and merge clauses belonging to one function binding. Parameters and
locals with distinct identities remain separate, including identically named
parameters in different clauses. Function, module and declaration ranges own
their nested symbols; selection ranges identify the declaration's name.
Clients without hierarchy support retain flat symbol locations. Workspace
symbol resolution rejects stale source
and context data. Source is checked statically and never executed.

Completion returns compiler-visible lexical names, qualified members and
keywords, with namespace filtering from compiler syntax. Record selectors
offer labels from a concrete checked operand type. Signature restrictions
apply to qualified completion. Item resolution requires its original
snapshot; edits invalidate old items. Leading declaration comments supply
hover and resolved-item documentation from captured source.

Document highlights follow checked binding identities within the current
source occurrence, including a caret directly after the name. They distinguish
shadowed names and qualified prefixes/members, and mark value uses as reads.
An oversized result produces a request failure instead of a truncated set.
Repeated inputs keep their selected occurrence even when they use different
spellings of the same path; navigation uses the corresponding inferred type.
The remaining presentation features and performance gates are still part of
M9 acceptance.

Folding and selection ranges use captured compiler syntax. Type errors keep
structural ranges available, and parse failures retain current comments and
tokens rather than the previous successful tree. Folding returns complete-line
ranges, respects the client's range limit, and caps results at 8192. Selection
requests support up to 128 positions and 64 nested ranges per position, retaining
the document as the outermost range. Build-file selections use the shared build
grammar's path spans. Split encoded characters and oversized requests fail
explicitly. Negotiated folding refreshes follow workspace/configuration changes;
pending refreshes coalesce and ordinary typing does not trigger a global refresh.

Semantic tokens support full, range and delta requests negotiated with the
client's legend and relative format. Lexical classes combine with checked
value, type, structure and signature namespaces. SML value identifiers use
the generic `variable` class; their immutable bindings can carry `readonly`,
and declarations carry `declaration`. Identifier locations must be unambiguous.
Multiline tokens split at line endings and results do not overlap. Ranges retain
whole intersecting tokens and use the negotiated position encoding.

Token history keeps at most eight results within a conservative 8 MiB estimate
that includes integer storage and keys. Unknown, evicted or restarted histories
produce a full response. Replies exceeding 20,000 candidate spans fail explicitly;
a bounded range can remain available when a full response exceeds that budget.
Negotiated token refreshes follow workspace changes. Other M9 providers and
performance acceptance remain in progress.

Clients supporting inlay hints receive inferred types beside unannotated
variable and alias patterns, including function parameters and case bindings.
The compiler supplies each type, lexical identity and exact name-token location.
Explicitly typed patterns suppress their hints. These are display hints; accepting
one does not insert a source annotation. Visible ranges and positions use the
negotiated encoding, and responses have limits of 2048 hints and 1 MiB.

Tooltip resolution is deferred only when the client supports resolving it.
Resolution uses the original retained snapshot and validates its source revision,
workspace generation and binding. An unchanged background recheck can publish a
newer snapshot while the retained item remains valid; edits, context changes and
eviction reject old items. Negotiated hint refreshes follow workspace changes,
with the same coalescing rules as folding and semantic tokens.

Clients with snippet support also receive invocation templates whose
argument groups follow the checked callable type. Their default argument
expressions use `raise op Match` where a nullary `Match` exception is visible,
so a template can be checked without inventing values or depending on an
infix setting. No completion request executes it. Named-call signature help uses
compiler applications, including curried, tuple and infix forms; parameter
label offsets count UTF-16 units independently of source-position encoding.

Clients negotiating inline completion can request bounded constructor
patterns, using wildcards for constructor arguments. Suggestions must be
compatible with selected-completion information. Other clients retain
ordinary constructor completion. Private incomplete-expression probes do
not replace source or publish their diagnostic/type data. Broader
incomplete-pattern recovery, performance and real-client acceptance remain
open; this is not full M8 acceptance.

Build documents (`.build`, or language ID `rune-build`) use the compiler's
build grammar and project planner. Their diagnostics respect unsaved
overlays. Path completion offers files, directories, configured variables
and installed libraries, including unfinished quoted paths and variables.
Replacement edits supply the required quoting, and stale path-item resolves
are rejected. Build requests do not execute the project or fabricate SML
semantic snapshots. Other semantic providers currently apply to SML sources.

Clients supporting document links receive links for complete build references:
sources, included build files, a header's friends, installed libraries, and a
step's or a preprocessor's tool, inputs and outputs. Path
variables and library directories follow the compiler's rules. Targets resolve
on demand to native file URIs; a missing target fails explicitly. Resolution
checks the original document revision, workspace generation and range. Tooltips
require client support. Unknown variables and unfinished quoted paths are
omitted, and ordinary SML string literals remain ordinary source text.
Responses have limits of 2048 links and 1 MiB, with explicit failures.

The wire adapter offers filenames that can be written in UTF-8 build text;
native filename bytes remain preserved in the public compiler API. Use a
configured path variable for a native name that cannot be written in the
source encoding. Directory/result scans and completion response sizes are
bounded, with incomplete results reported to the client.

## Keeping what is computed

A worker keeps each context's analysis between checks (`docs/compiler-analysis.md`).
An edit that keeps a unit's identity, a comment, a body, costs that unit's
elaboration at the place it was reached and nothing else: no later unit is
walked, reloaded or looked at. An edit that moves an identity, a name added, a
type changed, walks from the start: each later unit is taken by its usages,
reloaded or elaborated again as they say, which is O(later units); its usages
are looked at only where a unit before it in the walk bound a key they name and
changed identity, after a walk that went through to the end (*The scale
target*). What a check
would otherwise repeat is memoised too.

* **The plan.** Discovery and a check share a memo of a file's plan: the targets'
  membership, the file's configuration and its contexts. It holds while the
  workspace's settings, the set of open documents, the text of an open build
  file, the files the plan read, the directories a build
  is looked for in and the places a root file would be, all stand. What says
  that a file stands is the client's file events where it watches the file
  (*File events*, below), and elsewhere its stamp: its time, in whole seconds,
  and its size, so that nothing is memoised by its stamp of a file changed
  within three seconds of being read; it is read again at the next check. A
  plan is made again on any other change, and an edit of a source plans
  nothing: a plan reads build files alone. A plan reads from the disk only
  the builds that changed: the text of each build read is kept while it
  stands, and taken from there (*The scale target*, below).
* **Closed inputs.** Their text is kept while it stands, by the same rule; a
  source is re-indexed only where its text changed.
* **Closed units.** Only the units of the open documents keep syntax, typing,
  facts and occurrences. Another keeps its notes: its facts, occurrences and
  types as bytes, with each type name its facts printed and the path they
  printed it by. A request into it reads them where they hold: where each such
  type name prints by that path still, from where the unit stands now (a path
  depends on the whole environment, which no usage says), and the units whose
  places its occurrences hold by span alone have the text they had. Otherwise,
  and for its syntax or typing, it is opened at its place, at the price of its
  elaboration. So `workspace/symbol` elaborates no unit to say its symbols.
  `textDocument/implementation` needs no notes: a closed unit keeps the
  occurrences it reads.
* **Bindings.** A definition in another unit is held by reference, resolved when
  it is read, so go-to-definition and a binding's identity are right under a unit
  reused across a span that moved.

Through the real server at the 512 MiB heap, from the client's side, a pull
of diagnostics after each edit (`bin/rune-lsp-replay`, 20 comments or 8 body edits,
on 2026-11-03 at a load of 12 to 18 on 16 processors; seconds, p50 and p95):

| Build | First check | Comment at the end of the last file | Body edit |
|---|---:|---:|---:|
| `rune.build`, 246 units with the Basis's | 5.7 | 0.024 / 0.045 | 0.246 / 0.330, `src/driver/main.sml`; 0.045 / 0.067, `lib/compiler/util/source.sml` |
| HOL4's `src/boss` closure, 923 units | 17.5 | 0.132 / 0.152 | 0.357 / 0.369, `patternMatchesLib.sml` |
| A generated build of 351k lines, 3,016 units | 49.1 | 0.188 / 0.223 | 0.129 / 0.139 |

A body edit costs that unit's elaboration with its facts and pickle, which is
most of each figure. A comment at the start of an early file costs the same as
one at the end: it moves spans, and no identity. An edit that moves an identity
walks: in process, on `rune.build`, a name added to `lib/compiler/util/source.sml`
takes 0.15 to 0.3 seconds, reloading the 79 units after it, and a constructor added
to its datatype about 1.2 seconds, elaborating the 13 whose usages it breaks.

Nothing here is allowed to change an answer. `bin/rune-lsp-oracle` keeps a
context through a list of edits, and after each compares every fact, occurrence,
type, diagnostic and query with a fresh analysis of the same inputs, which keeps
every file open, on every unit; it fails a run that did not take each path it is
told to. `make test-lsp-oracle`, part of `make check`, runs it on the compiler's
own build three times: with every file open; with one, and the Basis Library's
units taken from another context (`--share`); and with one, cold from a store a
compile at `-O0` made, whose units are taken from it (`--store`, *The store*,
below). `make test-lsp-oracle-corpora`, in the nightly tier, on HOL4's closure
and MLton (`tests/lsp/README.md`).

### The store

Where the build has a store (`docs/units.md`, *The store*: `.rune` beside the
workspace's `rune.workspace`, or `RUNE_CACHE`), the server reads it: a compile's
entries, and its own sidecars. It makes no store, and writes no entry.

* **A compile's entries, as a static layer.** A unit no context holds, whose
  file is not open, is taken from an entry of a compile whose usages hold where
  the unit is reached, by their binders. Only its static layer is read, and of
  the ABI layer only what the static layer names, so a compile's entry and an
  analysis of the same text load the same; an analysis knows a unit by its
  static layer's identity, so that a body edit moves none, and a compile's
  entries name the units it loaded under their whole identities, which are the
  same units to it. The configuration is split: an entry of any configuration
  whose static settings are the server's (the compiler, the formats, the hash
  and the language's settings) serves, whatever its level, passes, fuel,
  target or integers' width, none of which moves a static layer.
* **Sidecars.** A compile records no origins, so a unit is taken from its
  entry only with its sidecar, which an analysis of the same text wrote: the
  origins its basis's names have, its notes, its types, the names its text
  mentions, the binder of each name it looked up, the keys its names are bound
  by and the paths its top-level names reach (with which it is taken by need,
  below), and the compiler that wrote it. A sidecar is kept by the hash of the source and its format, not by the
  compiler: after an upgrade it is still found, and taken for nothing (a hint,
  never an answer); the unit is elaborated and its sidecar written again. One
  whose unit is another, or whose names another unit binds now, or whose
  places another text holds now, is not taken either. A sidecar is written for
  each unit a check elaborates from the text its file has, never from a buffer
  not saved, and goes when the store is trimmed.

So a cold start costs what reading the store does, and an edit what a kept
context's does. A body edit of a unit taken from a compile's entry keeps its
static identity, and so every unit after it, which a compile's usages name under
the compile's identities: E24 found 55 of the 79 units after
`lib/compiler/util/source.sml` broken by such an edit, and now none is. An edit
that moves an identity walks: a unit taken from a compile's entry holds its
usages by the compile's fingerprints, which an analysis's never equal, so
before the walk takes the changed unit out, what each unit after it used of it
is worked out again in the analysis's terms, where the unit still stands, as an
analysis that elaborated them would have recorded it. `make test-lsp-oracle`'s
third run shows both: a name added to `source.sml`, cold from the store, breaks
no usage, and a constructor added breaks those that used the datatype.

Cold from a store, in process, no file open (`bin/rune-lsp-oracle --focus --store
DIR --no-fresh --collect`, a seed context having written the sidecars; 2026-11-04,
one store each, by need, the default, and with every basis loaded, `--eager`;
VM instructions the claim, and seconds the best of three runs each on a
processor of its own, but the generated build's, the better of two at a load
of 2, its runs on a processor of their own having met a load of 13 to 17;
lines are the program's, the Basis Library's added but on the generated
build):

| Build | Lines | Units from the store, by need | Cold, every basis / by need | VM instructions | Live after | A line |
|---|---:|---:|---:|---:|---:|---:|
| `rune.build` | 67,338 | 259 of 260, 253 | 0.42 / 0.35 s | 0.346G / 0.314G | 28.4 / 19.6 MiB | 0.43 / 0.30 KB |
| HOL4's `src/boss` closure | 231,714 | 907 of 910, 902 | 1.18 / 1.05 s | 1.099G / 1.005G | 100.6 / 69.3 MiB | 0.44 / 0.31 KB |
| A generated build of 1.13M lines, 9,021 files (`gen-as-run.py`, `--domains 32`) | 1,133,346 | 9,015 of 9,016, 9,014 | 14.8 / 7.6 s | 10.33G / 6.34G | 567.8 / 350.0 MiB | 0.51 / 0.32 KB |
| MLton's 606 files | 217,107 | 762 of 764, 755 | 25.1 / 1.13 s | 7.37G / 1.53G | 1,487.7 / 118.7 MiB | 7.0 / 0.56 KB |

A unit is not taken where no entry of a compile holds by its binders, as on
`rune.build` at the defaults the Basis's `seal_textio.sml`, whose compile took
its entry from the frozen libraries across a change, by fingerprints a static
layer does not say; or where its sidecar is another unit's, two files with one
text, as HOL4's two `Systeml.sig`. Of those taken, a unit that registers an
overloading is loaded whole (below); the rest only where a unit elaborated
after them names what they declared. MLton's signatures are copied into each
unit that loads them, so that its static layers hold 7 KB a line when every
basis is loaded; by need it holds 0.56 KB a line, within 2 KB.

### Loading by need

A context loads its units by need (`docs/compiler-analysis.md`, *Loading by
need*), as a compile's warm path does: a unit taken from the store, or from
its pickle again after a walk, whose usages hold by the units that bound their
names, is registered and its names bound, and its basis is not read until a
unit elaborated after it names what it declared; that unit sees what its text
names. The answers are a whole environment's. `make test-lsp-oracle`'s second
and third runs and the corpora's take units so, hold the context to a fresh
one that loads every basis, and fail where none was taken so, or where a unit
read outside its view, which has the context load every basis from then on.
HOL4's datatype edit of `Feedback.sig` and MLton's of `control-flags.sig`,
which gave E24's false type errors under its lazy world, agree with a fresh
analysis on every unit: those were an overloading's registration a walk lost,
which a unit that registers one, loaded whole at its place, no longer loses,
and the tables of units a walk took out, which it now clears.

An edit costs a little more: a unit taken by need costs a registration where
it cost a load, but each unit elaborated after an interface edit sees a view
and loads the bases its text names, and a unit taken by need has the paths its
names reach entered. HOL4's closure, no file open, kept context alone
(`--no-fresh`), in VM instructions: a comment or a body edit the same; a name
added to `Feedback.sml` 0.37G by need against 0.29G with every basis; a
constructor added to its datatype 5.94G against 5.56G, elaborating 204 units
either way. From no store,
a cold check elaborates every unit and so loads every basis: MLton holds
1.58 GiB after it, no file open, as before, and 184 MiB once a name added to
`layout.sml` and taken out again has had the 561 units after it taken by need.

## The scale target

The editor's scale target is the build-system roadmap's D28: cost functions,
not a size at which the server stops. The table gives each row and what it
measures at the sizes the tiers below run, on generated trees
(`bin/rune-lsp-fixture`, `tools/lsp/fixture.sml`): a tree of 100k files and 1000
builds, the build files alone, which is the 10M-line tree's (lines change the
sources alone), and a build of 130,793 lines in 1,017 units with its 10 builds
(`--lines 100000 --files 1000 --builds 10`). A program names its libraries
(`libraries NAME`, under the tree's `rune.workspace`), and the whole tree's
build has every library's files as its own, in load order, so that its context
is all 1,017 units. Times are 2026-11-04's, two runs,
on 16 processors at a load of 12 to 14, the worker's heap at 512 MiB; the
planning row's are 2026-11-05's, on the build-system roadmap's last commit,
two runs at a load of 1.5 to 3.3.

| Scope | Target | Measured |
|---|---|---|
| A workspace: 10M lines, 100k files, 1000 builds, each a target | Planning a check at most 200 ms, reading no build outside the changed set | After a change, reading the changed build alone: a file of a library 18-32 ms, a program's own file 33-65 ms (medians, a touch to an added or removed file). With no build changed, its memo, 6-16 ms. The first plan 0.08-0.1 s, a program's 7.6-9.3 s. 134 MB live at most, 186 MB resident, in the worker's 512 MiB |
| A context: one closure of 1M lines, 10k units | At most 2 KB a line resident | 0.33-0.39 KB a line, from a store, after every edit; 0.32 KB at 1.13M lines (*Loading by need*) |
| Cold from a store | Seconds at 1M lines | 0.97-1.39 s in process, every unit from the store, 2.5-3.7 s through the server; 7.6 s at 1.13M lines |
| A leaf comment | p95 at most 250 ms | 0.052-0.055 / 0.065-0.075 s, p50 / p95 through the server |
| A body edit | That unit's own elaboration, on top | One unit elaborated, at its place; 0.040-0.050 / 0.059-0.063 s through the server |
| An interface edit | O(clients) | The edited unit and its clients elaborated (2 units for a name added to the first module, 32 for a constructor added to its datatype, which 30 files use), and only their usages looked at; every later unit is still taken again by need: see below |
| Hover | At most 50 ms | 7-18 ms through the server |

* **Planning** reads only what changed. A file of a library is checked in its
  library (*A file's context*), so its plan is made from the targets over its
  owning library alone where those hold it, and the rest are not read: the
  answer is the one enrich and the choice of a context come to, which
  `bin/rune-lsp-contexts --owned` holds them to over every file of this
  repository's builds, with every build a target and with none (734 of the
  879 files of its 127 builds planned so, none different; the other 145
  below). A build's
  text is kept while it stands and taken from there, so that a plan reads from
  the disk only the builds that changed; a path's key and a file's identity
  are kept too, the second while events vouch for it.
* **A file of no library**, a program's own file, is planned from an index of
  what each build names (`RuneLspProjects.indexed`): each build, under the real
  directory of the spelling a plan reaches it by, with the files it names, by
  key and by identity, and the builds it uses. A target holds the file only if
  its build reaches a build naming a file that is the file: a superset, of
  which each target is read as enrich reads it, and only it, which makes the
  answer exact. A build that does not parse, names a path with a variable, or is
  not there, may name anything. The index is kept between plans, a build taken
  again where its text changed and a file looked at again where an event names
  it, or at every plan where no event can; a target's project is kept while
  every build it read has its text. A file not on the disk (one not saved yet)
  has no identity, and takes the whole way. `bin/rune-lsp-contexts --owned`
  holds the index to enrich too: with every build a target, the 145 files the
  owner does not settle are all planned by it, none differently; with none, 72,
  and the other 73, which no root's build holds, go by discovery. Before it, such
  a file's plan at 100k files and 1000 builds took 558 s cold and 343-413 s
  after a change, in 2.8 GB; at 10k files and 100 builds, 5.7-8.2 s.
* **An interface edit** elaborates the units whose usages it breaks and no
  other. A walk takes each unit after the edited one again, by need, but looks
  at the usages of only those that name a key a unit before them in the walk
  bound, before or after, and was elaborated to another identity: a later unit
  taken again has its identity, so at its place no other binder can have
  changed, and every unit the last walk kept held there. That holds where the
  last walk went through to the end, from the start, over the same plan and
  libraries, and the units come in its order; a walk stopped by a unit that
  fails, or a question's, leaves later units as an earlier walk kept them, and
  the next walk looks at every usage (`compiler-analysis/past-a-failure`, which
  fails where it does not). What a later unit's
  usages and pickle ask of it is kept with it while its binders stand. So a
  later unit costs about 40k VM instructions, where it cost 340k: at 1,017
  units an added name 122.6M (0.15-0.17 s) where it cost 349.7M (0.30-0.48 s),
  and the datatype edit 454.4M (0.89-0.95 s) where it cost 685.5M (1.25-1.42 s),
  in process. That is still O(later units), with a seventh of the constant, not
  O(clients): every later unit is taken again and its keys registered. Keeping
  a later unit without taking it again needs the walk not to cut it, and so the
  binders of each place after the edited unit, the tables of units loaded by
  need, their order and the paths a type is printed by, to change in the
  middle, which none of them does.
* **The caps.** An analysis has no cap of its own on its inputs, their number
  or their text: the 10,000 inputs and 128 MiB are gone. A job's deadline is a
  limit on silence (*Static analysis and queries*). The worker's 512 MiB heap
  stays: it holds the 130k-line build with room, and a context of 1.13M lines
  holds 350 MiB loaded by need.

`make test-lsp-scale`, in `make check`, holds what the machine's load cannot
move: on the 100k-file tree, with file events and at the worker's heap, that a
plan of a library's file and of a program's own after a change reads no build
outside the changed set, and one after none takes its memo;
cold from a store a compile of the 130k-line build made, that a body edit
elaborates its unit alone, an interface edit no unit but the edited one and
those whose usages broke, and that at most 2 KB a line lives after each
check (`bin/rune-lsp-plan-bench --reads`, `bin/rune-lsp-oracle --clients
--per-line 2048`, scenarios `tests/lsp/oracle/scale.tsv`). `make
test-lsp-scale-times`, in the nightly tier and on a machine of its own, as
every timing is (`docs/testing.md`), holds the times: a plan of either file at
most 200 ms at the median of five, a leaf comment's p95 at most 250 ms and hover's 50 ms
through the server (`bin/rune-lsp-replay --limit`), and cold from the store
within 2 s. `make test-lsp-scale-oracle`, nightly, holds the kept analysis to
a fresh one on every unit of the 130k-line build after each edit: 20 checks,
no disagreement, about twelve minutes, which `make test-lsp-oracle` does on
the compiler's own build in `make check`.

### File events

Where the client watches files (`workspace/didChangeWatchedFiles`, registered
for `*.sml`, `*.sig`, `*.fun`, `*.build` and `rune.workspace`), the
server keeps the last 4096 files its events named, with the generation each
made, and each job carries them. What a plan or a check read at a generation
stands while no event since names it, or, of a directory, no file that came
into it or went, with no look at the disk: a file of those names under a folder the client
watches, by the key an event would name it by (a path with `..` where that is
the same file). Elsewhere, where the events since are not whole, and a minute
after the disk was last looked at, the stamp decides, as the bound of an event
the client dropped. So an edit of the open file plans nothing and looks at no
file, and a changed build is read again alone.

**Entries on save** (D27 D) were measured and not built. A compile in units of
`rune.build` after a body edit of `src/driver/main.sml` costs 1,163.7M VM
instructions (3.6-4.2 s), against a no-op's 3.3M (0.14 s); after a build run
on the save, the user's build costs 878.3M (1.9-4.4 s): the build on save ran
within three seconds of the save, so the up-to-date record was not written and
the next build takes every unit by the warm path. A build on save delayed past
that window would leave a no-op, at the price of a whole build after every
save, which an editor that saves as one types makes continuous, and only where
the user's build is the one the editor ran, with its flags. That is work moved,
not removed, by a mechanism with one user, the editor's save, which this
project does not add for one case.

## Workspaces and build contexts

The server accepts initial workspace folders, legacy root settings and
folder changes. With client support it requests scoped `runelsp`
configuration and dynamically registers file watchers; refusal retains
startup settings. Closed-file contexts are revalidated when queried.

Initialization options use the same settings object as `runelsp`:

```json
{
  "target": "registers",
  "sourceMode": "ascii",
  "libraries": [],
  "pathVariables": {},
  "targets": [
    {"name": "application", "build": "file:///project/application.build"}
  ],
  "activeContext": "application"
}
```

`target` is `registers` or `stack`. Source modes are `ascii`, `unicode`
(`unicode=utf8`) and `unicode=latin1`. `libraryRoot`, when supplied, is a
file URI; path-variable values are directory file URIs. Targets may
override compiler settings, libraries, path variables and the library root.

Without explicit targets, a root file (`rune.workspace`,
[build.md](build.md), *The workspace*) gives a file its named targets, with
their options after the settings' flags, whether the root file is inside the
client's folder or above it; a workspace sweep of a folder inside a workspace
reads the folder's own builds alone. A root file open in the editor is read as
it stands, saved or not, and an edit of it plans a file's check again, as an
edit of a build file does. Beside those, discovery examines
the document directory and its ancestors up to an owning workspace root,
following build `use` edges. It does not recursively scan descendants.
Project source order, scopes and annotations come from `CompilerApi.Project`,
which is given the root file above each build, so that a unit has the name it
has in a build ([units.md](units.md), *Names*).

### A file's context

A file has one context where it can (the build-system roadmap's D26), and a
choice is asked for only where its contexts really differ.

* **One owner.** A file of a library, below the deepest directory above it
  with a `library.build`, as its unit's name says, is checked in that library's
  build, whatever else names it: a program that reaches into the library, or a
  test's build, gives it no other context. Where the library's build does not
  hold the file, the others stand. A setting's `activeContext` is taken as it
  says.
* **Several contexts.** Where a file still has several, the server checks it in
  each. A context whose check stops before the file, at an earlier unit's error,
  is dropped. The rest are compared by what each occurrence of the file's names
  resolves to, the place of its definition and its declaration, by paths whole,
  and by the file's own errors, never by a printed type, which depends on what
  was selected (`SML90.instream` or `TextIO.instream`). A place is the file
  go-to-definition opens, so that one file named two ways is one place: a
  library's build names its sources from its own directory,
  `libraries/table/../../table.sml`, where a program's build names `table.sml`.
  A virtual module's name, one a `_virtual` or a `_dynamic` declaration binds
  (*A virtual module*, below), is compared by the signature its declaration
  gives, as written, and not by the declaration's place. Where they agree the
  file is checked in the first, and nothing is asked; the file still has them
  all, and a client that asks can choose another (*Status for a client that
  asks*). The comparison is made once while the file's plan holds, and its first
  discovery pays a check of each context: in this repository, 8.5 s for
  `build/config.sml`, in five builds, and 5.4 s for `src/isa/isa.sml`, in three
  (2026-11-05, at a load of 3).
* **A virtual module.** A client of a virtual module ([build.md](build.md),
  *Virtual libraries*) is compiled against its signature alone, whichever
  implementation a build names or a plugin gives, and a build that names
  another implementation compiles none of the client's units again: so its
  builds are compared as above, and agree.
  Go-to-definition on the module's name in the client goes to the declaration
  the client is compiled against, in the context the file is checked in: the
  `_virtual` declaration, a program's own or a virtual library's, or a plugin
  build's `_dynamic` one. It never goes to an implementation, which no client's
  code reaches, and go-to-implementation finds none. Where two builds declare
  the module with signatures written differently, the choice is asked for.
* **A real choice.** Where they differ, the server requests a context choice,
  of those that reach the file; it does not select by enumeration order. A
  configured target name or the returned context identifier can also select one.
  Dismissal or unsupported client UI leaves the context unresolved. Document
  synchronization remains available while semantic analysis awaits an explicit
  selection. The prompt is shown once: a file whose prompt was dismissed is not
  asked about again until it is closed or the settings change. A choice lasts as
  long.
* **Sweeps.** A workspace sweep asks no one: a file with several contexts is
  checked in its first, so that a sweep covers every file of the builds it reads.

In this repository (`tools/lsp/contexts.sml --builds`, the 880 sources of the
113 of its 127 builds that the server can read as they stand, as a client
whose folder is its root sees them), 739 files are a library's, 24 have several
contexts, and 1 asks for a choice: `tests/ffi/win32/native/config.sml`, whose
builds are for 32 and 64 bits. `examples/virtual/table/main.sml`, the client of
the virtual functor `Table` in five builds, asked too, until places were
compared by the file they open and a virtual module by its signature. A sweep
covers all 154 files the root's targets hold. When these rules came, on the 834
sources of 76 readable builds, the prompts fell from 124 to 1, and a sweep from
153 of 220 files to 220.

### A file in no build

Most SML files are in no build: a test, a script, a bug report. Such a file has
an implicit library over its directory. The server reads the names the file
uses from its syntax (`CompilerApi.Syntax.names`, what `rune --deps` reads;
[units.md](units.md), *Well-formed units*) and looks for each where it is
declared: in the file's own directory, then anywhere in its workspace (the root
file's directory, else the client's folder that holds the file, else its own
directory), the nearest first by the directories they share. A file found in a
library that lets the name out is not taken: the library is imported, as a
build would import it. A name the Basis Library provides is its; a library none
of whose files was read is imported by its `library.build`: what its header
exports, or else all its files declare. What is found is looked
through in turn, and the file is checked after it all, as a build no file holds,
beside it, read through an overlay. It is analysis only: no batch build reads it.

The index is of every SML file under the workspace, but those of a hidden
directory and of one with a root file or a repository of its own: a scan of each
file's text for the names after `structure`, `signature` and `functor`, which a
parse of the file confirms where one is looked up; both are kept while the
file's stamp stands. A type or a value at the top level is not looked up, and
nor is a name a file reaches only through an `open`. The tree is walked again
at most every 30 seconds, which file events do not shorten; a file a name
is found in is read by its stamp in any case. The first walk and scan of this
repository's 3,983 files take about 2 s.

On the build-system roadmap's sample of 726 files in no build (E22, E24), the
same files on this tree, each checked as the server checks it
(`tools/lsp/contexts.sml --zero`):

| Each file checked | Clean | An unbound name | Another error |
|---|---:|---:|---:|
| Alone with the Basis Library, before (E22) | 251 | 416 | 59 |
| In the nearest build (E24) | 262 | 390 | 74 |
| Alone with the Basis Library, on this tree | 251 | 420 | 53 |
| In its implicit library | 517 | 145 | 62 |

Two files fail both ways: one is not UTF-8, and one makes the analysis fail
rather than report. A file's plan and check take a median of 0.06 s and 0.48 s
at the 95th percentile, in one process after the index is built; a context
holds a median of 2 files, and 107 at most.
Of the 145 whose first unbound name remains, the name is declared nowhere as a
structure, signature or functor for 45, and the rest are mostly what syntax
cannot know: a host's own structures (`MLton.Signal`), a test whose command line
imports the compiler library's `CompilerApi`, and error tests meant to fail.

### Past the first error

A unit that fails reports each top-level declaration that does not elaborate,
as a compile does ([units.md](units.md), *Errors*), and each syntax error;
what it declares past them is checked, and answers hover, completion and the
rest. The units after it are not reached: a file among them reports that an
earlier source could not be checked.

### Two builds over one library

A unit of a library is the same unit in every build over it, so the server's
contexts share them (`CompilerApi.Analysis.share`): a context that reaches a
library's unit it has not held takes the one another context checked last,
under the same compiler configuration, by its usages, as a compile takes an
entry of its cache, and elaborates it where they do not hold. In this
repository, `tools/lsp/oracle.build` checked after `runelsp.build` takes 254 of
its 257 units and elaborates 3: 0.49G instructions and 2.2 s, against 1.98G
and 5.6 s alone (`tools/lsp/contexts.sml --share`). `make test-lsp-oracle` holds
a context that shares to fresh ones that do not.

## Status for a client that asks

A client can ask, under `experimental` in `initialize`, to be told what the
server is doing and which context each file is checked in, and can then choose
a file's context at any time. The VS Code extension does, for its two items in
the `{ }` menu. Other clients see nothing of this: they get no `rune/` message,
and the prompt stays theirs. [The protocol](lsp-protocol.md#status-for-a-client-that-asks)
gives the messages.

`rune/status` says that the server is busy while it discovers, checks or sweeps,
what it is doing and the context and units checked and reused, and after a
check the same of the last one. A hover or other query does not count as busy,
and nor does a workspace poll that its cache answers. Severity is an error from
a worker's failure until a check in that worker succeeds. The server looks
every 250 ms and sends what changed, so work shorter than that may not show.
`rune/context` goes when a
file's context changes: the one it is checked in, or that it has none or is
waiting for a choice, and those it could have. `rune/setContext` takes the path
a prompt's answer takes, for a context the last `rune/context` of that file
offered.

## Editor syntax

The compiler library also provides `CompilerApi.Syntax`, a separate SML
editor parser with immutable snapshots, lossless source pieces, recovery,
cross-file fixity environments and lexical/declaration reuse. It is tested
against the batch parser and supplies server analysis. Performance and
recovery acceptance remain in progress; source-editing providers such as
rename and formatting remain unadvertised.

## Protocol and acceptance

[The protocol contract](lsp-protocol.md) records implemented behavior and
compatibility rules. The generated specification inventory describes the
entire upstream protocol; it does not advertise unimplemented providers.

```
make test-lsp-protocol
make check-lsp-protocol
```

The first target runs portable wire-value/request-ownership tests and
independent stdio transcripts, including an interactive client that keeps
its input open. The second checks the pinned generated inventory. The
[test and measurement guide](../tests/lsp/README.md) describes fixtures and
the recorded initial baseline. Native editor/platform acceptance is
recorded separately as it is performed.
