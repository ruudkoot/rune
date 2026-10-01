# Rune benchmarks

Portable SML97 benchmark programs, being implemented from the
[roadmap](../../docs/plans/benchmarks.md). The runnable catalogue includes the five M1 pilots and the growing M2 classic
SML collection, with fixed profiles and result checks. The larger source
[inventory](inventory.tsv) schedules future imports; it is not a list of
passing programs. See the [source audit](audit.md) and [literature map](literature.md).

| Name | Source | Description |
|---|---|---|
| [tak](#tak) | Classic SML / MLton | Evaluate the strict Takeuchi recurrence and sum repeated results. |
| [kittmergesort](#kittmergesort) | Classic SML / ML Kit | Sort deterministic integer lists with the region-friendly copying merge. |
| [primes-lazy](#primes-lazy) | nofib | Demand only the required prefix of the finite iterative sieve using memoized tails. |
| [primes-strict](#primes-strict) | nofib | Evaluate each finite sieve list strictly to produce the same prime. |
| [bdd](#bdd) | Sandmark | Construct and check a hidden-weighted-bit binary decision diagram. |
| [fib](#fib) | Classic SML / MLton | Evaluate naive binary-recursive Fibonacci. |
| [tailfib](#tailfib) | Classic SML / MLton | Evaluate tail-recursive Fibonacci with two accumulators. |
| [even-odd](#even-odd) | Classic SML / MLton | Call mutually recursive parity predicates. |
| [merge](#merge) | Classic SML / MLton | Merge interleaved sorted lists using non-tail recursion. |
| [tailmerge](#tailmerge) | Classic SML / MLton | Merge sorted lists using a reversed tail-recursive accumulator. |
| [imp-for](#imp-for) | Classic SML / MLton | Traverse seven nested mutable-counter loops. |
| [vector-rev](#vector-rev) | Classic SML / MLton | Reverse a vector twice and consume every element. |
| [vector32-concat](#vector32-concat) | Classic SML / MLton | Concatenate Int32 vectors and validate their contents. |
| [vector64-concat](#vector64-concat) | Classic SML / MLton | Concatenate Int64 vectors and validate their contents. |
| [string-concat](#string-concat) | Classic SML / MLton | Concatenate cyclic alphabet strings and consume every character. |
| [wc-input1](#wc-input1) | Classic SML / MLton | Count newline characters by reading a generated file one character at a time. |
| [wc-scanStream](#wc-scanstream) | Classic SML / MLton | Count newline characters through a stream scanner. |
| [checksum](#checksum) | Classic SML / MLton | Fold packed 32-bit words into a modular network checksum. |
| [boyer](#boyer) | Classic SML / MLton | Prove a substituted theorem with the classic symbolic rewriting checker. |
| [nucleic](#nucleic) | Classic SML / MLton | Search Pseudoknot nucleotide conformations and check the maximum atom distance. |
| [life](#life) | Classic SML / MLton | Advance a list-based Game of Life glider gun and summarize its live cells. |
| [matrix-multiply](#matrix-multiply) | Classic SML / MLton | Multiply dense matrices and validate every product entry against a closed form. |
| [md5](#md5) | Classic SML / MLton | Compress deterministic byte blocks using the MD5 rounds and padding. |
| [fft](#fft) | Classic SML / MLton | Transform analytical Fourier data and check the resulting ramp. |
| [binary-trees](#binary-trees) | Classic SML / SML/NJ | Build, traverse and retain binary trees of varying depths. |
| [flat-array](#flat-array) | Classic SML / MLton | Fold a vector of pairs using explicit checked 32-bit arithmetic. |
| [peek](#peek) | Classic SML / MLton | Retrieve mixed-width values from generative-exception property lists. |
| [psdes-random](#psdes-random) | Classic SML / MLton | Generate Word32 values with the four-round pseudo-DES generator. |
| [mandelbrot](#mandelbrot) | Classic SML / MLton | Evaluate the original escape-iteration loop with its unusual coordinate formula. |
| [pidigits](#pidigits) | Classic SML / MLton | Produce pi digits until a selected zero occurrence using an IntInf spigot. |
| [logic](#logic) | Classic SML / MLton | Find the first peg-solitaire solution by continuation-based unification. |
| [zebra](#zebra) | Classic SML / MLton | Solve the zebra puzzle using constraint propagation and fluid state. |
| [count-graphs](#count-graphs) | Classic SML / MLton | Enumerate graph isomorphism classes with pruning and higher-order folds. |
| [many_refs](#many_refs) | Classic SML / ML Kit | Retain three tables of real references and repeatedly update every element. |
| [tensor](#tensor) | Classic SML / MLton | Apply real and paired-complex elementwise and contraction operators, checking every result. |
| [zern](#zern) | Classic SML / MLton | Accumulate phase screens and validate every complex E-field value. |
| [smith-normal-form](#smith-normal-form) | Classic SML / MLton | Reduce an IntInf matrix to Smith normal form and consume its diagonal. |
| [ratio-regions](#ratio-regions) | Classic SML / MLton | Segment a fixed grid by preflow-push max flow and validate its min-cut mask. |
| [mpuz](#mpuz) | Classic SML / MLton | Enumerate distinct digit assignments to a fixed multiplication puzzle. |
| [DLXSimulator](#dlxsimulator) | Classic SML / MLton | Interpret five embedded DLX programs and consume every simulated output. |
| [knuth-bendix](#knuth-bendix) | Classic SML / MLton | Complete geometric group equations and validate the resulting rewrite rules. |
| [tyan](#tyan) | Classic SML / MLton | Compute the cyclic polynomial Groebner basis over F17 and consume its term summaries. |
| [lexgen](#lexgen) | Classic SML / MLton | Generate a lexer from the original SML specification and compare every output byte. |
| [mlyacc](#mlyacc) | Classic SML / MLton | Generate an LALR parser from the original SML grammar and compare its source and signature. |
| [hamlet](#hamlet) | Classic SML / MLton | Parse, elaborate and evaluate a unary arithmetic program with the HaMLet interpreter. |
| [kitfib35](#kitfib35) | Classic SML / ML Kit | Evaluate the ML Kit Fibonacci recurrence with its single n<1 base case. |
| [fib0](#fib0) | Classic SML / ML Kit | Evaluate the two-base-case development Fibonacci recurrence. |
| [kitreynolds2](#kitreynolds2) | Classic SML / ML Kit | Search a shared tree with a chain of ancestor predicates. |
| [kitreynolds3](#kitreynolds3) | Classic SML / ML Kit | Search the same shared tree using explicit ancestor lists. |
| [kitloop2](#kitloop2) | Classic SML / ML Kit | Count down a lexicographic pair using a tail-recursive loop. |
| [kitdangle](#kitdangle) | Classic SML / ML Kit | Build and consume one closure chain retaining list payloads. |
| [kitdangle3](#kitdangle3) | Classic SML / ML Kit | Build and release three closure chains sequentially. |
| [msort](#msort) | Classic SML / ML Kit | Sort the original ascending sequence with alternating-split copying mergesort. |
| [kittmergesort_tp](#kittmergesort_tp) | Classic SML / ML Kit | Regenerate and sort ten lists in process using the shared copying kernel. |
| [barnes-hut](#barnes-hut) | Classic SML / MLton | Advance a seeded three-dimensional N-body model with octree force approximation. |
| [tsp](#tsp) | Classic SML / MLton | Build and validate a divide-and-conquer travelling-salesman tour. |
| [fannkuch](#fannkuch) | Classic SML / SML/NJ | Enumerate permutations, flip their prefixes and consume the alternating checksum. |
| [f-arith](#f-arith) | Classic SML / SML/NJ | Accumulate paired Leibniz-series terms and check the approximation of pi. |
| [stream-sieve](#stream-sieve) | Classic SML / SML/NJ | Demand a prime from the original nonmemoized infinite-stream sieve. |
| [twenty-four](#twenty-four) | Classic SML / SML/NJ | Enumerate arithmetic-expression solutions using continuation callbacks. |
| [simple](#simple) | Classic SML / MLton | Compute a hydrodynamic time step and check all final state arrays. |
| [nbody](#nbody) | Classic SML / SML/NJ | Advance five immutable solar-system records and validate their total energy. |
| [output1](#output1) | Classic SML / MLton | Write individual characters to a regular file and validate every output byte. |
| [ray](#ray) | Classic SML / MLton | Interpret the original sphere scene and validate its rendered dump image. |
| [raytrace](#raytrace) | Classic SML / MLton | Render the original chess scene and check every quantized RGB pixel. |
| [vliw](#vliw) | Classic SML / MLton | Schedule and compress instructions, then validate both assembly streams. |
| [fxp](#fxp) | Classic SML / MLton | Parse deterministic generated XML and validate its complete tag and attribute counts. |
| [model-elimination](#model-elimination) | Classic SML / MLton | Search the original first-order problem sets with deterministic inference budgets. |
| [sat](#sat) | Classic SML / SML/NJ | Solve a fixed Boolean formula with nested higher-order choices. |
| [boyer-smlnj](#boyer-smlnj) | Classic SML / SML/NJ | Prove the original theorem using the modern modular SML/NJ rewriting checker. |
| [logic-smlnj](#logic-smlnj) | Classic SML / SML/NJ | Find a peg-solitaire solution through the modern modular unifier and trail. |
| [life-smlnj](#life-smlnj) | Classic SML / SML/NJ | Repeat fifty-generation glider-gun evolutions with complete coordinate checks. |
| [minimax](#minimax) | Classic SML / SML/NJ | Build and score complete tic-tac-toe trees with and without a transposition table. |
| [iter-pidigits](#iter-pidigits) | Classic SML / SML/NJ | Generate a fixed number of pi digits with the iterative IntInf spigot. |
| [mazefun](#mazefun) | Classic SML / SML/NJ | Generate and validate complete deterministic mazes using persistent list matrices. |
| [queens-lazy](#queens-lazy) | nofib | Count queen placements using memoized level-generation streams. |
| [queens-strict](#queens-strict) | nofib | Count queen placements using eagerly generated list levels. |
| [nqueens](#nqueens) | Sandmark | Count queen placements by depth-first search with mutable sibling totals. |
| [rec_seq_ack](#rec_seq_ack) | Sandmark | Evaluate strict Ackermann calls and consume every repeated result. |

## Running and interpreting checks


From the repository root:

```sh
make bench-check
make bench-check BENCH_PROFILE=normal
make bench-check BENCH_PROFILE=large
```

Configuration names are the existing Basis matrix names. For example:

```sh
make bench-check BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt
make bench-check BENCH_CONFIGS=native:mlton,native:smlnj-legacy,native:polyml
make bench-check BENCH_FILTER=primes
```

The default `rune,hosts` selects Rune and the six hosts installed by
`make hosts`. Standalone `xc1` exports remain unavailable; see the measurement
document for the adapter limitation. Missing requested
configurations fail visibly; they do not count as passing comparisons.
These commands check correctness. `make bench`, `make bench-count` and
`make bench-stats` provide separate serial timing, count and runtime-statistics
runs. See [measurement commands and limitations](measurement.md).

The [manifest](manifest.tsv) records ordered sources, source identity,
profile arguments, expected-result files, limits, diagnostic tags, input files, result-check mode and implementation
status. XML and other generated inputs have a fixed SML recipe and profile
arguments instead of an upstream file identity. Implementation status records a port; recorded runs in validation.md
provide the evidence for correctness on specific hosts and profiles.
The shared SML catalogue validates it before the thin shell runner executes
jobs through the existing matrix. Source inventory metadata is separate
from this runnable catalogue.

Smoke and normal profiles are required for imported programs. Large profiles
are explicitly selected; an application need not invent a large profile.
The manifest records overrides to the standard limits.

Every program reads its benchmark name, space-separated arguments and
expected result as three input lines. The runner supplies a fixed regular
input file and records output in an isolated `tests/out/benchmarks/PROFILE/run.XXXXXX/NAME`
directory, printed at launch. Concurrent correctness invocations have separate
job lists, source lists, input files and result directories; they cannot
overwrite each other. The stable program names and relative data filenames
are the same within each configuration's fresh working directory.
The SML driver compares the complete one-line result and reports PASS/FAIL.
It also rejects mismatched names and exceptions. Interactive hosts see the
same input as compiled programs, without leaking launcher arguments.

Limits apply to compilation and execution phases. On Linux, the ordinary
configurations use a virtual-address-space quota. Compact Poly/ML reserves
18 GiB of uncommitted address space; it instead uses a data-memory quota,
a managed heap capped at half that quota, and a 64 MiB stack-space reservation.
Actual limit settings appear in each result log. These accounting methods
are recorded explicitly and are not RSS measurements or equal-heap claims.

The independent and negative tests are:

```sh
sh tests/benchmarks/check-pilots.sh
sh tests/benchmarks/check-classic.sh
python3 tests/benchmarks/test-inventory.py
python3 scripts/benchmark-inventory.py --check
```

The source audit can additionally be reproduced with all five pinned trees:

```sh
python3 scripts/benchmark-inventory.py --check \
  --source mlton=/path/to/mlton \
  --source smlnj=/path/to/smlnj-benchmarks \
  --source mlkit=/path/to/mlkit \
  --source nofib=/path/to/nofib \
  --source sandmark=/path/to/sandmark
```

The Python tool reads source metadata; it never executes upstream scripts.
Benchmark kernels, input generation, result checks and catalogue logic are
SML. Review changes before regenerating the source inventory with `--write`.

## tak

The MLton version of the strict Takeuchi function returns `z` when `y >= x`
and otherwise recursively evaluates three smaller calls. Preserve this
particular recurrence: similarly named tarai variants may return a different
value or use a different evaluation strategy.

[Provenance](tak/PROVENANCE.md) pins MLton's source; its individual author is
not stated. [Gabriel's benchmark book](https://dreamsongs.com/Files/Timrep.pdf)
provides the classic recursive-benchmark context.

The port moves the unchanged recurrence into a structure, accepts sizes
and repetitions at runtime, and accumulates every result in an IntInf
checksum. The original hardcoded `(33,22,11)` is the large profile;
smoke uses `(18,12,6)` once and normal `(24,16,8)` ten times. Checksums are
`7`, `90`, and `22`, independently calculated by a memoized recurrence.
The kernel itself remains unmemoized. Calls, branching, primitive arithmetic
and recursion are diagnostic hypotheses; allocation is principally driver
and checksum overhead, so this is not a collector workload.

## kittmergesort

[The ML Kit source](kittmergesort/PROVENANCE.md) attributes top-down mergesort
to Paulson's book. Its merge copies the remainder even when one argument
is empty, permitting local regions. That copying policy, custom recursive
length, take/drop operations and generator are preserved. Consult
[Paulson's Lists chapter](https://doi.org/10.1017/CBO9780511811326.005) and
[the ML Kit region/GC study](https://elsman.com/mlkit/pdf/jfp2021.pdf).

Inputs use seed 1 and `next = 167 * seed mod 2147`, with 100, 50,000 and
100,000 elements. The large size is the original input. The port removes
progress printing, parameterizes the size and consumes the whole sorted
list, checking order and returning length, IntInf sum and a Word32 rolling
hash. Expected summaries were independently calculated with Python's sort
and reviewed; exact values are in the three `.expected` files.

The list operations and copying policy make allocation, lifetimes,
recursion and representation selection plausible sensitivities. GPL and
project notices are included beside the source. The checksum is additional
validation, not a replacement for the sorting workload.

## primes-lazy

[nofib provenance](primes-lazy/PROVENANCE.md) identifies the finite sieve
`map head (iterate the_filter [2..n*n]) !! n`. The index is zero-based, so
size 10 yields the eleventh prime, 31. The SML implementation creates finite
streams with memoized tails and filters out multiples after each selected
head; values outside the demanded prefix remain delayed.

This is a newly written SML implementation, with the source algorithm as
its reference. It is not a general laziness library. Memoization is tested
by forcing one delayed computation twice and observing one evaluation.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies
suite context; the pinned source supplies the exact algorithm and bounds.

Profiles use `(size,repetitions)` of `(10,1)`, `(100,100)` and `(400,100)`.
The large size is nofib's fast input; normal is deliberately smaller than
its own normal input, and smoke reduces repetition. Results are summed
instead of printing 100 equal lines. Expected sums `31`, `54700`, and
`274900` agree with the original compiled by GHC and an independent
trial-division prime generator. Each repetition constructs a fresh sieve.
Investigate closures, demand, sharing, allocation and collector behavior;
these are hypotheses, not measured performance conclusions.

## primes-strict

[Provenance](primes-strict/PROVENANCE.md), input bounds, result convention
and expected sums are shared with [primes-lazy](#primes-lazy). The strict
version builds `[2..n*n]` as a list and eagerly filters each remainder.
It therefore computes list elements the lazy variant does not demand.
This is an explicit evaluation-style variant, not an identical Haskell
workload. Independent tests compare both implementations to trial division
for sizes 3 through 80. Sizes below 3 are rejected because the finite interval
need not contain the requested zero-based prime.

Compare list traversal, allocation and the effectiveness of list-operation
optimization against the lazy version, keeping their times and counts
separate. Neither version uses a cached prime result across invocations.

## bdd

[Provenance](bdd/PROVENANCE.md) credits Xavier Leroy's Caml translation;
the original SML author is unspecified. The upstream copyright and QPL 1.0
notice are retained. Unmodified upstream files and a separate translation
patch accompany the SML port. [Bryant's BDD paper](https://www.cs.cmu.edu/~bryant/pubdir/ieeetc86.pdf)
explains the algorithm family; it does not identify the benchmark's original
SML author.

The benchmark builds a hidden-weighted-bit function with unique-node
hashing, table growth, negation and operation caches. The port preserves the
upstream shared AND/XOR cache, insertion policy and right-before-left
allocation schedule explicitly. It retains separate operation functions.
State is reset between invocations. Hash indexing and the random low bit
use Word32 to avoid host-width overflow; tested indices fit every host int.
The source's optional GC-statistics output is removed.

Profiles use 8, 18 and 22 variables, each checked on 100 generated assignments.
The large variable count is the upstream default. Results include variables,
last node ID and test count: `8 382 100`, `18 14289 100`, and `22 47088 100`.
These agree with the original OCaml program, instrumented only to expose
its final node ID.

The upstream random low bit alternates and covers few distinct assignments.
Separate tests therefore check every truth assignment for sizes 1 through
10 against the mathematical hidden-weighted-bit definition. This validates
the benchmark's construction, not a general-purpose BDD API. Investigate
allocation, hash/caching behavior, arrays, recursion and locality before
attributing a performance change to a particular compiler pass.

## fib

Evaluate naive binary-recursive Fibonacci. See [provenance](fib/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/fib.sml`.

Naive binary-recursive Fibonacci. Upstream checks fib 41 = 165580141.
Smoke/normal are smaller; large retains 41. An iterative recurrence supplies
the independent expected values. Calls, branching and recursion are the
diagnostic targets; there is no memoization in the benchmark.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `30 1` | `832040` |
| large | `41 1` | `165580141` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tailfib

Evaluate tail-recursive Fibonacci with two accumulators. See [provenance](tailfib/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailfib.sml`.

Tail-recursive Fibonacci. The original 44-step recurrence and accumulator
order are unchanged. Large preserves the original million repetitions. The
IntInf result sum is additional validation and avoids narrow-host overflow.
Tail calls and accumulator arithmetic are the diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `44 1000` | `701408733000` |
| large | `44 1000000` | `701408733000000` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## even-odd

Call mutually recursive parity predicates. See [provenance](even-odd/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/even-odd.sml`.

Mutually tail-recursive parity predicates. Large retains the upstream input
of 500000000; smaller profiles permit quick correctness checks. Both
predicates are checked against arithmetic parity as well as each other.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `1` |
| normal | `1000000 1` | `1` |
| large | `500000000 1` | `1` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## merge

Merge interleaved sorted lists using non-tail recursion. See [provenance](merge/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/merge.sml`.

Stephen Weeks is credited upstream. The non-tail-recursive merge is retained.
Large preserves the original 100000-element input lists. The checker now
consumes every output element and verifies the complete sequence 0..2n-1,
instead of merely testing its head. Sum = n(2n-1) per repetition.
Allocation, list traversal, recursion and tail calls are relevant.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `19900` |
| normal | `10000 10` | `1999900000` |
| large | `100000 25` | `499997500000` |

Source inspection suggests sensitivity to lists-streams, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tailmerge

Merge sorted lists using a reversed tail-recursive accumulator. See [provenance](tailmerge/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailmerge.sml`.

Stephen Weeks is credited upstream. The tail-recursive reversed-accumulator merge is retained.
Large preserves the original 100000-element input lists. The checker now
consumes every output element and verifies the complete sequence 0..2n-1,
instead of merely testing its head. Sum = n(2n-1) per repetition.
Allocation, list traversal, recursion and tail calls are relevant.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `19900` |
| normal | `10000 10` | `1999900000` |
| large | `100000 25` | `499997500000` |

Source inspection suggests sensitivity to lists-streams, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## imp-for

Traverse seven nested mutable-counter loops. See [provenance](imp-for/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/imp-for.sml`.

Seven nested imperative loops over references, preserving the upstream
loop implementation and nesting. Large retains width 10. Expected counts
are width^7 times repetitions, independently calculated. Mutable refs,
closures, loop lowering and allocation are diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `2 1` | `128` |
| normal | `5 1` | `78125` |
| large | `10 1` | `10000000` |

Source inspection suggests sensitivity to closures, mutation. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector-rev

Reverse a vector twice and consume every element. See [provenance](vector-rev/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector-rev.sml`.

Stephen Weeks. Retains tabulate-based vector reversal. Every element of
the double reversal is checked, strengthening the original head-only test.
Large preserves 200000 elements and the original inclusive 1001 iterations.
The independent sum is n(n-1)/2 per repetition.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `4950` |
| normal | `10000 10` | `499950000` |
| large | `200000 1001` | `20019899900000` |

Source inspection suggests sensitivity to arrays, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector32-concat

Concatenate Int32 vectors and validate their contents. See [provenance](vector32-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector32-concat.sml`.

Stephen Weeks. Retains Int32 element arithmetic and vector concatenation.
Large preserves 20000 elements and the original inclusive 10001 iterations.
Per-run expected sum n(n-1) stays representable in a 31-bit host int;
the cross-iteration validation sum uses IntInf.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `9900` |
| normal | `5000 10` | `249950000` |
| large | `20000 10001` | `4000199980000` |

Source inspection suggests sensitivity to arrays, integer-arithmetic, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector64-concat

Concatenate Int64 vectors and validate their contents. See [provenance](vector64-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector64-concat.sml`.

Stephen Weeks. Retains Int64 element arithmetic and vector concatenation.
Large preserves 20000 elements and the original inclusive 10001 iterations.
Per-run expected sum n(n-1) stays representable in a 31-bit host int;
the cross-iteration validation sum uses IntInf.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `9900` |
| normal | `5000 10` | `249950000` |
| large | `20000 10001` | `4000199980000` |

Source inspection suggests sensitivity to arrays, integer-arithmetic, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## string-concat

Concatenate cyclic alphabet strings and consume every character. See [provenance](string-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/string-concat.sml`.

Retains the cyclic A-Z input, triple String.concat and complete character
fold. Large preserves length 2017 and 10001 inclusive iterations. Expected
sums come from the independently generated character sequence; the original
per-iteration 468705 is retained as the large result component.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `26 1` | `6045` |
| normal | `1000 100` | `23224800` |
| large | `2017 10001` | `4687518705` |

Source inspection suggests sensitivity to strings, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## wc-input1

Count newline characters by reading a generated file one character at a time. See [provenance](wc-input1/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/wc-input1.sml`.

Stephen Weeks. Retains file generation, TextIO.input1 reading and
newline counting. Source newlines occur at positions divisible by ten,
including zero: ceil(n/10) is the independent oracle. Files are closed and
removed on success and failure. The scanner variant returns its observed
count rather than discarding the result after its internal assertion.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 10` | `100000` |
| large | `1000000 3` | `300000` |

Source inspection suggests sensitivity to io, strings. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## wc-scanStream

Count newline characters through a stream scanner. See [provenance](wc-scanStream/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/wc-scanStream.sml`.

Stephen Weeks. Retains file generation, TextIO.scanStream reading and
newline counting. Source newlines occur at positions divisible by ten,
including zero: ceil(n/10) is the independent oracle. Files are closed and
removed on success and failure. The scanner variant returns its observed
count rather than discarding the result after its internal assertion.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 10` | `100000` |
| large | `1000000 3` | `300000` |

Source inspection suggests sensitivity to io, strings. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## checksum

Fold packed 32-bit words into a modular network checksum. See [provenance](checksum/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/checksum.sml`.

Stephen Weeks; based on Derby, The Performance of FoxNet 2.0 (1999).
Preserves packed little-endian word access and the original zero-filled
buffer. Large preserves 10000000 bytes. All zero words contribute zero,
which supplies the reviewed mathematical result. A nonzero-buffer correctness
test is required separately, since a zero-input benchmark alone is weak.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1024 1` | `0` |
| normal | `1000000 10` | `0` |
| large | `10000000 1` | `0` |

Source inspection suggests sensitivity to arrays, integer-arithmetic. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## boyer

Prove a substituted theorem with the classic symbolic rewriting checker. See [provenance](boyer/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/boyer.sml`. Project notice: LICENSE.

Classic SML/NJ tautology checker. Terms, rewrite rules, property lists,
substitution and theorem are retained. Unlike the original unit driver, every
returned theorem result must be true. The same theorem appears in upstream
Main.testit as Proved. This observes the actual computation without adding
a second theorem invocation. The repetition count is runtime input.

The unmodified source and separate adaptation patch accompany the port.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10` | `10` |
| large | `24` | `24` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## nucleic

Search Pseudoknot nucleotide conformations and check the maximum atom distance. See [provenance](nucleic/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/nucleic.sml`. Project notice: LICENSE.

Pseudoknot (nucleic) molecular search. The biological data, coordinate
transforms, geometry and search are unchanged. The numeric result is
checked against the upstream 33.797594890762724 reference with the same
relative 1e-6 tolerance. The returned sum counts verified computations,
not mere successful termination. Hartel et al., JFP 1996, is the literature
reference. Upstream explicitly notes earlier assembler versions of the
coordinate transform; this port retains its SML implementation.

The unmodified source and separate adaptation patch accompany the port.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `4` | `4` |
| large | `12` | `12` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## life

Advance a list-based Game of Life glider gun and summarize its live cells. See [provenance](life/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/life.sml`. Project notice: LICENSE.

Classic SML/NJ list-based Life and its gun seed. Coordinate lists, neighbor
collection, lexicographic normalization and the next-generation algorithm
are unchanged. Profile generations are reduced from the original 25000
for practical portable runs; that value remains accepted by the driver.
All living coordinates are consumed into a count and Word32 checksum,
including cells that the original drawing helper would hide outside its
nonnegative plotting window. An independent set/neighbor-counter simulator
supplies the reviewed expected generations.

The unmodified source and separate adaptation patch accompany the port.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10` | `61 3AA2F3FF` |
| normal | `100` | `74 F4838721` |
| large | `1000` | `28 60A560FF` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## matrix-multiply

Multiply dense matrices and validate every product entry against a closed form. See [provenance](matrix-multiply/PROVENANCE.md), the retained notices, and the source adaptation.

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/matrix-multiply.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Stephen Weeks. Retains Array2 multiplication and dot-product traversal.
Large preserves dimension 500. Every entry is checked against the independent
closed form n*i*j+(i+j)*sum(k)+sum(k*k). The total uses IntInf for narrow
hosts. These inputs produce exactly representable integral doubles.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `656` |
| normal | `50` | `326156250` |
| large | `500` | `33729281250000` |

Source inspection suggests sensitivity to numerical, arrays. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## md5

Compress deterministic byte blocks using the MD5 rounds and padding. See [provenance](md5/PROVENANCE.md), the retained notices, and the source adaptation.

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/md5.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Retains the original MD5 state, compression rounds, padding and hex encoding.
Input bytes are i mod 256. Large preserves the original 10000-byte block
repeated 100000 times. Python hashlib supplies an independent digest; the
large digest additionally matches the upstream literal reference.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `64 1` | `b2d3f56bc197fd985d5965079b5e7148` |
| normal | `1000 100` | `333cc4cfc0deca30c684f147b4a800a1` |
| large | `10000 100000` | `766a2bb5d24bddae466c572bcabca3ee` |

Source inspection suggests sensitivity to integer-arithmetic, arrays. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## fft

Transform analytical Fourier data and check the resulting ramp. See [provenance](fft/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fft.sml`.

Retains the in-place FFT, bit reversal, complex arrays and analytical
input whose transform should be the real ramp 0..n-1 with zero imaginary
component. The original error computation is now returned instead of
discarded. Every run checks maximum residual <= n*1e-8; the nonnegative
check also rejects NaN. Large is the largest original transform. Numeric
validation is separate from exact result formatting.
Original source, notice and separate adaptation patch are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `256 1` | `1` |
| normal | `4096 10` | `10` |
| large | `8388608 1` | `1` |

Source inspection suggests sensitivity to allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## binary-trees

Build, traverse and retain binary trees of varying depths. See [provenance](binary-trees/PROVENANCE.md), the retained notices, and the source adaptation.

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/binary-trees`.

Copyright 2026 Fellowship of SML/NJ. Tree datatype, top-down construction,
checksums, stretch/retained trees and depth-dependent repetition are retained.
Logging is replaced by one consumed summary; nIters and full-tree node counts
supply the independent formula. Large preserves upstream depth 21.
Allocation, liveness and traversal are the diagnostic targets.
Original source, notice and separate adaptation patch are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6` | `255 4016 127` |
| normal | `12` | `16383 649904 8191` |
| large | `21` | `8388607 601183584 4194303` |

Source inspection suggests sensitivity to allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## flat-array

Fold a vector of pairs using explicit checked 32-bit arithmetic. See [provenance](flat-array/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/flat-array.sml`. Original, patch and notice retained.

Vector of pairs and repeated fold, retaining the original overflow-reset policy.
Int32 makes the upstream 32-bit arithmetic assumption explicit on all hosts.
The original million entries are normal and large; the actual fold sums are
consumed in IntInf. Independent bounded Python arithmetic supplies fixtures.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `1000000` |
| normal | `1000000 10` | `11056941910` |
| large | `1000000 100` | `110569419100` |

Source inspection suggests sensitivity to vectors, integer-width. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## peek

Retrieve mixed-width values from generative-exception property lists. See [provenance](peek/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/peek.sml`. Original, patch and notice retained.

Stephen Weeks. Generative exceptions implement heterogeneous property lists
with Int32 and Int64 values. Parameterizes only the inner loop and repetitions.
Both observed accumulators are checked by the original arithmetic invariants
and returned. Large preserves ten million inner iterations. Poly/ML lacks
Int64; this configuration is unavailable, not a different-width emulation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `64000 58000` |
| normal | `1000000 10` | `640000000 580000000` |
| large | `10000000 10` | `6400000000 5800000000` |

Source inspection suggests sensitivity to exceptions. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## psdes-random

Generate Word32 values with the four-round pseudo-DES generator. See [provenance](psdes-random/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/psdes-random.sml`. Original, patch and notice retained.

Stephen Weeks, Numerical Recipes pseudo-DES generator. Four Word32 rounds
and alternating generated words are retained. Removed top-level executions;
the actual modular sum is returned. Python bit arithmetic supplies smaller
fixtures; the original literal supplies the 150 million-word fixture.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000` | `CA36C720` |
| normal | `1000000` | `43E080E` |
| large | `150000000` | `132B1B67` |

Source inspection suggests sensitivity to modular-arithmetic. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## mandelbrot

Evaluate the original escape-iteration loop with its unusual coordinate formula. See [provenance](mandelbrot/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mandelbrot.sml`. Original, patch and notice retained.

SML/NJ-derived numerical loop. Preserves the unusual upstream coordinate
formula x_base * (delta + j), initial z=c and escape threshold, rather than
substituting a conventional Mandelbrot image. Side and iteration limit are
parameters. Python reproduces the exact iteration convention. For j >= 2 the initial squared real coordinate exceeds four, so the
independent large calculation skips those mathematically zero contributions.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `32 128` | `2788` |
| normal | `1024 2048` | `1073042` |
| large | `32768 2048` | `34365041` |

Source inspection suggests sensitivity to numerical. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## pidigits

Produce pi digits until a selected zero occurrence using an IntInf spigot. See [provenance](pidigits/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/pidigits.sml`. Original, patch and notice retained.

Jeremy Gibbons linear fractional transformation spigot, in the MLton source.
Keeps IntInf arithmetic and the original function-stream implementation.
The benchmark stops on a zero occurrence, not at a fixed digit count; its
zero index and returned digit position are zero based. Chudnovsky expansion
provides an independent oracle. Stream functions are nonmemoized as in this
SML source; no Haskell demand equivalence is claimed.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `3` | `65` |
| normal | `30` | `330` |
| large | `1000` | `10376` |

Source inspection suggests sensitivity to big-integers, streams. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## logic

Find the first peg-solitaire solution by continuation-based unification. See [provenance](logic/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/logic.sml`. Original, patch and notice retained.

SML/NJ continuation-based unification and backtracking for peg solitaire.
Retains the original board and first-solution stopping condition. Returning
normally without reaching the success continuation fails validation, unlike
the original driver. Upstream testit independently reports yes for this board.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10` | `10` |
| large | `100` | `100` |

Source inspection suggests sensitivity to symbolic, exceptions, search. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## zebra

Solve the zebra puzzle using constraint propagation and fluid state. See [provenance](zebra/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zebra.sml`. Original, patch and notice retained.

Stephen Weeks, 1999 zebra puzzle constraint solver. Retains generative
exceptions, fluid state and consistency propagation. The observed count of
3342 attempted assignments is asserted by upstream and returned per search.
Large preserves one original driver batch (its inclusive loop ran 1001).
This fixture checks control flow; additional solution constraints are required
before using it to claim a general constraint solver correctness result.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `3342` |
| normal | `100` | `334200` |
| large | `1001` | `3345342` |

Source inspection suggests sensitivity to search, exceptions. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## count-graphs

Enumerate graph isomorphism classes with pruning and higher-order folds. See [provenance](count-graphs/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/count-graphs.sml`. Original, patch and notice retained.

Henry Cejtin graph isomorphism-class enumeration using permutation, subset
and graph folds. Retains pruning and graph criterion, replaces progress
printing with the actual class count. Reference counts 2, 20 and 250 come from the pinned unmodified source
compiled by MLton; the added driver only exposes f(n). Smoke counts the two
nonisomorphic four-vertex/four-edge graphs (cycle and triangle with a tail).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `2` |
| normal | `8` | `20` |
| large | `11` | `250` |

Source inspection suggests sensitivity to graphs, search. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## many_refs

Retain three tables of real references and repeatedly update every element. See [provenance](many_refs/PROVENANCE.md), the retained notices, and the source adaptation.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/many_refs.sml`. Original, patch and notice retained.

ML Kit development allocation/retention workload. Three tables of boxed
real refs and sequential updates are retained. Original table length 100 and
100000 increments are normal; large scales retained refs. Every table is
checked against the exact number of increments, including the two tables
that upstream did not print. Their exact IntInf sum is returned.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 10` | `3000` |
| normal | `100 100000` | `30000000` |
| large | `10000 100000` | `3000000000` |

Source inspection suggests sensitivity to retained-data, refs, gc. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tensor

Apply real and paired-complex elementwise and contraction operators, checking every result. See [provenance](tensor/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tensor.sml`. Original, adaptation patch and notices retained.

Juan Jose Garcia Ripoll tensor library, imported through MLton. The individual copyright and redistribution conditions are embedded in the
source (lines 31-68), including the acknowledgement requirement and author
name restrictions. Retained verbatim in TENSOR-LICENSE and upstream source.
Real and paired-complex representations, elementwise
operators and both contraction orders are retained. Checked Real64Array
accesses replace Unsafe access. The clock/timing printer is removed; every
result element is checked against 2, 1 or the contraction dimension.
Runs 20 repetitions of each elementwise operator and four of each contraction
as upstream, on one selected dimension rather than the five-size outer sweep.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `1` |
| normal | `100 1` | `1` |
| large | `500 1` | `1` |

Source inspection suggests sensitivity to numerical, arrays, tensors. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## zern

Accumulate phase screens and validate every complex E-field value. See [provenance](zern/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zern.sml`. Original, adaptation patch and notices retained.

David McClain phase-screen E-field study; source also credits Stephen Weeks
and retains AT&T notices. Fifteen coefficient screens and the flat real
array operations are unchanged. collect uses indices 1 through 15, so the
coefficients are 2 through 16 and their sum is 135. The independent field
is cos(1.35*i)+i*sin(1.35*i). Check both components at every cell with
absolute error <=1e-8. Removes clock reporting and selects one side length.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1` | `1` |
| normal | `128 1` | `1` |
| large | `128 100` | `100` |

Source inspection suggests sensitivity to numerical, arrays, phase-screens. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## smith-normal-form

Reduce an IntInf matrix to Smith normal form and consume its diagonal. See [provenance](smith-normal-form/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/smith-normal-form.sml`. Original, adaptation patch and notices retained.

Henry Cejtin integer Smith normal form. Retains the embedded matrix and
IntInf elimination, and consumes every diagonal entry while rejecting
nonzero off-diagonal entries. Profiles use leading 4, 12 and 26 squares;
upstream dimension 35 is still accepted by the driver but not selected.
The previous external runner used 26 to bound intermediate growth.
Review diagonal divisibility and compare the absolute diagonal product with
an independent Bareiss determinant before accepting fixtures.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `1 ~1 1 ~7506` |
| normal | `12` | `1 1 ~1 1 ~1 ~1 ~1 ~1 1 1 1 ~6096777698704` |
| large | `26` | `1 ~1 ~1 1 1 1 ~1 ~1 1 ~1 1 ~1 1 1 1 1 ~1 ~1 1 1 1 ~1 ~1 ~1 ~1 ~60208115211646196979849372947415` |

Source inspection suggests sensitivity to big-integers, matrices. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## ratio-regions

Segment a fixed grid by preflow-push max flow and validate its min-cut mask. See [provenance](ratio-regions/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ratio-regions.sml`. Original, adaptation patch and notices retained.

Jeff Siskind Scheme algorithm translated by Stephen Weeks. The Cox/Rao/Zhong
ratio-region reduction and preflow-push wave scheduling are retained.
The original generated capacities and weights remain fixed; expose and
consume the returned min-cut mask by counting true cells. No clock limit
is introduced. Reference fixtures must check the retained mask as well as
the count, before performance interpretations about flow behavior.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `4` |
| normal | `32` | `256` |
| large | `128` | `4096` |

Source inspection suggests sensitivity to graphs, arrays, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## mpuz

Enumerate distinct digit assignments to a fixed multiplication puzzle. See [provenance](mpuz/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mpuz.sml`. Original, adaptation patch and notices retained.

Stephen Weeks, based loosely on Laurent Vaucher OCaml solution. Enumerates
distinct decimal assignments to the fixed multiplication puzzle. The
previously discarded solution text is observed, not replaced with a constant
success marker. Text length and Word32 rolling hash consume all assignments;
full reviewed reference text is retained beside the fixtures. Added output
observation allocates and is included in these workloads.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `61 40183CD7` |
| normal | `10` | `610 FF39A16D` |

Source inspection suggests sensitivity to search, integer-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## DLXSimulator

Interpret five embedded DLX programs and consume every simulated output. See [provenance](DLXSimulator/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/DLXSimulator.sml`. Original, adaptation patch and notices retained.

DLX instruction simulator with the five original programs (Simple, Twos,
Abs, factorial 12, GCD). Retains instruction decoding, memory and pipeline
model. Every simulated program output is returned for every invocation;
statistics printing is removed. The arithmetic outputs have independent
mathematical checks. Full instruction fixtures remain embedded upstream.

Smoke execution exceeded its initial 30-second quota on Rune. Its explicit
limit is now 120 seconds; normal repeats the full five-program set twice.
The timeout is retained in validation records, not counted as a passing run.

The source credits Matthew Thomas Fluet (Harvey Mudd College) and updates by
Stephen Weeks and Matthew Fluet; all header notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `47 ~10 10 479001600 1` |
| normal | `2` | `47 ~10 10 479001600 1 47 ~10 10 479001600 1` |

Source inspection suggests sensitivity to interpreter, words, arrays. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## knuth-bendix

Complete geometric group equations and validate the resulting rewrite rules. See [provenance](knuth-bendix/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/knuth-bendix.sml`. Original, adaptation patch and notices retained.

Knuth-Bendix term-rewriting completion (individual author not stated in this source), from the SML/NJ collection
through MLton. The geometric group equations and recursive path order are
unchanged. Return completed rules instead of discarding them, normalize both
sides of every input equation, and consume the exact completed rule text.
Retains rule ordering and numbering; correctness references cover this
problem, not arbitrary completion termination.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `672 AAE94F6A` |
| normal | `10` | `6720 4714BCB7` |

Source inspection suggests sensitivity to symbolic, rewriting, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## tyan

Compute the cyclic polynomial Groebner basis over F17 and consume its term summaries. See [provenance](tyan/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tyan.sml`. Original, adaptation patch and notices retained.

Thomas Yan multivariate polynomial/Groebner-basis workload. Preserves
the six cyclic equations, monomial trie, F17 modular/polynomial representations
and algorithm. Progress printing stays suppressed; consume only leading monomials and
term counts from the actual basis; complete reviewed upstream output accompanies the digest fixtures.
The additional textual observation and its allocation are recorded workload
changes. No claims about arbitrary polynomial correctness follow from this
fixed system.

Allyn Dimock adapted the TIL version to SML97; Stephen Weeks fixed the u6
input in 2001. The source explicitly records Thomas Yan's benchmark-use
permission and cites his 1998 Journal of Symbolic Computation article,
The Geobucked Data Structure For Polynomials, volume 23(3), pages 285-293.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1608 BFA61E48` |
| normal | `2` | `3216 F8AFEF2B` |

Source inspection suggests sensitivity to symbolic, polynomials, modular-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## lexgen

Generate a lexer from the original SML specification and compare every output byte. See [provenance](lexgen/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/lexgen.sml`. Original, adaptation patch and notices retained.

Classic SML lexgen application from the SML/NJ tools, through MLton.
Preserves the full generator and original SML grammar/lexer input. Uses fixed
relative filenames to remove host working-directory identities from output.
Every generated source/signature/report is byte-exact checked against the
pinned source compiled by MLton. The fixture comparison and file reads are
included in the workload; compilation of the generated source is separate
validation. Original input notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `111408 D050F60A` |
| normal | `3` | `111408 D050F60A` |

Source inspection suggests sensitivity to compiler-application, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## mlyacc

Generate an LALR parser from the original SML grammar and compare its source and signature. See [provenance](mlyacc/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mlyacc.sml`. Original, adaptation patch and notices retained.

Classic SML mlyacc application from the SML/NJ tools, through MLton.
Preserves the full generator and original SML grammar/lexer input. Uses fixed
relative filenames to remove host working-directory identities from output.
Every generated source/signature/report is byte-exact checked against the
pinned source compiled by MLton. The fixture comparison and file reads are
included in the workload; compilation of the generated source is separate
validation. Original input notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `117863 CDA6CD68;3150 27A50FF4` |
| normal | `3` | `117863 CDA6CD68;3150 27A50FF4` |

Source inspection suggests sensitivity to compiler-application, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## hamlet

Parse, elaborate and evaluate a unary arithmetic program with the HaMLet interpreter. See [provenance](hamlet/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/hamlet.sml`. Original, adaptation patch and notices retained.

Andreas Rossberg HaMLet Standard ML interpreter, as embedded by MLton.
Retains parsing, static elaboration and dynamic evaluation. Removes the
interactive session printer/loop and exposes Sml.exec only for observing the
result binding in the returned dynamic basis. The unary arithmetic program
is retained; smoke evaluates four squared (16), normal sixteen squared
(256), and large preserves the original nested power (65536). A host SML traversal consumes the returned unary value; an observer flag
rejects any swallowed fatal interpreter error or interpreted exception. These input changes and added traversal are
explicit workload adaptations, and there is no new Rune language feature.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.sml 1` | `16` |
| normal | `DATA/normal.sml 1` | `256` |
| large | `DATA/large.sml 1` | `65536` |

Source inspection suggests sensitivity to compiler-application, interpreter. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitfib35

Evaluate the ML Kit Fibonacci recurrence with its single n<1 base case. See [provenance](kitfib35/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitfib35.sml`. Original, patch and notices retained.

Recursive Fibonacci with the original n<1 base case, returning F(n+2).
This differs from the MLton fib recurrence. Normal preserves argument 35.
The original wildcard discards the number; the driver consumes every result
in an IntInf sum. An iterative recurrence gives independent fixtures.
The mlton and smlnj source variants have the identical kernel and input,
with only entrypoint wrapping differences; their provenance is retained.

Additional source provenance at the same ML Kit revision:

* `test/kitfib35_mlton.sml`: identical kernel and fixed input; entrypoint wrapping only.
* `test/kitfib35_smlnj.sml`: identical kernel and fixed input; entrypoint wrapping only.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `17711` |
| normal | `35 1` | `24157817` |
| large | `40 1` | `267914296` |

Source inspection suggests sensitivity to calls-recursion. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fib0

Evaluate the two-base-case development Fibonacci recurrence. See [provenance](fib0/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/fib0.sml`. Original, patch and notices retained.

Naive Fibonacci with two unit base values, returning F(n+1). Different
base-case structure and values from kitfib35 and MLton fib. Normal retains
the original input 30 and upstream reference 1346269. The runtime-specific
printNum output adapter is replaced with a consumed IntInf result sum;
the recursive arithmetic kernel remains unchanged.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `10946` |
| normal | `30 1` | `1346269` |
| large | `40 1` | `165580141` |

Source inspection suggests sensitivity to calls-recursion. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitreynolds2

Search a shared tree with a chain of ancestor predicates. See [provenance](kitreynolds2/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitreynolds2.sml`. Original, patch and notices retained.

Shared binary tree with labels descending by depth. The exhaustive
ancestor search remains exponential although mk_tree allocates only n nodes.
Uses a chain of predicate closures for ancestor membership.
No ancestor label can repeat on a path, giving an independent false result
for every positive depth. Normal retains depth 20; output becomes a checked
count of searches. The two representation variants remain separately named.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6 1` | `1` |
| normal | `20 1` | `1` |
| large | `22 1` | `1` |

Source inspection suggests sensitivity to higher-order, shared-data, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitreynolds3

Search the same shared tree using explicit ancestor lists. See [provenance](kitreynolds3/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitreynolds3.sml`. Original, patch and notices retained.

Shared binary tree with labels descending by depth. The exhaustive
ancestor search remains exponential although mk_tree allocates only n nodes.
Uses an explicit ancestor list and membership traversal.
No ancestor label can repeat on a path, giving an independent false result
for every positive depth. Normal retains depth 20; output becomes a checked
count of searches. The two representation variants remain separately named.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6 1` | `1` |
| normal | `20 1` | `1` |
| large | `22 1` | `1` |

Source inspection suggests sensitivity to higher-order, shared-data, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitloop2

Count down a lexicographic pair using a tail-recursive loop. See [provenance](kitloop2/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitloop2.sml`. Original, patch and notices retained.

Tail-recursive lexicographic pair countdown. Retains the original
borrow/reset transition and pair argument. Normal preserves the corrected
upstream maximum 375; large uses the older stated value 2000. Stop only at
(0,0), and return the observed pair instead of printing a done marker.
Tail calls, tuple representation and allocation are diagnostic hypotheses.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `50` | `0 0` |
| normal | `375` | `0 0` |
| large | `2000` | `0 0` |

Source inspection suggests sensitivity to tail-calls, tuples. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitdangle

Build and consume one closure chain retaining list payloads. See [provenance](kitdangle/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitdangle.sml`. Original, patch and notices retained.

One retained closure chain.
Preserves each strict 2000-element payload list and the captured (m,list)
pair inside the singleton. Primitive polymorphic equality is replaced by
SML97 equality. The driver forces each completed chain once to consume its
result; the original dropped the function without evaluating it. This
additional forcing is explicit, and the triangular-number sum independently
validates construction. Normal preserves depth 1000 and payload 2000.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 10` | `55` |
| normal | `1000 2000` | `500500` |
| large | `2000 2000` | `2001000` |

Source inspection suggests sensitivity to closures, allocation, lifetimes. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitdangle3

Build and release three closure chains sequentially. See [provenance](kitdangle3/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitdangle3.sml`. Original, patch and notices retained.

Three closure constructions, released sequentially rather than retained together.
Preserves each strict 2000-element payload list and the captured (m,list)
pair inside the singleton. Primitive polymorphic equality is replaced by
SML97 equality. The driver forces each completed chain once to consume its
result; the original dropped the function without evaluating it. This
additional forcing is explicit, and the triangular-number sum independently
validates construction. Normal preserves depth 1000 and payload 2000.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 10` | `165` |
| normal | `1000 2000` | `1501500` |
| large | `2000 2000` | `6003000` |

Source inspection suggests sensitivity to closures, allocation, lifetimes. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## msort

Sort the original ascending sequence with alternating-split copying mergesort. See [provenance](msort/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/msort.mlb`. Original, adaptation patch and notices retained.

Alternating split mergesort (individual author not stated) with explicit copying of the
remaining merge argument. Ordered project members msort.sml, upto.sml and
msortrun.sml are preserved in upstream/. Normal keeps the original sorted
1..50000 input, not the pseudo-random input of kittmergesort. The driver
validates every element against its expected ordinal and returns length,
IntInf sum and Word32 hash. These fixtures are calculated independently.
The standalone library and invocation entries retain provenance in the
inventory without creating duplicate benchmark implementations.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100` | `100 5050 C1C3524A` |
| normal | `50000` | `50000 1250025000 986A5B08` |
| large | `100000` | `100000 5000050000 CFA6A210` |

Source inspection suggests sensitivity to sorting, lists, allocation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kittmergesort_tp

Regenerate and sort ten lists in process using the shared copying kernel. See [provenance](kittmergesort_tp/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kittmergesort_tp.sml`. Original, adaptation patch and notices retained.

Same sorting kernel and input generator as kittmergesort, with a materially
different ten-repetition in-process driver. The implementation is shared,
while this workload remains separately named and measured. Each invocation
regenerates its list from seed 1 and validates its entire sorted result.
Normal preserves the ten 100000-element calls; large scales the list length.
Every invocation summary is retained in the expected result, rather than
observing only the last call.

The copying kernel and validation live in shared/kittmergesort.sml, with
separate thin named drivers. Each compilation contains one Benchmark
structure; there is no alias/rebinding of another benchmark driver.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `100 98940 43BE5438` |
| normal | `100000 10` | `100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55` |
| large | `1000000 10` | `1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A` |

Source inspection suggests sensitivity to sorting, lists, allocation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## Recorded host coverage

Poly/ML 5.9.2 lacks the optional Int64 structure used by peek and
vector64-concat. These are recorded unavailable comparisons; the suite does
not substitute a different integer width. Real-array kernels instead use
RealArray with an explicit binary64 precision requirement.

ML Kit 4.7.23 crashes compiling the current Boyer, Knuth-Bendix Tyan and FXP
ports. Their logs remain failures and cannot supply measurements. The four
primary systems (Rune, MLton, SML/NJ and Poly/ML) pass applicable smoke
checks. The broader acceptance run and normal-profile results are recorded
in validation.md as they complete.

## barnes-hut

Advance a seeded three-dimensional N-body model with octree force approximation. See [provenance](barnes-hut/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/barnes-hut.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories three-dimensional Barnes-Hut simulation from the
SML/NJ collection. Retains the Plummer distribution, seed 123, octree,
force approximation, leapfrog integration, dtime=.025, eps=.05 and tol=1.
Normal and selected large preserve the original stop time 2.0; smoke uses .05.
Observe every final position and velocity component rather than discarding
the simulation. Reference state comes from the pinned source compiled by
MLton, with a read-only observer, and uses 17 significant decimal digits.
Compare each component with absolute tolerance 1e-8 plus relative 1e-6.
Returns the actual body and step counts after validation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0.05 expected/smoke.tsv` | `16 3` |
| normal | `256 2.0 expected/normal.tsv` | `256 81` |
| large | `8192 2.0 expected/large.tsv` | `8192 81` |

Source inspection suggests sensitivity to numerical, spatial, mutable-data. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## tsp

Build and validate a divide-and-conquer travelling-salesman tour. See [provenance](tsp/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tsp.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories divide-and-conquer travelling-salesman heuristic.
Retains the generated point distribution, tree, nearest-neighbor conquer
and merging/orientation logic. The generator uses the source-commented
32-bit Park-Miller modulus 2147483647 explicitly, with IntInf intermediate
arithmetic, rather than each host's Int.maxInt. This changes generator
representation but keeps MLton's input distribution. Observe the complete
cycle, reject broken backlinks/cardinality, and compare its sorted point
multiset with the input tree. Check length against the pinned upstream
MLton result with absolute and relative tolerance 1e-8. Large uses the
initial 32767-point setting; the later MLton 2097151 override is not selected.
Additional cycle validation/sorting is included in the workload.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `31 10 5.0285603627720601` | `31` |
| normal | `1023 150 34.594758416849281` | `1023` |
| large | `32767 150 190.67246516366754` | `32767` |

Source inspection suggests sensitivity to numerical, spatial, mutable-data. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fannkuch

Enumerate permutations, flip their prefixes and consume the alternating checksum. See [provenance](fannkuch/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/fannkuch`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ fannkuch-redux implementation. Keeps mutable
permutation arrays, rotation order, flip counting and alternating checksum.
Normal retains upstream testit size 7; large retains three size-11 calls.
Return the observed maximum and IntInf sum of checksums. Benchmark Game
reference values are max/checksum (7,11), (16,228), and (51,556355) before
repetition; independent small permutation checks are required.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 1` | `7 11` |
| normal | `7 1` | `16 228` |
| large | `11 3` | `51 1669065` |

Source inspection suggests sensitivity to permutations, mutable-arrays. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## f-arith

Accumulate paired Leibniz-series terms and check the approximation of pi. See [provenance](f-arith/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/f-arith`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ floating arithmetic loop: two alternating
Leibniz terms per iteration. Preserve acc+1/n-1/(n+2) and denominator
increment 4, including their operation order. Check against mathematical
pi with the next-term bound 4/(4*steps+1), plus 8*steps*2^-53 for rounding
accumulation. Large retains the original five billion steps and requires
a default int precision of at least 34; narrower configurations are
unavailable for that profile. Removes logging, consumes the computed value.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000` | `1` |
| normal | `1000000` | `1` |
| large | `5000000000` | `1` |

Source inspection suggests sensitivity to numerical, float-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## stream-sieve

Demand a prime from the original nonmemoized infinite-stream sieve. See [provenance](stream-sieve/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/stream-sieve`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ infinite stream sieve. The stream constructor
holds a strict head and a nonmemoized tail function. This differs from
the memoized nofib finite sieve and is intentionally retained. get uses
a zero-based index; large preserves 20000. Every requested prime is
consumed and checked against an independent finite Eratosthenes sieve.
The Streams and Sieve sources are compiled in dependency order, rather
than the textual order of the CM project.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10` | `31` |
| normal | `1000` | `7927` |
| large | `20000` | `224743` |

Source inspection suggests sensitivity to streams, higher-order, nonmemoized. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## twenty-four

Enumerate arithmetic-expression solutions using continuation callbacks. See [provenance](twenty-four/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/twenty-four`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ arithmetic-expression solver. Retains its
expression tree and continuation/resume enumeration, including repeated
solutions. Smoke retains the [4,7,8,8] fixture with count 44. Normal
enumerates four distinct cards selected from 1..10, and large retains
250 full deck enumerations. Actual callback counts are accumulated in
IntInf rather than dropped. Reference counts come from the unchanged
upstream solver on MLton; no claim of unique expression deduplication.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `sample 8 1` | `44` |
| normal | `deck 10 1` | `9603` |
| large | `deck 10 250` | `2400750` |

Source inspection suggests sensitivity to symbolic, search, continuations. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## simple

Compute a hydrodynamic time step and check all final state arrays. See [provenance](simple/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/simple.sml`. Original, adaptation patch and notices retained.

SML/NJ hydrodynamics simulation. Every arithmetic routine and the custom
Array2 representation are preserved. Replaces the value-parameter functor
wrapper with a function so grid size is runtime input in SML97; its original
body remains a local declaration block with freshly initialized state.
Smoke uses grid maximum 8, normal preserves 100 and one time step, large
selects 128. Consume all eleven final arrays and both scalar results.
Reference state is the pinned MLton program with a read-only observer;
per-element error bounds are 1e-8 absolute plus 1e-7 relative. The original
100-grid scalar checks (truncated c*10000=6787 and delta=-33093) provide
additional upstream evidence. Validation reads are included in the workload.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1 expected/smoke.txt` | `710` |
| normal | `100 1 expected/normal.txt` | `110006` |
| large | `128 1 expected/large.txt` | `180230` |

Source inspection suggests sensitivity to numerical, arrays, simulation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## nbody

Advance five immutable solar-system records and validate their total energy. See [provenance](nbody/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/nbody`.
Copyright/notice and original ordered sources retained.

2025 Fellowship of SML/NJ solar-system benchmark. Keeps five planets,
immutable planet records/lists, pairwise velocity updates, momentum offset,
dt=.01 and the original numerical operation order. The original driver
offsets momentum before calling run, which offsets it again; this is
preserved. Normal uses one million steps; large preserves fifty million.
Energy references come from the original C implementation in other/main.c
with an explicit second momentum offset to match the SML driver, and
17-digit output; reference.patch records these reference-only changes. Bounds are absolute 1e-9 plus
relative 1e-9; they are not an energy-conservation claim.

The reference offset uses subtraction from the sun velocity before its
second call, matching the immutable SML operation. The original C operation
assigns a velocity assuming an initially resting sun; calling that assignment
twice would reset the sun velocity and produce the wrong reference problem.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 ~0.1690507623824094` | `100` |
| normal | `1000000 ~0.16908618459855648` | `1000000` |
| large | `50000000 ~0.16905990681396785` | `50000000` |

Source inspection suggests sensitivity to numerical, immutable-data, nbody. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## output1

Write individual characters to a regular file and validate every output byte. See [provenance](output1/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/output1.sml`. Original and adaptation patch retained.

The output1 loop still writes one a character per iteration through TextIO.
The Unix /dev/null sink is replaced by a fixed regular file so the SML97
program can consume and validate its actual output. This materially adds
filesystem writes and validation reads; comparisons measure this documented
file-output variant, not the original discard-device timings. Every byte
must be 97 and the observed file length must equal the requested count.
Large preserves one billion writes; it is explicitly selected and creates
a one-GB artifact within the isolated run directory.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1024` | `1024` |
| normal | `1000000` | `1000000` |
| large | `1000000000` | `1000000000` |

Source inspection suggests sensitivity to io, file-output. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## ray

Interpret the original sphere scene and validate its rendered dump image. See [provenance](ray/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ray.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories stack-language ray tracer from the SML/NJ collection.
Retains the original sphere scene, interpreter, camera and shading routines.
The image side is a runtime parameter; normal preserves 512x512, and the
same unit-square sampling convention is retained. Consume the entire dump
image and compare its encoded pixels/header byte-exactly against the pinned
upstream MLton output. This is a zero-error bound in quantized output units,
not a tolerance on unencoded floating-point intermediates. File writes and
validation reads are part of the workload.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 DATA/ray expected/smoke.dump` | `813 4F7643A5` |
| normal | `512 DATA/ray expected/normal.dump` | `786479 5580B075` |
| large | `1024 DATA/ray expected/large.dump` | `3145777 399DC82D` |

Source inspection suggests sensitivity to numerical, rendering, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## raytrace

Render the original chess scene and check every quantized RGB pixel. See [provenance](raytrace/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/raytrace.sml`. Original, adaptation patch and notices retained.

PL Club winning OCaml entry to the 2000 ICFP programming contest, translated
by Stephen Weeks on 2000-10-11. Retains the language evaluator, CSG objects,
lighting, camera, intersections and shader. Keeps the original chess scene;
only its final render dimensions vary: 16x12 smoke, original 400x300 normal,
800x600 large. The original driver swallowed all exceptions; this driver
propagates them and consumes the full PPM image. Output is checked at every RGB pixel after 8-bit quantization against
two reviewed upstream images (MLton and SML/NJ), with at most two intensity
levels of error per channel. Headers and image dimensions remain exact. File I/O is included.

The smoke pixel (12,6) exposes a measured numerical discontinuity: on
MLton its reflected ray has no intersection, while SML/NJ reports an interval
with both endpoints 0.04810688415066595. The original filter tests only
its starting distance, so this zero-width interval changes the reflected
color. The initial hit endpoints differ by less than 1e-15. The original
kernel remains unchanged; each pixel must match one of the two original
program outputs within two 8-bit levels per channel. This is a specified
reference-set bound, not a claim that arbitrary large color errors are
acceptable. Other large reference differences are recorded as hypotheses
of the same discontinuity until individually traced.

The chess input credits Leif Kornstaedt, copyright 2000, revision 1.6.
Its notice is retained in the pristine input. Reference images are generated
from that input by the pinned SML translation on the recorded host versions.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.gml expected/smoke.ppm expected/smoke-smlnj.ppm` | `192` |
| normal | `DATA/normal.gml expected/normal.ppm expected/normal-smlnj.ppm` | `120000` |
| large | `DATA/large.gml expected/large.ppm expected/large-smlnj.ppm` | `480000` |

Source inspection suggests sensitivity to numerical, rendering, interpreter, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## vliw

Schedule and compress instructions, then validate both assembly streams. See [provenance](vliw/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/vliw.sml`. Original, adaptation patch and notices retained.

SML/NJ VLIW instruction scheduling/compression workload. Retains ndotprod.s,
instruction parsing, dependency graph, delay handling, compression and output
formats. Reset name allocation and idempotency as the original driver does.
Normal preserves window size 9; smoke selects 3; large repeats window 9 ten times. Consume and
check every instruction token in both assembly outputs. Fixed relative
filenames remove directory identities from output; generated artifacts are
reference fixtures from the pinned original program on MLton.

The initial window-20 large trial raises FILTERSUCC in the upstream code.
That trial is recorded as a failure; it does not define a golden result.
The selected large profile repeats the validated original window-9 workload,
regenerating and validating both outputs on every call.

Real.toString formats integral real literals as 3 on MLton and 3.0 on
Poly/ML. The checker preserves the output and compares GETREAL values by
finite binary64 value and sign, normalizing their mantissa/exponent only for
the digest. Every other instruction token and line remains exact.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `3 1 expected/smoke.tmp.s expected/smoke.cmp.s` | `458 5C980444;405 9DAD17EC` |
| normal | `9 1 expected/normal.tmp.s expected/normal.cmp.s` | `458 5C980444;398 EA74477B` |
| large | `9 10 expected/large.tmp.s expected/large.cmp.s` | `458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B` |

Source inspection suggests sensitivity to compiler-application, graphs, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fxp

Parse deterministic generated XML and validate its complete tag and attribute counts. See [provenance](fxp/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fxp.sml`. Original, adaptation patch and notices retained.

Andreas Neumann fxp 1.4.4, in MLton's generated 2001 monolith. The source
version constant is retained; the source identity is the pinned MLton file.
[The archived project documentation](https://www.informatik.uni-bremen.de/cofi/CASL-CD/Tools/Cats/src/fxp/doc/)
identifies authorship. Its separate copyright/download links return 404;
the monolith carries no individual notice. The MLton project notice is
retained; recovering the original individual notice remains a provenance
check, not a claim that the aggregate notice describes every component.

Retains the null XML parser, symbol tables, Unicode handling and resolver.
Legacy Timer, vector/array iteration and Substring.all are adapted to the
current SML97 Basis. Iterators preserve absolute indices. No remote URI or
DTD retrieval is used. Explicitly disable validation for the generated
DTD-free document, fail on parser errors and consume start/end/attribute
event counts. Input generation and these additional hooks are part of the
measured workload.

A new portable SML recipe uses the old external helper's word/tag vocabulary
and depth/length distributions, with seed 12345 and exact Word32 ANSI-LCG
arithmetic modulo 2^31. It ensures unique attributes and correctly nested
children. The old awk helper used rounded floating arithmetic, could emit
duplicate attributes, and printed nested calls separately; these bytes and
old count baselines are not reused. Profiles select target payload byte
limits 8192, 1200000 and 4800000, permitting a final-element overshoot.

The URI retrieval helper checks OS.Process.isSuccess instead of comparing
opaque status values for equality, matching the current Basis contract.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8192` | `79 79 131` |
| normal | `1200000` | `11362 11362 17000` |
| large | `4800000` | `45290 45290 67933` |

Source inspection suggests sensitivity to parser-application, unicode, generated-input. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## model-elimination

Search the original first-order problem sets with deterministic inference budgets. See [provenance](model-elimination/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/model-elimination.sml`. Original, adaptation patch and notices retained.

Joe Hurd's September 2002 model-elimination benchmark, using the embedded
Metis code and original first-order problem sets. Preserves meson settings,
problem pruning, CNF normalization choices, clause machinery and scheduling.
Select a prefix of the original problem order and impose the existing
inference meter instead of a CPU-time limit. The count-reference Timer
adapter advances by 100 microseconds per observation and is reset per run;
scheduler readings are deterministic. Slice and overall limits are inference
counts. This stopping/scheduling adaptation is explicit, not a clock claim.
Consume each actual prover result as name/proved-or-unknown; a returned proof
must have an empty clause. Runtime exceptions propagate. Unknown under a
work limit is distinguished from a proved theorem in the result trace.
Reference traces come from the pinned SML program with these documented
work limits on MLton, and are reviewed problem by problem.

Suppress diagnostic printing while retaining the result trace. Smoke stops
P26 as unknown under 1000 inferences. Normal proves nine of the fourteen
selected problems under 50000; large proves all fourteen under 200000.
The three reviewed name/status traces accompany the expected digests.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1 1000` | `12 A7A12B55` |
| normal | `14 50000` | `211 10CC61C0` |
| large | `14 200000` | `206 D43957EC` |

Source inspection suggests sensitivity to symbolic, proof-search, work-limit. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## sat

Solve a fixed Boolean formula with nested higher-order choices. See [provenance](sat/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/sat/main.sml.
Copyright 2025 Fellowship of SML/NJ; notice and original retained.

Preserves the nine-clause formula, ten nested higher-order Boolean choices,
true-before-false search order and first-satisfying-assignment stopping.
Removes candidate logging and consumes every returned Boolean. An independent
1024-assignment truth table finds 80 satisfying assignments,
including the three unused variables. Normal repeats 10000 solves; large
retains the original million. Allocation, closures and short-circuiting are
diagnostic hypotheses, not measured findings.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10000` | `10000` |
| large | `1000000` | `1000000` |

Source inspection suggests sensitivity to symbolic, search, higher-order. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## boyer-smlnj

Prove the original theorem using the modern modular SML/NJ rewriting checker. See [provenance](boyer-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/boyer.
Ordered original sources, notice and adaptation patch retained.

Modern modular SML/NJ tautology checker. Keeps the four-module property
list, rewrite rules, substitution and original theorem. Every actual result
must be true, as upstream testit requires. Large preserves 1300 repetitions.
Only the String.concatWithMap presentation extension is replaced by the
SML97 map/concatWith composition. This source organization and newer rules
remain distinct from the old MLton monolith until a full equivalence audit.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `100` | `100` |
| large | `1300` | `1300` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## logic-smlnj

Find a peg-solitaire solution through the modern modular unifier and trail. See [provenance](logic-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/logic.
Ordered original sources, notice and adaptation patch retained.

Modern modular peg-solitaire unification/backtracking workload. Retains
Term, Trail, Unify and Data source order, first-success continuation and
original board. Normal preserves sixty solves. A normal return without
reaching the success continuation fails; the actual success count is
consumed. Separate from MLton's concatenated earlier variant.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `60` | `60` |
| large | `600` | `600` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## life-smlnj

Repeat fifty-generation glider-gun evolutions with complete coordinate checks. See [provenance](life-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/life.
Ordered original sources, notice and adaptation patch retained.

Modern list-based Game of Life variant. Retains the sorted generations,
neighborhood merge and glider-gun seed. Observe every live coordinate and
return count/hash for every invocation. Normal performs 100 fifty-generation
calls; large preserves the original 1000 calls. Independent Python set-based
neighbor counting supplies the exact generation summaries. The repetition
policy differs materially from the long single evolution in MLton life.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 1` | `61 3AA2F3FF` |
| normal | `50 100` | `54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3` |
| large | `50 1000` | `54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## minimax

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/minimax.
Copyright 2025 Fellowship of SML/NJ; source and notice retained.

Retains the complete tic-tac-toe rose tree and the separate transposition-table
version with 59049 slots. Each call builds both as upstream. Traverse every
returned node, consuming node count, maximum depth and root score. An
independent exhaustive Python search in `oracle.py` gives a draw (score zero)
and confirms both tree-size/depth fixtures from upstream testit. Normal uses
two calls; large preserves ten. Smoke has recorded 120-second and 2-GiB overrides
because even one call constructs the complete game tree. The 1-GiB
smoke run passed the three reference hosts but Rune reported out of memory;
the larger quota preserves the complete allocation workload.
No cache is reused between separate transposition-table constructions.

Replace the SML/NJ extension `Option.isNone` with `not o Option.isSome`.
The ordinary option list representation, move order and scoring are unchanged.
The read-only traversal is additional measured work; both root scores must
be zero before the six-integer summary reaches the suite's exact checker.
The full tree versus cache-pruned tree distinguishes allocation and lookup
costs. These are source-based hypotheses, not measured explanations.

Profiles repeat both constructions 1, 2 and 10 times for smoke, normal and large.

## iter-pidigits

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`,
`programs/iter-pidigits/pi-digits.sml` and `main.sml`.
Copyright 2026 The Fellowship of SML/NJ; notice and pristine sources retained.
The upstream README identifies the Benchmarks Game C version (retained in
the pinned tree at `other/pidigits.c`) and Jeremy Gibbons's
[Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf), section 5.

This is an iterative IntInf spigot, distinct from the lazy stream and
zero-count stopping condition of `pidigits`. Keep its arithmetic, column
counter and termination. Capture each emitted digit, omit the human-readable
column labels, then validate every digit against an independently calculated
Chudnovsky fixture (`oracle.py`). Smoke retains upstream's 30-digit check;
normal selects 100 digits; large preserves upstream's 2000. The original
2000- and 500-digit normal runs passed the reference hosts but timed out after 600
seconds on Rune. Moving that input to the 3600-second large profile preserves
the algorithm and stopping condition without changing its arithmetic. There are no external
datasets or random seeds. Arbitrary-precision division and multiplication
and iterative control flow are source-based diagnostic hypotheses.

## mazefun

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mazefun/main.sml`.
Copyright 2024 The Fellowship of SML/NJ; notice and pristine source retained.
Marc Feeley's Larceny Scheme maze generator was ported by Kavon Farvardin
for Manticore. Upstream calls the benchmark `mazefn`; the directory and
established Scheme name are `mazefun`. Record `mazefn` as an alias.

Preserve persistent list matrices, recursive cavity relabeling, hole order,
and the integer generator `(seed*3581+12751) mod 131072`, seeded at zero for
each shuffle. Rename the module to expose `makeMaze` to a portable driver.
Flatten the complete rendered matrix into one line with slash row separators
and compare every character; suppress direct logging. Repetitions check
each regenerated maze against the first. Smoke is the 11-by-11 maze printed
in the upstream comment; normal uses 100 repetitions of its 15-by-15 maze;
large retains the original 10000 repetitions. Each consumes its result.

Independent fixtures come from the union-find Python oracle, whose different
representation also verifies a connected, acyclic maze. The 11-by-11 fixture
was reviewed against the source comment. No external dataset is required.
Persistent updates, flood-fill recursion and intermediate lists are
diagnostic hypotheses from source inspection. No performance finding is
claimed. The Larceny/R6RS family remains a coverage candidate in the
[literature review](../literature.md); this port records that overlap.

See [retained source and patch](mazefun/) and the
[executable independent oracle](mazefun/oracle.py).

## queens-lazy

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source says it was taken from the LML distribution. Individual author
and notice are not stated in this file; `NOTICE` records that outstanding
lookup rather than assigning another collection's license. Original source,
Makefile and fast/normal/slow fixtures are retained.

Enumerate placements by levels: each prior board precedes columns 1 through
n, with the original short-circuit row/diagonal safety test. The Haskell
list comprehension is translated into memoized stream tails in
`shared/queens.sml`; pending functions are released after forcing. Exceptions
are memoized and recursive forcing is detected by `shared/lazy.sml`. The
outer count forces the complete solution stream; board suffixes remain
shared. No complete solution list is retained by the counter. Integer values
and counts fit a signed 31-bit integer for selected profiles; repetition
totals use IntInf. There are no external inputs or random choices.

Smoke counts size 4 (2); normal counts size 10 (724); large counts size 12
(14200), preserving upstream's fast input. Upstream normal/slow sizes 13/14
and their 73712/365596 fixtures remain recorded rather than being silently
replaced. The unchanged Haskell original compiled with GHC agrees on all
selected sizes. The strict variant uses the same board/safety/order logic
but eagerly constructs levels; different forcing, retention and allocation
justify separate names. Sandmark `nqueens` instead counts depth-first with
mutable sibling counters. These differences are source-based hypotheses;
no measured performance cause is claimed. See
[Partain and the nofib survey](../literature.md).

See [provenance and original files](queens-lazy/PROVENANCE.md).

## queens-strict

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source attributes its origin to the LML distribution; individual author
and license are unstated. Original source/build parameters/fixtures and the
unresolved individual-notice lookup are retained in this directory.

Preserve the board-first list-comprehension order, columns 1 through n,
short-circuit safety test and shared board suffixes. Evaluate the generated
levels eagerly using map, mapPartial and concatenation before taking length.
This deliberately changes Haskell's demand and allocation behavior; the
faithful memoized `queens-lazy` variant remains separately available.
No mutation, randomness, numeric-width substitution or external data is
introduced. Selected counts fit signed 31-bit integers; the outer repetition
total uses IntInf. Newly written SML97 translation lives in
`shared/queens.sml`; the thin named driver consumes its count.

Profiles select sizes 4/10/12 once, yielding 2/724/14200. Size 12 is the
original fast input; upstream's normal 13 (73712) and slow 14 (365596)
are preserved in the retained Makefile/fixtures. GHC's unchanged Haskell
program agrees for selected sizes; semantic tests independently check
both SML variants for every size 1 through 10. Sandmark `nqueens` uses a
different depth-first mutable counter and stays separate. Level retention,
intermediate lists and allocation are hypotheses from source inspection,
not measured causal findings. See [the nofib literature](../literature.md).

See [provenance and original files](queens-strict/PROVENANCE.md).

## nqueens

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-numerical/nqueens.ml`, executable `nqueens.exe`.
No individual author or notice is stated in the file. Sandmark's root
public-domain notice is retained in `LICENSE`; the original file is retained.
This is the sequential executable in a directory also containing a separate
parallel implementation; no Domainslib or multicore facility is needed.

Translate depth-first row search directly, preserving the zero-based column
loop, shared immutable board suffixes, short-circuit conflicts, and mutable
sibling count. Explicit SML tail recursion replaces OCaml's for loop. The
count is consumed rather than formatted as a human-readable sentence.
There are no external inputs or seeds. Selected counters fit signed 31-bit
integers; no OCaml wrapping arithmetic is exercised by these profiles.

Smoke size 4 gives 2, normal size 10 gives 724, and large preserves the
upstream default size 13 giving 73712. All three are in the original source
comment and agree with the unchanged OCaml program. nofib queens counts
the same mathematical solutions through level generation, with distinct
lazy and strict retention; those are different algorithms/workloads, not
duplicates. Search, recursion, board sharing and local mutable counters are
source-based hypotheses. See [the Sandmark literature](../literature.md).

See [provenance and original files](nqueens/PROVENANCE.md).

## rec_seq_ack

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-effects/rec_seq_ack.ml`, executable `rec_seq_ack.exe`.
The file references the Larceny/R6RS benchmarks (spelled Larcenry upstream)
but does not identify an individual author/notice. Sandmark's root
public-domain notice and pristine program are retained. This sequential
member uses no effect handlers; the effect-based executable remains deferred.

Preserve the three-case Ackermann recurrence and nested strict call. Move
launcher defaults into fixed runtime profiles: smoke `(reps,m,n)=(1,3,6)`,
normal `(2,3,8)`, large the original `(2,3,11)`. Consume every repetition
in an IntInf sum rather than discard the upstream accumulator and print only
the final value. This is documented additional checking/allocation work.
The kernel retains ordinary signed integer arithmetic; selected results fit
31 bits. No filesystem data or random input is used.

The formula A(3,n)=2^(n+3)-3 independently gives 509, 2045 and 16381;
summed fixtures are 509, 4090 and 32762. The unchanged OCaml program agrees
with each individual result. Recursive calls and deep stack activity are
source-based diagnostic hypotheses, not measured conclusions. See
[Larceny overlap and the Sandmark literature](../literature.md).

See [provenance and original files](rec_seq_ack/PROVENANCE.md).
