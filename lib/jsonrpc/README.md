# JSON-RPC

<!-- Area: Protocols -->

JSON-RPC 2.0. Requests, notifications and responses are values, read from
JSON and written to it, and a framing cuts them out of a byte stream: a
line each, or a `Content-Length` header, as the Language Server Protocol
and the Debug Adapter Protocol frame theirs.

Request IDs and error codes use `IntInf.int`, retaining their wire values
on 31-bit hosts. Callers with ordinary integer counters convert with
`IntInf.fromInt` when constructing a numeric ID. JSON-RPC batches remain
supported; a protocol such as LSP can impose its narrower single-message
and 32-bit integer requirements in its own adapter.

`Framing.bounded` sets independent header and body byte limits. It refuses
repeated lengths, malformed decimal lengths and unsupported charsets;
received chunks are concatenated once per completed message. Reader values
can be reused to decode independent continuations. A transport must also
check `Framing.pending` at EOF to diagnose a truncated message.
