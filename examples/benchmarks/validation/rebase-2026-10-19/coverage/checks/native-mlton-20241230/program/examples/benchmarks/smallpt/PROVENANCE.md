# smallpt provenance

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/smallpt/smallpt.hs,
Makefile and README.mkd. The README credits Davean Scies and bollu's Haskell
port and links the original smallpt-opt repository. Kevin Beason's
[smallpt](https://www.kevinbeason.com/smallpt/) supplies renderer ancestry.
The selected Haskell files state no separate program redistribution notice;
retain the files/history without inferring a grant from another version.
The scene constants are embedded program data, not an acquired image dataset.

## Algorithm and variants

Trace the nine-sphere Cornell-style scene with diffuse, specular and glass
materials. Preserve intersection order/ties, epsilon 1e-4, cosine-weighted diffuse
sampling, Schlick-style reflection weights, branch/split order, path roulette,
2x2 subpixels, tent-filter jitter, per-subpixel averaging/clamping and descending
image rows. The selected Haskell refractive split tests the incoming depth;
do not substitute an ancestor's incremented-depth convention. Keep the black
front wall and RNG draws even when color contributions later vanish.

Vectors/rays/spheres have strict numerical fields in the source. SML uses strict
real tuples and constructors, preserving scalar operation association. The
selected hash observation consumes every RGB channel. Keep row-sized lists and
force each row's sequential state actions before consumption, avoiding a full
image array or an additional cached-result variant. Tuple/header layout and
GHC's UNPACK annotations have no portable SML memory-layout equivalent and are
recorded representation differences.

The full modulo 2^64 state recurrence is retained. Source bitcast construction
of 1+out/2^48 followed by subtraction becomes exact dyadic conversion of the
masked 48 bits, split into two 24-bit pieces that fit every host's Int. Both
terms and their sum are exactly representable in binary64. Retain row seed
y^3 shifted 32 and all state updates; no alternate RNG or sampling distribution
replaces it. A state fixture independently verifies all 50 selected full 64-bit
states and exact draw values.

## Profiles, references and output checks

Smoke 16x12x1 and normal 64x48x1 reduce image dimensions through the upstream
smallpt API. Large preserves 512x384x6, the selected slow profile. Upstream CLI
FAST/NORM both use 512x384x1; that full reference is also retained. All dimensions,
seeds, scene values and sample counts are fixed. Each invocation reconstructs
row RNG state; repeated execution does not reuse rendered pixels.

The source hash prints six decimal places without a final newline. Pinned
nofib fixtures add one terminal LF. Reference checks record that formatting
adaptation and agree on both one/six-sample values. An export-only observer
retains complete RGB values and full-precision channel sums at every profile
and the full upstream normal input.

The driver streams every RGB reference line, checking each channel within
1e-8+1e-8*abs(reference) and the sequential channel sum within
1e-6+1e-10*abs(reference). Require exact pixel count and EOF. These budgets
cover selected deterministic results/math rounding, not arbitrary Monte Carlo
scenes. Gamma conversion/PPM image mode are outside the chosen hash workload.
Reference I/O and per-channel checks are measured work; the final report is
width:height:samples:checked. Large SML execution is claimed only where recorded.

GHC 9.4.7 lacks unboxed-ref in this environment. A correctness-only adapter
implements its used API with boxed STRef and strict initialization/writes.
This preserves state semantics while changing representation; its executions
are not original-runtime performance measurements. Both pinned hashes and
complete strict-adapter scene outputs agree. Retain adapter/source identities,
its explicit limitation, and the initial fixture-newline comparison attempt.

Semantic/negative tests cover vector algebra, normalized directions, near/far/
miss intersections, epsilon, full RNG states, complete smoke RGB, zero-sample
behavior, bad pixels/sums, truncation and extra reference data.

## Recorded native32 findings

Both selected profiles produce different pixels on managed 32-bit SML/NJ.
The full-state/value RNG check also fails, while the other geometry and negative
checks pass. Other supported native hosts and all Rune engines pass. Preserve
the Word64 expressions and reviewed references; the existing
[Word64 host reports](../../../docs/bugreport/smlnj/README.md) describe related
constant/arithmetic defects. This workload's exact first failing operation is
not reduced, so a specific cause is not asserted from the image difference.
Failed pixels cannot contribute accepted measurements.

## References and diagnostic questions

The [original smallpt explanation](https://www.kevinbeason.com/smallpt/) describes
Monte Carlo illumination, diffuse sampling, roulette and sphere scenes. The
retained Haskell program defines this workload's exact ordering, PRNG and hash
mode. Recursion, strict tuple boxing, scalar/library math, branch behavior,
state refs, row retention and allocation are source-based performance questions
until supported by inspection or measurement. Standard reports compare identical
SML. Original C++ OpenMP behavior is outside this sequential Haskell port.
