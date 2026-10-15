# Regex parsing and cyclic NFA interpretation

Recorded 2026-10-15. [All 56 canonical smoke/normal cases](correctness.tsv)
pass on four Rune engines at both levels and all six managed SML hosts.
Forty-five semantic checks pass all ten configurations at both levels.
Typed parser values, ordered alternatives, cyclic graph sharing, epsilon-table
compression and duplicate active states retain the source algorithm.

Both variants keep memoized cyclic edges. Finite parser/transition/active-state
sequences use memoized or eager evaluation, respectively. Portable strict UTF-8
acquisition and line buffers are explicit representation/demand adaptations;
Unicode code points, rather than UTF-8 bytes, feed matching and hashing.
Normal preserves the original 150 repetitions and NORM input. Smoke uses FAST
data once; original FAST's 100 repetitions and SLOW's 250 remain in provenance.

Every iteration checks every matched line in order before computing the source's
signed 64-bit wrapping hash. The repetition total uses IntInf. Unchanged GHC,
all pinned hash fixtures, a separate full-line GHC observer and an independent
Unicode-aware filter agree. Dataset contributor metadata and notice gaps are
recorded in each port's provenance. Large SML execution is not universally claimed.

Allocation and applicable instruction comparisons agree across four Rune
engines. All eight canonical count samples pass, with full configuration,
source/input/tool snapshots and raw process samples retained. Instrumented times
are not headline timing results. Prototype syntax and unconstrained-parser-value
failures are archived separately; the final concrete int-token annotation passes
all managed hosts. No alternate host-specific expected result is accepted.
M4 remains in progress.
