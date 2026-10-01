# peek provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/peek.sml`. Original, patch and notice retained.

Stephen Weeks. Generative exceptions implement heterogeneous property lists
with Int32 and Int64 values. Parameterizes only the inner loop and repetitions.
Both observed accumulators are checked by the original arithmetic invariants
and returned. Large preserves ten million inner iterations. Poly/ML lacks
Int64; this configuration is unavailable, not a different-width emulation.
