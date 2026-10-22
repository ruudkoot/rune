# The runelsp protocol

The server uses [LSP 3.18](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/)
over stdio and UTF-8 JSON-RPC. [The language-server manual](language-server.md)
describes launching it. This document describes the implemented M2
protocol foundation; feature milestones extend it together with their
tests and negotiated capabilities.

## Transport and envelopes

Messages have ASCII headers terminated by CRLF, a blank line, and exactly
the declared Content-Length bytes. Input is incrementally decoded across
arbitrary reads. Repeated lengths, malformed decimal lengths, unsupported
charsets and configured size-limit violations close the transport. UTF-8
and the legacy `utf8` charset spelling are accepted. An incomplete frame
at EOF is a failure; clean EOF releases connection-owned state.

Each frame contains one message. JSON-RPC batches are refused without
executing their elements. Request IDs and error codes preserve signed
32-bit values even on a 31-bit SML host. String IDs retain their UTF-8
bytes. Ambiguous envelope members and mixed request/response fields are
invalid. Malformed recognizable notifications and responses are logged
without replies, avoiding response loops. Unknown extension members are
permitted.

## Lifecycle and capabilities

`initialize` validates the client capability object and selects UTF-8 when
offered, then UTF-16 or UTF-32, with mandatory UTF-16 as the fallback. Its
result contains `serverInfo` and the implemented server capabilities.
Currently `textDocumentSync` is None and no semantic providers are
advertised. A specification entry in `LspMethods` does not activate a
provider.

`initialized` completes the handshake. Other ordinary requests before
initialization receive `ServerNotInitialized`; duplicate initialization is
invalid. Unsupported requests after initialization receive
`MethodNotFound`. A notification method sent as a request is invalid.

`shutdown` is a request and returns null. Further requests are invalid.
`exit` is a notification: its process status is success after shutdown and
failure otherwise. A shutdown notification does not change lifecycle
state. Clean transport EOF also releases connection ownership.

## Progress, cancellation and tracing

A client-supplied initialization `workDoneToken` receives paired begin/end
progress notifications. Unknown or already completed cancellation/progress
tokens need no reply. Current handlers complete synchronously; compiler
job cancellation is added with supervised analysis, rather than claiming
that a completed initialization can still be cancelled.

`LspRequests` supplies bounded, connection-owned pending request data,
fresh string IDs, response matching, cancellation and cleanup for later
server requests and analysis jobs. An entry is consumed once; duplicate,
stray and late responses cannot replace another request's data. Dynamic
registrations and server-initiated progress are used when their feature
milestones create such work and the client supports them.

`$/setTrace` accepts off, messages and verbose. Requested trace data is
sent as framed `$/logTrace` notifications; operational errors remain on
stderr. Notifications never receive ordinary response messages.

## Reusable wire values and inventory

`lib/lsp` has portable integer, position/range, envelope, capability and
request-ownership interfaces. Its coordinates are code-unit counts in the
negotiated encoding; conversion to source offsets belongs to document
storage. Reversed ranges and negative/out-of-range coordinates are refused.

`tools/lsp/protocol/metaModel-3.18.0.json` is the reviewed upstream data,
with source hash and attribution. `make lsp-protocol` deterministically
regenerates 95 method declarations, 814 wire-property declarations and 250
enumeration members; `make check-lsp-protocol` rejects stale output. Each
feature's codecs and behavior require independent acceptance even though
the inventory already contains its declaration.

## Verification and transport performance

`make test-lsp-protocol` covers lifecycle, old/modern capability sets,
full-width integer IDs, progress order, malformed envelopes, notifications,
response ownership, limits, truncation, trace traffic and interactive
stdio. `tests/lib/lsp/protocol.sml` also runs on the native SML hosts.
Host deviations retain their actual causes; a compiler bug does not
justify changing the library's semantics.

[The framing ledger](../tests/lsp/baseline/2026-10-22-framing.json) compares
the unchanged earlier decoder (with renamed signature/structure) against
the bounded streaming decoder in one VM, with paired order and independent
body checks. For the 16 KiB, one-byte-fragment fixture, median allocation
fell from 305177312 to 2511984 bytes. This is a transport microbenchmark,
not a measurement of compiler analysis or the parser-sharing condition.
