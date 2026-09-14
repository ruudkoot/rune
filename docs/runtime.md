# Runtime architecture

The C runtime should remain split into these layers:

- `vm`: instruction dispatch and execution state;
- `format`: bytecode header, decoding, validation, and versioning;
- `memory`: allocation, object layout, limits, and failure handling;
- `platform`: clocks, files, process behavior, and other host integration;
- `cli`: argument parsing, diagnostics, and exit-status policy.

Only `platform` may depend on operating-system APIs. The VM and format layers
must be testable with in-memory byte arrays and deterministic inputs.

Debug, sanitizer, and release builds must exercise the same semantic code. Any
optimization that changes observable behavior requires a regression test.
