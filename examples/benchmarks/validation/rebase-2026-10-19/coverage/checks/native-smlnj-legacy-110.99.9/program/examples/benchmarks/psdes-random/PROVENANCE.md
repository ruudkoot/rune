# psdes-random provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/psdes-random.sml`. Original, patch and notice retained.

Stephen Weeks, Numerical Recipes pseudo-DES generator. Four Word32 rounds
and alternating generated words are retained. Removed top-level executions;
the actual modular sum is returned. Python bit arithmetic supplies smaller
fixtures; the original literal supplies the 150 million-word fixture.
