# Deterministic Win32 GUI mock

Area: Foreign interfaces

`Win32Mock` implements `WIN32` through the same semantics as the SDL3
provider. Its in-memory driver advances a deterministic clock, creates
no native resources, and records normalized API operations. Injection,
time advancement and trace controls support reproducible contract tests.
A blocked GetMessage with no queued event or active timer raises an
explicit unsupported operation instead of waiting for an external source.
