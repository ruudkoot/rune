# The runelsp protocol

The server uses [LSP 3.18](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/)
over stdio and UTF-8 JSON-RPC. [The language-server manual](language-server.md)
describes launching it. This document describes the protocol foundation
and implemented document synchronization; feature milestones extend it with
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
`textDocumentSync` advertises open/close, incremental changes, will-save
notifications and saves with included text. Implemented semantic providers
cover diagnostics, hover, navigation, symbols, binding highlights and completion;
source-editing providers remain unadvertised. A specification entry in
`LspMethods` does not activate a provider.

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
tokens need no reply. Compiler jobs run in a supervised child while the
connection polls input. Cancelling a queued or running request receives a
single cancelled response. Running work gets a cooperative cancellation
message, followed by process-group termination if its grace period expires.

`LspRequests` supplies bounded, connection-owned pending request data,
fresh string IDs, response matching, cancellation and cleanup for later
server requests and analysis jobs. An entry is consumed once; duplicate,
stray and late responses cannot replace another request's data. Dynamic
registrations and server-initiated progress require client support.

Diagnostics use current document revisions and workspace generations.
Document pulls return full or unchanged reports. Workspace reports include
closed build inputs and can use a partial-result token. Pull clients get a
diagnostic refresh instead of duplicate pushes. A stale diagnostic request
returns ServerCancelled with retriggerRequest, and completion edits for an
obsolete source return ContentModified. Workspace symbol and completion
resolution validate their original snapshot data before returning results.
Malformed semantic parameters retain `InvalidParams` through the private
worker protocol. A normal query whose immutable view was evicted retries
one fresh check when its source revision/context is still current. Stale
item resolution returns `ContentModified` instead; process startup, I/O and
deadline failures remain request failures.

`textDocument/documentHighlight` returns current-document occurrences of the
selected checked binding. Qualified prefixes and members have separate token
ranges; shadowed bindings, strings and comments are excluded. Value uses are
`Read` highlights, while declarations and other namespaces use `Text` rather
than inventing mutable writes. Ranges use the negotiated position encoding.
Requests exceeding the 8192-range response budget fail explicitly without a
partial highlight set, and leave the worker available for later queries.

`textDocument/foldingRange` returns complete-line syntax/comment folds and
honours `rangeLimit`. `textDocument/selectionRange` returns one containing range
chain per requested position, including compiler syntax and qualified-name
components. Chains have at most 64 entries and requests at most 128 positions;
the outermost range covers the document. Split character positions are invalid.
Build documents use build grammar path spans for selection.

Clients offering `workspace.foldingRange.refreshSupport` receive refresh
requests after relevant workspace/configuration changes and context choices.
Only one request is outstanding; a changed generation is refreshed after the
acknowledgement. A `MethodNotFound` refusal disables that refresh for the
connection. Text edits do not emit global folding refreshes.

Semantic-token capabilities appear only with a compatible client legend,
`relative` format and supported full/range requests. Deltas require the client's
full-delta option. Five-integer rows use negotiated position units; multiline
spans always split and overlapping observations coalesce. Range replies include
whole intersecting tokens. Full result IDs identify URI, legend and token data;
raw-array deltas can edit inside a token tuple. An unavailable previous ID falls
back to a full result. History belongs to the worker/connection and has count
and estimated memory bounds. Build documents currently return null token results.

`workspace.semanticTokens.refreshSupport` enables token refreshes using the same
generation/coalescing/refusal rules as folding refresh. Unnegotiated token
methods return `MethodNotFound`; malformed ranges retain `InvalidParams` and
response-budget failures retain `RequestFailed`.

`textDocument.inlayHint` enables inferred pattern type hints. The provider
advertises tooltip resolution only when `resolveSupport.properties` includes
`tooltip`; other clients receive the tooltip eagerly. Labels carry kind `Type`
and have no accepting text edits. Range endpoints follow the position mapper's
EOL/EOF clamping and character-boundary rules. Limits are 2048 hints and 1 MiB
per response; refusal is `RequestFailed` and leaves smaller ranges available.

Hint metadata identifies its retained snapshot, binding, source revision and
workspace generation. `inlayHint/resolve` selects that original snapshot, even
after an equivalent recheck, and verifies the metadata against both current
service state and the captured view. Label/position changes are invalid.
Edits, changed contexts, eviction and worker restart return `ContentModified`
without retrying stale hint metadata. Build documents return null hints.
`workspace.inlayHint.refreshSupport` enables workspace refresh using the same
generation, coalescing and refusal rules as folding; typing does not emit it.

`$/setTrace` accepts off, messages and verbose. Requested trace data is
sent as framed `$/logTrace` notifications; operational errors remain on
stderr. Notifications never receive ordinary response messages.

## Documents and positions

`didOpen`, `didChange`, `didClose`, `willSave` and `didSave` operate only
after `initialized`. Client versions are signed LSP integers and must
increase within an open-document lifetime. Server revisions also
distinguish closing and reopening the same URI at a reused client version.

A change batch applies to successive intermediate texts and publishes
only after every change succeeds. Invalid transitions quarantine the
document for semantic use. Its last valid text/version remain available
for recovery; the highest observed version prevents stale replacement.
Ranged changes cannot repair a quarantined document: a later full
replacement or reopen is required. No custom resynchronization request is
sent. A save payload is observed without changing text or client version.

Positions recognize LF, CRLF and CR, preserve a present BOM, and reject
split UTF-8 characters or UTF-16 surrogate pairs. Characters beyond EOL
clamp to EOL and lines beyond the document clamp to EOF. Offsets inside
line-ending bytes map to EOL. Byte edits reuse sparse Unicode checkpoints;
line-ending edits rebuild the affected line region.

File URI decoding keeps client identities separate from native paths.
POSIX filename bytes and Windows drive/UNC/WTF-8 paths are preserved.
Native keys retain path-component case and parent arcs; they do not
resolve symlinks. Project-context selection must account for aliases
explicitly. Virtual and unsaved URIs remain valid document identities.

## Workspace requests

`workspace/configuration` is requested only when supported, with section
`runelsp` and explicit folder/document scope URIs. Responses belong to a
configuration epoch; stale responses cannot overwrite newer settings.
Closed document scopes are not replaced by late replies. Startup options
remain the fallback when the client refuses configuration.

Workspace folders use initialization data or a negotiated
`workspace/workspaceFolders` request. Folder and configuration changes
invalidate context discovery. `didChangeWatchedFiles` invalidates
closed-source/build metadata; a client refusal does not make disk state
authoritative over an open overlay.

When supported, watcher registrations use relative patterns. Registrations
are balanced on root changes, and refusal falls back to revalidation on
queries. Build ambiguity uses `window/showMessageRequest` actions tied to
the current document revision and workspace generation; stale choices are
discarded. Dismissed or unavailable UI never chooses an arbitrary target.

## Reusable wire values and inventory

`lib/lsp` has portable integer, position/range, envelope, capability and
request-ownership interfaces. Its coordinates are code-unit counts in the
negotiated encoding. `LspPosition` converts them to immutable source
indexes and `LspUri` handles native path conversion. Reversed ranges and
negative/out-of-protocol coordinates are refused.

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
