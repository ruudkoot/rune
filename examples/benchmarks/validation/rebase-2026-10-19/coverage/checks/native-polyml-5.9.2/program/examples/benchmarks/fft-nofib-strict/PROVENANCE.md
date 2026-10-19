# fft-nofib-strict provenance

Selected collection/value evaluation: strict.

## Algorithm and workload

Run both original transforms on a real ramp [63,62,...,0] repeated 2^coarse
times. The first transform uses bit-reversed input and iterative fresh arrays;
the second recursively transforms lists and uses the source join/reorder pass.
Compare every result, render its status character and consume the complete
status stream with the source ASCII-sum/length checksum. Both transforms share
the generated input and its 64 memoized complex payloads.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
`spectral/hartel/fft/Main.hs`, Makefile, three 360-line stdout fixtures, and
`spectral/hartel/Fast2haskell.hs`. Preserve their complete bytes under upstream/.
The collection name records the Hartel association; the program/shim files state
no full individual authorship or separate redistribution notice. The related
GHC Complex module has a University of Glasgow 2001 notice and BSD-style license;
its file and base-library license are preserved with their own scope.

The classic SML fft keeps the unsuffixed name. This distinct nofib workload uses
fft-nofib-lazy/strict. It runs two array/list algorithms with a different input
and consumer. genfft generates transform source text; its embedded numerical FFT
helpers are unreachable there. These are distinct workloads with shared ancestry,
not duplicate runnable implementations.

## Evaluation variants and source semantics

GHC 9.4.7 Data.Complex at revision
00920f176b0235d5bb52a8e054d89a664f8938fe declares both components strict. The SML
complex pair therefore has strict binary64 fields in both variants. The lazy
variant memoizes whole complex values, array lookups/indices, comparison strings
and collection spines. The strict variant evaluates these finite values/spines
eagerly. The shared pi value follows the selected evaluation policy. Record
initialization can consequently move between compilation/startup and first use
on different host adapters; headline reports compare identical SML sources.

Both array butterfly outputs share z=root*y and their input lookup cells. The
list transform shares its root per recursive node and shares the product list
between plus/minus branches. Preserve source root arguments, including large
array angles; no modular reduction or twiddle-table substitution changes them.
List reordering retains split/join traversal rather than replacing it with a
direct permutation. Fast2haskell's miraseq does not demand its first argument.

## Portable SML97 translation and adaptations

Fresh SML arrays model the functional Haskell arrays: populate each new array,
then keep it read-only while later stages refer to it. Explicit association lists
and pair order are retained for butterfly stages. Array.tabulate supplies the
shim's tabulation helper; this replaces its library association-building layer.
Standard initialization supplies a shared zero cell. A separate seen array and
write counter validate complete unique index coverage before any stage escapes.
These extra validation allocations and bounds checks are part of the SML workload.
The input and stage arrays, lists, shared cells and arithmetic remain distinct;
there is no in-place butterfly overwrite.

Complex addition/subtraction/multiplication retain the pinned base module's field
expressions and operation grouping. The shim's log2 retains logarithm, rounding
and conversion operations. Nonnegative bounded bit operations use fixed Word32
or div/mod2 equivalents. At 2048 points, index products stay below 2^22 and all
source/driver integers fit signed 31 bits. Standard SML operations replace the
Haskell libraries; no compiler/runtime prerequisite is added.

An independent closed-form spectrum is built once per driver invocation. For
N=64*m and output k, frequencies not divisible by m are zero. For k=m*q,
q=0 gives (2016*m,0); q=1..63 gives (N/2,(N/2)/tan(pi*q/64)). This is the positive
sign, unnormalized transform used by the source. Every scalar from both algorithms
must be finite and within absolute 1e-7 plus relative 1e-12 of that value. The
original method-comparison bound 0.5 also remains. Reference GHC discrepancies
are at most 7.69e-9 (array) and 2.71e-11 (list); an independent direct DFT differs
from the formula by at most 1.21e-8 on the selected inputs. The chosen bound is a
reviewed finite-input rule with margin, not a general floating-point error theorem.
Tests reject perturbations that the original 0.5 comparison would accept.

The original successful t-character stream is retained and consumed; its checksum
is 117*N/N. The driver validates every repeated result, formats the original
checksum/newline contribution and reports repetitions:checksum:emitted-bytes.
Controlled summary output replaces separate per-iteration writes. Invalid
numerical results raise a suite failure before the original verbose difference
formatter. Numerical reference/checking work is included and documented for
SML compiler comparisons.

## Compiler/runtime diagnostic questions

Investigate fresh arrays and persistent lists, array checks, association cells,
complex representation, memoized roots/products, initialization, collector
retention, trigonometric calls and whole-program specialization. These are
source-derived hypotheses until supported by measurements. Count/allocation
instrumentation and serial timings have separate archives. The array algorithm
forms a root per butterfly; the list algorithm shares one per recursive node.
Aggregate results cover both algorithms; they do not isolate either one's cost.

## Profiles, correctness and references

| Profile | Coarse | Points | Repetitions | Suite result |
|---|---:|---:|---:|---|
| smoke | 1 | 128 | 1 | 1:14976/128:10 |
| normal | 3 | 512 | 360 | 360:59904/512:3600 |
| large | 5 | 2048 | 360 | 360:239616/2048:4320 |

Normal/large retain original NORM_OPTS/SLOW_OPTS and all 360 iterations. Smoke
preserves FAST_OPTS and reduces only iterations to one. Default limits apply.
The unmodified GHC program agrees with all three 360-line fixtures. Full vectors
from both original algorithms agree with independent direct DFT/analytic checks.
SML tests compare those vectors, nonuniform complex inputs, source checksums,
repeat formatting, bounds, invalid scalars and input sharing. Whole normal
Rune O2 pilots retain all 360 iterations. Other coverage belongs in validation.md.

[Cooley and Tukey](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Cooley65.pdf)
provide algorithmic background; [Partain](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides nofib context. The pinned sources establish these implementations and
[GHC's Complex definition](https://github.com/ghc/ghc/blob/00920f176b0235d5bb52a8e054d89a664f8938fe/libraries/base/Data/Complex.hs)
establishes field strictness. Source observations, reference discrepancies and
performance hypotheses have the distinct evidence scopes described above.
