# aobench provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/aobench`.
SML/NJ Fellowship; original headers, modules and aggregate notice retained.

Render ambient occlusion by sphere/plane ray intersections and 8x8 hemisphere
samples. The original C/SML algorithm is preserved, with one/one/three
subsamples in smoke/normal/large. Large preserves the upstream 512-square
three-subsample workload. Rand48 seed 0x1234abcd330e is reset per run to its
upstream initial state; otherwise repeated calls advance RNG demand. Replace
Unsafe.Real64.castFromWord by exact conversion of a 48-bit integer divided
by 2^48, the same binary64 value as the original bit construction. Explicit
Word64 preserves modular 48-bit state. Real64Array becomes SML97 RealArray.
The source draws randomness only on hits: preserve demand and draw order.
Every header, dimension, data length and actual quantized RGB channel is
validated against reviewed original MLton and separately loaded original SML/NJ
renders. Original separate-unit and concatenated SML/NJ normal frames differ at
one RGB pixel by 32 levels; the interactive frame agrees with MLton. An
earlier portable SML/NJ build differed at two pixels by 12/8 levels. Ten
thousand RNG draws using original bit construction versus portable numeric
conversion agreed exactly; this does not establish a cause for the image
sensitivity. Discrete hit-test boundaries are a source hypothesis. Every
whole RGB pixel must match one original reference pixel, with at most one level
per 8-bit channel for floating-point rounding at quantization boundaries;
this is a benchmark-specific output tolerance, not permission to change
geometry. Allocation/traversal/real-operation concerns are source hypotheses;
no measured attribution is claimed. See [rendering literature](../literature.md).

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.
