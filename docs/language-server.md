# The Rune language server

`runelsp` is the standalone LSP adapter for Rune. The current implementation
provides stdio transport, initialization, capability/position-encoding
negotiation, progress tokens, tracing, shutdown and versioned document
synchronization. Compiler-backed editing features follow in
[the roadmap](plans/language-server.md); semantic providers remain
unadvertised until their acceptance checks pass.

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
worker resource limits are separate later milestones.

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
against the batch parser. Server analysis integration remains in progress;
the server does not yet advertise syntax or semantic editing providers.

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
