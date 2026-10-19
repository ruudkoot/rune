# matrix-multiply provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/matrix-multiply.sml`, Stephen Weeks. Original notice and
source identity are retained; the kernel is shared in `shared/matrix-multiply.sml`.

Preserve Array2 multiplication, dot-product traversal and the original
all-ones input. Large keeps dimension 500; smoke and normal scale to 4/50.
Every output entry must equal n exactly, and the full matrix sum n^3 is
independently derived in IntInf for narrow hosts. Integral doubles are exact
for these selected operations, so no floating tolerance is needed.

The first adaptation changed the input to a ramp, which affects numerical
values and boxed-input allocation. That adaptation is retained separately
as matrix-multiply-ramp with explicit provenance. The ML Kit version selects
200 and regenerates input on two calls; it shares the reviewed kernel but
retains its own profiles. Array specialization/unboxing, traversal and
allocation are hypotheses from source analysis, not measured explanations.
