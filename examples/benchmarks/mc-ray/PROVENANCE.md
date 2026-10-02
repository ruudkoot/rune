# mc-ray provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mc-ray`.
Individual module/data notices and aggregate notice are retained with the
ordered originals and patch.

Monte Carlo recursive ray tracing from John Reppy and the SML3d project.
Keep sphere/material generation, camera sampling, dielectric/metal/diffuse
paths and demand-dependent RNG draws. Reset MINSTD seed 1234567 each run;
explicit Word64 preserves the 64-bit multiplier/folding implementation on
32-bit default hosts. Real64 aliases become SML97 Real; binary64 precision
is required. Smoke/normal reduce dimensions and samples; large preserves
150x100 with 50 samples. Keep original list-pixel and object data structures.
Validate P6 headers, dimensions and every RGB channel against reviewed
native original renders, with at most one 8-bit level of rounding tolerance.
Result consumption and file output/validation are measured work. Algorithm,
real-operation, closure and allocation sensitivity are source hypotheses,
not established performance causes. See [literature](../literature.md).

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.
