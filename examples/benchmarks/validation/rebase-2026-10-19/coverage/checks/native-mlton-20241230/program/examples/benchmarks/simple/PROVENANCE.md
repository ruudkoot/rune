# simple provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/simple.sml`. Original, adaptation patch and notices retained.

SML/NJ hydrodynamics simulation. Every arithmetic routine and the custom
Array2 representation are preserved. Replaces the value-parameter functor
wrapper with a function so grid size is runtime input in SML97; its original
body remains a local declaration block with freshly initialized state.
Smoke uses grid maximum 8, normal preserves 100 and one time step, large
selects 128. Consume all eleven final arrays and both scalar results.
Reference state is the pinned MLton program with a read-only observer;
per-element error bounds are 1e-8 absolute plus 1e-7 relative. The original
100-grid scalar checks (truncated c*10000=6787 and delta=-33093) provide
additional upstream evidence. Validation reads are included in the workload.
