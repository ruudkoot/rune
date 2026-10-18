# FEM binary32 validation

The primary smoke/normal matrix records 54 passes in 56 attempts. All Rune
O0/O2 stack/register/JIT/native cases and all other managed SML hosts pass.
Legacy 64-bit SML/NJ fails both normal profiles with incorrect numerical
results. Smoke succeeds, including all six native fresh-process diagnostics.

All twenty semantic invocations complete all 133 assertions: 2604 pass,
56 fail and none are unreached. Legacy 64-bit groups have 24 and 32 failures;
native labels repeat the same host-default flags. Every other invocation
passes all 133. Expected bits and standard defaults remain unchanged.

Original complete snapshots cover parsed integer/Float32 arrays, degrees,
band addresses, stiffness, LL factors, loads, forward/back solves, nodal
displacements and forces across four unique model sizes. All selected states
agree bit for bit on validated configurations. Separate intermediate
snapshots are not additional solves in timed workloads.

An independent binary64 dense assembly and partial-pivot solve checks
structural bandwidth, physical stiffness, LL residual, equilibrium and forces
using reviewed binary32 input values. Explicit norm bounds and rejected
one-percent perturbations are recorded. Runtime correctness requires finite,
exact original final-value bits; these independent-model bounds do not relax
the primary bit checker.

The original Float report uses shortest formatting. A documented common
FIX9 renderer preserves headings, fields and padding, and matches an
output-only Haskell observer completely. Final displacement/force bits,
complete report and original modular-64 hash algorithm are all checked.
The full original FAST/NORM/SLOW programs evaluate their reports/hash and
produce no stdout, matching recorded runs.

Three further legacy default-process diagnostics fail 25, 26 and 25 checks;
three separate @SMLalloc=64m diagnostics pass all 133. Actual numeric snapshots
vary materially (not merely decimal formatting or one-ulp tolerances).
This is consistent with the existing GC-root report, without proving the
application's exact compiler/runtime cause. Diagnostic heap settings are
not standard configurations and no standard failing sample is accepted.

All eight full-normal Rune count samples agree; both guards exit zero
without interruption. Six serial single fresh-process native smoke diagnostics
pass, including correctness preflights. These are adapter diagnostics, not
ten-sample comparative claims. Broader selected large runs remain unrecorded.

All 128 inventory regressions and the five-pin 861-entry replay pass.
The public semantic target passes Rune O0/O2. Complete source, author/data
origins, historical MAIL and ancillary C-comparison exclusions are retained.
Canonical input identities replace byte-verified repeated archive copies;
per-run outcomes remain intact. Repository acceptance is recorded separately.

Full make JOBS=4 check exits zero with 1385 profiles and all compiler,
runedoc and runeopt cross-build comparisons. Unrecorded large/performance
scopes remain outstanding as stated above.
