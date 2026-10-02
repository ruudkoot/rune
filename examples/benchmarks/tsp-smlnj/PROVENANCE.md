# tsp-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/tsp`.
AT&T Bell Laboratories, SML/NJ Fellowship. Preserve individual notices,
all ordered modules and original launcher.

Build a seeded two-dimensional spatial tree and construct a tour by
recursive division and conquest. Seed 314 restarts for each tree; threshold
150 is preserved for normal and large. The modern MINSTD generator uses
two word folds instead of the older Int32 quotient/remainder recurrence.
Use explicit Word64 to preserve its intermediate product on default-32-bit
hosts; Real64 becomes SML97 Real, requiring at least 53-bit precision.
Tree layout, construction order and tour linking are preserved. Suppress
progress, require cardinality and backlinks, compare complete coordinate
multisets before/after, and check tour length at abs 1e-8 plus rel 1e-8.
The standard SML left-to-right evaluation order is retained. Full observation
is included in measured execution. Large selects original 262143 vertices
and 25 calls; normal is the bounded 1023-vertex profile. Modern RNG, closure
and linking costs are source hypotheses, not measured causes. See the
[classic and numerical literature](../literature.md); upstream Rand cites
Park and Miller, CACM 31 (1988), 1192-1201, updated multiplier 48271.

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.
