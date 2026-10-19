# tensor provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tensor.sml`. Original, adaptation patch and notices retained.

Juan Jose Garcia Ripoll tensor library, imported through MLton. The individual copyright and redistribution conditions are embedded in the
source (lines 31-68), including the acknowledgement requirement and author
name restrictions. Retained verbatim in TENSOR-LICENSE and upstream source.
Real and paired-complex representations, elementwise
operators and both contraction orders are retained. Checked Real64Array
accesses replace Unsafe access. The clock/timing printer is removed; every
result element is checked against 2, 1 or the contraction dimension.
Runs 20 repetitions of each elementwise operator and four of each contraction
as upstream, on one selected dimension rather than the five-size outer sweep.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.
