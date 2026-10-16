# Binary32 adaptive Mandelbrot trees

Recorded 2026-10-16. All 56 requested tree cases are accounted for: 52 pass,
three legacy64 cases reject incorrect trees and its strict normal case raises
Domain. Every Rune engine passes both profiles at both levels, as do the other
five native hosts. Of 132 semantic/negative checks, legacy64 fails three tree
checks per pass while its scalar bit/demand checks pass; the other nine
configurations pass all 132.

Eight normal count samples agree. Existing budgets are unchanged; these new
profiles are currently unbudgeted. Five serial native smoke samples pass;
legacy64's lazy smoke correctness precheck is rejected and supplies no fresh
timing. The strict smoke diagnostic passes in its separate context. Counts
and single-sample diagnostics remain separate from headline timings and do
not establish that the configuration is reliable across other executions.

Original GHC trees and an independent binary32/perimeter model agree on every
node/bound/colour for extents 1/2/3/8/16/64/200. Original Main's finite forcing
terminates at source 2/20/100 repetitions. Per-operation bit fixtures cover
coordinates, orbit/radius updates and colours. Demand tests cover short
circuiting, shared col1, unused corners, outward scans, right-WHNF forcing and
eager right-before-left subtrees. Current normal-driver preflights validate
both complete two-repetition 200 trees on Rune O2.

Preserve the source's unusual perimeter inequalities, including outside scans
on zero-height rectangles. The independent full-root model requests 707 distinct
outside coordinates; that is not an instrumented GHC call count. Global
coordinate scaling remains 200 even for the smoke extent64. The finite-normal
binary32 helper preserves operation rounding/association without claiming a
general Float32 runtime feature. Every tree row and EOF are checked, with
wrong colour/branch and truncated/extra fixtures rejected.

The SML-generated per-repetition size input replaces source NOINLINE salt with
a portable runtime dependency; its added I/O and serialization/checking costs
are explicit. No FFI or parallel runtime is needed. Default/64 MiB nursery
replays preserve all outcomes: all four failed contexts pass with the larger
nursery, while default replays vary between incorrect output, Domain and a
pass. Earlier diagnostic callbacks move the mismatch. Source snapshots keep
the earlier point binding distinct from dependency injection added for demand
tests. Both default contexts fail; the parameterization was not a workaround.

The first corrupt operation is not reduced. No kernel, expectation or default
configuration is changed to hide it. Provenance, notices, symlink/target,
source/input identities and all raw evidence remain available. No prerequisite
compiler/runtime feature or universal large execution is introduced or claimed.
M3 remains in progress.
