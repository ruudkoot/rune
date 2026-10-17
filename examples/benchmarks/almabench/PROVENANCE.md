# almabench provenance

### Algorithm and workload

Calculate heliocentric planetary positions/velocities and derive right ascension,
declination and distance for eight planets at daily Julian epochs. Retain the
source nested loops, mutable epoch/state/result arrays, mean-element coefficient
tables, trigonometric corrections and iterative Kepler solver.

### History, authorship and source

ALMABENCH 1.0.1 OCaml version by Shawn Wagner, from Scott Robert Ladd's C++/Java
versions. Its individual header explicitly dedicates the program to the public
domain with no rights reserved. Retain that complete notice and attribution.
Pinned Sandmark revision 5605805954a00497ed197c930641cddd580e1507,
benchmarks/almabench/almabench.ml. The runnable name has no collision and is
almabench. There are no external datasets; all coefficients and epochs are
source constants. No foreign implementation is bundled in this upstream folder.

The source cites J. L. Simon, P. Bretagnon, J. Chapront, M. Chapront-Touze,
G. Francou and J. Laskar, Astronomy & Astrophysics 282, 663 (1994).
The comments' year-range descriptions differ; the executable epoch loop
actually starts at J2000 and advances 36525 days. Describe that concrete loop.

### Portable implementation and numerical choices

All computation, state generation and result checks use SML97. Leaf floating
arrays use RealArray and nested arrays use Array, retaining mutable unboxed
real storage and the original two-by-three state shape. Fixed coefficient
tables retain the same values and nesting; index bounds and integer counters
fit portable signed int for the selected profiles.

Preserve arithmetic association, Real.rem as the source mod_float operation,
Math.atan2 argument order and floating constants. The angle-normalizer comment
claims a half-open range, but exact negative pi maps to positive pi while
positive pi maps to negative pi. Preserve and explicitly test those endpoints.

Keep the Kepler loop's original OR condition: perform at least ten corrections
and continue until the residual condition also holds. Do not replace it with a
maximum-iteration interpretation. The independent reference has its own stopping
rule; agreement on selected states does not justify changing the benchmark.

The source initially computes all eight planets at J2000+1 before timing loops.
Keep and validate those calls too. Reuse the original state/output arrays across
all calls; no ephemeris/result cache is introduced. The optional OCaml GC-stat
file hook is outside the computation contract; OS/runtime statistics belong to
the suite's separate adapters.

### Profiles, consumption and correctness

| Profile | Outer repetitions | Days per repetition | Planet calls |
|---|---:|---:|---:|
| Smoke | 1 | 32 | 264 |
| Normal | 5 | 36525 | 1461008 |
| Large | 20 | 36525 | 5844008 |

Normal retains the complete source workload. Smoke reduces days/repetitions.
Large selects twenty repetitions, the historical count mentioned in the source,
while retaining the same epoch domain. Each profile includes the eight initial
test calls. Parameters are explicit instead of a universal size argument.

The original mutates arrays and prints nothing. Consume all six state coordinates
and three derived values on every call. For each of nine components accumulate
sum, sum of absolute values and sum of squares, preserving accumulation order.
All values must be finite. Compare all 27 moments to export-only original OCaml
references using absolute 1e-6 plus relative 1e-10 bounds. These are conservative
source-agreement bounds, not an astronomical accuracy guarantee or formal
floating-point error proof. Report planet-calls:27. The added moment consumer
is an explicit adaptation and prevents unused-result elimination.

Original OCaml completes its unmodified full workload with empty stdout.
Its observer produces all profile moments and 64 complete state/result samples
across eight epochs and eight planets. The separate ERFA Plan94 implementation
at revision 9915ba38c9365f8b0738269b8c2ac1fdd5f8dee3 (v2.0.1) agrees exactly
with all 384 sampled state coordinates. ERFA is a reference-only C program:
its complete source notices, pinned files and observer remain in the evidence
archive; the SML benchmark has no C/FFI dependency.

The 163-check target compares 64 original states, 64 independent states,
angle/remainder semantics, smoke moments, every individually perturbed moment,
nonfinite values and malformed/short references. Point comparisons use absolute
and relative 1e-11. Full normal final-source Rune calibration passes; canonical
host/count checks are recorded as they finish. Full large SML repetition checks
remain unrecorded, separately from the original observer's complete large
moments. Incorrect results cannot supply accepted measurements.

### Literature and diagnostic coverage

[Simon et al. (1994)](https://articles.adsabs.harvard.edu/full/1994A%26A...282..663S)
is the original algorithm citation retained in the source. The historical paper
link was unavailable during this import; detailed claims are based on the
reviewed benchmark and independent
[ERFA Plan94 source](https://github.com/liberfa/erfa/blob/9915ba38c9365f8b0738269b8c2ac1fdd5f8dee3/src/plan94.c).
Its limitations and stopping conditions remain distinct from ALMABENCH's.
Investigate scalar math calls, mutable real-array access, bounds elimination,
coefficient reuse, correction loops and result-consumer cost. These are
source-based hypotheses until supported by recorded measurements.
