# Rune benchmarks

Portable SML97 benchmark programs, being implemented from the
[roadmap](../../docs/plans/benchmarks.md). The five M1 pilots have fixed smoke,
normal and large profiles and reviewed result checks. The larger source
[inventory](inventory.tsv) schedules future imports; it is not a list of
passing programs. See the [source audit](audit.md) and [literature map](literature.md).

| Name | Source | Description |
|---|---|---|
| [tak](#tak) | Classic SML / MLton | Evaluate the strict Takeuchi recurrence and sum repeated results. |
| [kittmergesort](#kittmergesort) | Classic SML / ML Kit | Sort deterministic integer lists with the region-friendly copying merge. |
| [primes-lazy](#primes-lazy) | nofib | Demand only the required prefix of the finite iterative sieve using memoized tails. |
| [primes-strict](#primes-strict) | nofib | Evaluate each finite sieve list strictly to produce the same prime. |
| [bdd](#bdd) | Sandmark | Construct and check a hidden-weighted-bit binary decision diagram. |

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
`make hosts`. Standalone `xc1` library setup is left to M6. Missing requested
configurations fail visibly; they do not count as passing comparisons.
These commands check correctness. They do not publish timing comparisons.
The timing and count commands in the roadmap are M6 work.

The [manifest](manifest.tsv) records ordered sources, source identity,
profile arguments, expected-result files, limits and diagnostic tags.
The shared SML catalogue validates it before the thin shell runner executes
jobs through the existing matrix. Source inventory metadata is separate
from this runnable catalogue.

Every program reads its benchmark name, space-separated arguments and
expected result as three input lines. The runner supplies a fixed regular
input file and records output under `tests/out/benchmarks/PROFILE/NAME`.
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
