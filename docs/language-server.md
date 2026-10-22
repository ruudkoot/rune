# The Rune language server

`runelsp` is the standalone LSP adapter for Rune. The current implementation
provides the M2 protocol foundation: stdio transport, initialization,
capability/position-encoding negotiation, progress tokens, tracing and
shutdown. Compiler-backed editing features are the following milestones
of [the roadmap](plans/language-server.md); the server currently advertises
no text-document synchronization or semantic providers.

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
