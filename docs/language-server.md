# The Rune language server

`runelsp` is the standalone LSP adapter for Rune. The current implementation
provides stdio transport, initialization, capability/position-encoding
negotiation, progress tokens, tracing, shutdown and versioned document
synchronization. Compiler-backed diagnostics, hover, navigation, symbols
and lexical completion are implemented. The server remains under
development: [the roadmap](plans/language-server.md) records outstanding
feature, performance and platform acceptance.

## Build and launch

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

A supervised child process owns compiler sessions. The connection continues
reading requests while analysis runs; foreground queries precede queued
background checks. Background checks coalesce per document. Cancellation
receives one response and interrupts the child, with process termination as
a fallback. Worker restart drops references to its old snapshots.

The server supports push diagnostics and document/workspace pull reports,
unchanged result IDs, refresh, work progress and workspace partial reports.
Pull clients receive refresh instead of duplicate pushes. Publications must
match the current source revision and workspace generation. Workspace
queries check sources from configured or discovered build plans, including
closed sources and disk-only changes.

Hover and declaration/definition/type-definition/implementation navigation
use compiler type and binding records. Document and workspace symbols use
validated source tokens; workspace symbol resolution rejects stale source
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

The wire adapter offers filenames that can be written in UTF-8 build text;
native filename bytes remain preserved in the public compiler API. Use a
configured path variable for a native name that cannot be written in the
source encoding. Directory/result scans and completion response sizes are
bounded, with incomplete results reported to the client.

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

Without explicit targets, discovery examines the document directory and
its ancestors up to an owning workspace root, following build `use`
edges. It does not recursively scan descendants. A loose file without a
workspace checks its own directory. Project source order, scopes,
annotations and group ordering come from `RuneCompiler.Project`.

When several targets contain a file, the server requests a context choice;
it does not select by enumeration order. A configured target name or the
returned context identifier can also select one. Dismissal or unsupported
client UI leaves the context unresolved. Document synchronization remains
available while semantic analysis awaits an explicit selection.

## Editor syntax

The compiler library also provides `RuneCompiler.Syntax`, a separate SML
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
