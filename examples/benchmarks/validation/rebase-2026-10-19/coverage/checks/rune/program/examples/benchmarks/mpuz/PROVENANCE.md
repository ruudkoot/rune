# mpuz provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mpuz.sml`. Original, adaptation patch and notices retained.

Stephen Weeks, based loosely on Laurent Vaucher OCaml solution. Enumerates
distinct decimal assignments to the fixed multiplication puzzle. The
previously discarded solution text is observed, not replaced with a constant
success marker. Text length and Word32 rolling hash consume all assignments;
full reviewed reference text is retained beside the fixtures. Added output
observation allocates and is included in these workloads.
