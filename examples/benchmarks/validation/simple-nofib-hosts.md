# SIMPLE host results and checker review

The final twenty semantic invocations complete all 2160 assertions:
2158 pass and two fail. Every Rune O0/O2 engine, MLton, 32-bit SML/NJ,
development SML/NJ, Poly/ML and ML Kit passes all 108 checks. Each legacy
64-bit invocation fails one complete-state check. Native O0/O2 labels
repeat the same native flags and are not native optimization-level evidence.

Initial unresolved tuple selectors leave 912 checks incomplete with 608
passes. Numeric defaulting/expansive geometry bindings and Poly/ML's missing
optional packing structure leave 760 incomplete with 760 passes. Explicit
source-derived types and a portable IntInf/Real.fromManExp decoder resolve
those portability problems. No algorithm or expected values change.

The first complete 76-check matrix has 1518 passes and two legacy failures.
Its per-cell bound was also applied to array sums. Full-grid totals-only
profiles then reject a small cancelled z sum on both 32-bit and development
SML/NJ, while their full-state reports pass. Direct numeric snapshots show a
difference about 2.73e-12 against a 2.08e-12 point bound. An independently
reviewed conditioning bound accounts for cell compatibility and rounding
of both row-major reductions. The per-cell bound is unchanged. Exact rational
scale/bound checks and deliberately excessive errors test the new checker.
These old false rejections remain development evidence, not compiler bugs.

A separate legacy snapshot has eight totals outside even the derived
aggregate bound. This is consistent with the existing
[legacy real/GC report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md),
without an application-specific causal reduction. Three earlier logging
diagnostics decode expected values again while printing; their displayed
values alone cannot establish the original failing arguments. Enlarged-
nursery diagnostics hit their 1 GiB limit before completion and do not
establish a runtime-setting fix. Canonical settings remain unchanged.

Known-value controls show that the tested SML/NJ PackReal64Big produces
little-endian bytes while reporting isBigEndian=true, and PackReal64Little
produces big-endian bytes. The Big decoder and subVec also fail the fixed
big-endian 1.0 control. Numerical diagnostic bytes are normalized only after
that isolated control. The registered reference decoder avoids optional
packing modules entirely, so it does not depend on these observations.

Initial full-grid smoke reporting hits the 30-second limit on several Rune
configurations. A separate 120-second diagnostic times out after over 100
seconds of CPU work. Selected smoke profiles use the independently observed
grid 8, retaining one step, the same kernel and the 30-second/1 GiB defaults.
Normal/large remain grid 100 with original 20/100 steps. All original full-grid
attempts and calibration limits remain visible. Final selected profile and
serial-adapter outcomes are recorded in the canonical coverage archive.

The final source, rather than the preliminary numerically equivalent encoding,
restores sparse boundary tables, undefined entries and table aliases.
Original snapshots cover every entry and scalar constant. Planted faults
verify actual pressure-table lookup. Explicit lazy producer/fold pipelines,
strict accumulator variants, a delayed fixed tuple of totals and the shared
first revised-energy term retain source structure. The table-only intermediate
subject passes all 2000 assertions; the final richer subject has the two
legacy failures recorded above. No application-specific GC cause is inferred
from that variation.

Final canonical profiles record four legacy normal numerical failures and
one empty-log ML Kit lazy totals smoke compilation error. All other selected
cases pass, including ML Kit's four normal applications and three smoke
variants. Twelve final serial native smoke preflights/fresh samples pass.
