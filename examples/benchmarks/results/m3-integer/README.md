# Machine and arbitrary-precision integer grids

Recorded 2026-10-16. Two imports bring the catalogue to 279 programs and
831 profiles. All 56 selected smoke/normal cases pass across Rune's four
engines at both levels and all six managed native hosts. The 114 semantic/
negative checks pass every configuration except native32, which fails the
same two constant wrap checks at each level; its other 112 pass. The separate
two-check runtime-input probe passes all ten configurations and preserves the
constant/dynamic output differences. No expression or expected value is
changed to hide those findings.

Eight normal count samples agree across Rune engines. Existing budgets remain
unchanged; these profiles are currently unbudgeted. Six serial native smoke
samples validate MLton, SML/NJ and Poly/ML adapters. Single-sample diagnostics
and instrumented counts remain separate from headline timings.

Each variant retains all 14 operations, separate machine64/arbitrary-precision
passes, Cartesian order and forcing. Word64 helpers preserve signed machine
arithmetic on hosts with narrower default Int. IntInf performs the separate
arbitrary-precision operations. Explicit memoized heads/spines retain lazy
demand/sharing; the strict variant eagerly constructs finite result lists.
Every result contributes to all 28 checked count/digest lines and EOF.
Hashing and reference I/O are measured work, and machine helper costs differ
from original Haskell primitives.

Unmodified GHC originals terminate with empty output. A Show-only observer
retains the original operation selection/loop order and records every pass's
digest; an independent exact model agrees at smoke, selected normal/upstream
FAST 300, upstream NORM 934 and selected large/upstream SLOW 2100. A separate
GHC native64 observer and exact model verify 98 arithmetic results and machine
wrap; GHC quotient overflow and zero-divisor exceptions are also recorded.

Current-kernel FAST preflights pass both variants. The separately labeled
intermediate-calibration records earlier 934-grid runs with an enumeration
that computed the next addition one cell ahead. Those runs pass their digests
but are not canonical validation of the final delayed-tail implementation.
The intermediate source/bytecode identities, limits and logs are retained.
Final demand tests reject eager tail evaluation and check memoized sharing.

Inputs, unstated source authorship/notice, translation decisions and diagnostic
limits are documented. No prerequisite compiler/runtime feature or universal
large SML execution is introduced or claimed. M3 remains in progress.
