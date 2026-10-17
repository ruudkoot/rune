# FFT2 host results

The canonical primary matrix has 54 passes in 56 smoke/normal attempts.
Both normal legacy 64-bit SML/NJ 110.99.9 cases fail numeric result validation;
its smoke cases pass. All Rune, MLton, 32-bit legacy SML/NJ, development SML/NJ,
Poly/ML and ML Kit primary cases pass.

The broader 132-check semantic target is a different compilation/execution
context. Fourteen complete invocations pass every check. Each of the four
64-bit SML/NJ invocations completes 65 passing assertions before terminating;
each 32-bit SML/NJ invocation completes 64 passes and one failed assertion.
These six incomplete invocations leave 67 checks unreached each. The aggregate
is 2236 passes, two failed assertions and 402 unreached checks. Raw process
logs retain bus/segmentation faults and the bogus-overflow diagnostic.

A private native run reproduces the same host split. No compiler cause is
established by these observations; do not label every failure a rounding error,
change canonical nursery settings or enlarge numeric budgets to hide them.
The checker has explicit per-metric bounds, perturbation rejection and finite
value requirements. Failed primary checks supply no accepted measurement.

Eight complete normal Rune count samples agree under the engine model rules.
Six serial single fresh-process native smoke adapter samples pass, including
legacy SML/NJ. They validate the smaller input only and do not override its
normal-profile correctness failure.
