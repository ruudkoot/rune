# zern provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zern.sml`. Original, adaptation patch and notices retained.

David McClain phase-screen E-field study; source also credits Stephen Weeks
and retains AT&T notices. Fifteen coefficient screens and the flat real
array operations are unchanged. collect uses indices 1 through 15, so the
coefficients are 2 through 16 and their sum is 135. The independent field
is cos(1.35*i)+i*sin(1.35*i). Check both components at every cell with
absolute error <=1e-8. Removes clock reporting and selects one side length.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/zern.sml`,
is an additional source for this implementation. The complete kernel/input
agree; its launcher uses 1000 repetitions rather than a parameter. This
count remains accepted by the portable driver and is recorded as an
upstream invocation, rather than duplicating the implementation.
