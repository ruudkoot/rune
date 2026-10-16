# JSON-RPC

<!-- Area: Protocols -->

JSON-RPC 2.0. Requests, notifications and responses are values, read from
JSON and written to it, and a framing cuts them out of a byte stream: a
line each, or a `Content-Length` header, as the Language Server Protocol
and the Debug Adapter Protocol frame theirs.
