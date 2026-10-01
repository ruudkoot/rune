# kitqsort_no_basislib provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`,
`test_dev/kitqsort_no_basislib.sml`. Source attributes the copying/argument
transformation to Sestoft and Bertelsen, December 1995, and references
Paulson pages 96/98 and exercise 3.29 for generation/quicksort. Original
source and the aggregate ML Kit/GPL/SML-NJ notices are retained; no individual
license is asserted beyond what those notices establish.

Retain the pivot/partition order, copies of left partitions, right-first
recursive sort, tuple arguments, aliases and tail recursion. This differs
from copying mergesort and from later variants with active forceResetting.
The forceResetting mention here is inside a comment and stays inert.

Replace the old primitive-based mini-Basis by equivalent SML97 operations:
real division, Real.floor, Real.fromInt, string operations, print and
polymorphic equality. The foreign context pointer was only an implementation
argument to floorFloat; the algorithm requires no foreign call or runtime
facility. Keep all custom list and sorting functions from the kernel, and
wrap its outer let in SortKernel. Suppress old Ok/Oops output; validate order,
length, IntInf sum and every sorted element in a fixed Word32 checksum.

Keep the original floating Park-Miller generator, seed 117, multiplier
16807, modulus 2147483647 and value range 1..100000. Require binary64 Real;
all generator intermediate integer products fit its exact 53-bit range,
allowing an independent integer-modular Python oracle. Smoke sorts 100,
normal preserves 25000 and large selects 100000. No filesystem input or
random operating-system state is used. The added complete result scan is
measured work. Copying, tuple lifetimes and specialization are source-based
hypotheses, not measured explanations; see [ML Kit/Paulson references](../literature.md).
