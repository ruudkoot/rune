# Language Server Protocol

<!-- Area: Protocols -->

LSP 3.18 common wire values over `lib/jsonrpc`: one-message envelopes,
portable signed/unsigned integer bounds, positions/ranges, UTF-8 text and
capability-based position-encoding negotiation. Unknown extension fields
remain permitted. Malformed responses are distinguished from invalid
requests so callers do not answer a response with another response.

`LspMethods` is a generated declaration inventory, not a list of implemented
providers. It covers all methods, declared wire properties (including
anonymous object types), and enumeration members from the reviewed
metamodel. Regenerate it with `make lsp-protocol`; `make check-lsp-protocol`
rejects a stale inventory. Source identity and attribution are preserved
under `tools/lsp/protocol`.

The library contains no compiler, filesystem, workspace or editor policy.
Each feature adds its parameter/result codecs and semantic tests as it is
implemented. A server advertises a provider only after that behavior has
passed acceptance, independently of its presence in the specification.
