# quicksort provenance

## Algorithm and workload

In-place Lomuto partitioning uses the last element as pivot, <= comparison,
a mutable partition index and swaps. Preserve the wrapper and recursive worker,
left recursion before right, and the default OCaml random state. This is distinct
from classic list quicksorts and nofib sorting implementations.

## History, sources and variants

Sandmark revision `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-numerical/quicksort.ml` and its sequential dune
executable. The individual program's author is unstated. Retain source, build
manifest, run-configuration extract, aggregate Unlicense text and byte hashes.
The directory also contains parallel/multiprocess programs with their own
inventory dispositions; they are not part of this sequential port. Established
upstream name is preserved; there are no aliases requiring renaming here.

## Portable translation and library changes

Kernels, inputs and checks use SML97. Inclusive for loops become tail-recursive
loop helpers. Array bounds are read at each loop entry rather than all being
cached at function entry; invariant hoisting remains a compiler optimization. Arrays remain mutable; row arrays remain distinct. The random
library replacement follows Damien Doligez/INRIA's OCaml 4.14.1 source at
`99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`, `stdlib/random.ml`; the installed
reference matches it byte for byte. Retain its copyright header and full LGPL
2.1 license with OCaml's linking exception. Word32 expresses the 30-bit masked
additions without overflowing 31-bit SML int; bounded rejection draws retain
the source's state advancement. Fixed states for default, seed 42 and seed 512
are derived with the pinned library and retained derivation code. Precomputing
the two MD5 seed initializations removes that setup cost; per-invocation state
copying and all subsequent random draws remain within the driver. No library
substitution changes the generated inputs. These profiles use only Random.int;
the helper's floating-point draws are separately checked for future users.

## Inputs and correctness

Profiles: smoke 128, normal 100,000, large 4,000,000. Large preserves the published run
configuration 4,000,000; smoke and normal are deliberately smaller portable
correctness/comparison profiles. All seeds, ranges, kernel stopping conditions
and data distributions remain fixed. No external dataset is used.

The original discards its result. The driver consumes every output element,
checks monotone ordering and the complete input multiplicity histogram, then
reports length, arbitrary-precision sum and a 32-bit rolling fingerprint.
Histogram construction and validation are measured additions. Original OCaml
observers produce the reviewed scalar results; independent Python sorting of
the same generated inputs agrees for smoke and normal. Kernel values/indices
fit 31 bits, totals use explicit IntInf, and the fingerprint wraps modulo 2^32.

The reference programs were run with explicit 8 GiB/3,600-second bounds,
including the original large inputs. Large SML coverage is claimed only for
recorded runs, independently of the reference results. Integer checks use
exact equality. Twenty-one shared semantic checks cover 10,000 draws per
seed/mode, rejection behavior, fresh state, perturbed floating-point checks,
sort thresholds/odd sizes, rectangular multiplication and disconnected paths.

## Runtime questions and references

Array bounds checks, loop lowering, mutable accumulator representation, branch
behavior, allocation during validation, and the copied RNG state are diagnostic
hypotheses from source inspection. Compiler comparisons use identical SML
sources; original OCaml results are correctness references. No measured speed
sensitivity is asserted here. See the shared Sandmark and measurement survey,
the retained program, and [the pinned Random implementation](https://github.com/ocaml/ocaml/blob/99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93/stdlib/random.ml).
For literature on the partitioning choice, see Aumüller and Hass,
[*Simple and Fast BlockQuicksort using Lomuto’s Partitioning Scheme*](https://arxiv.org/abs/1810.12047).
Its block algorithms differ from this direct implementation; no performance
claim from that paper is transferred to the port.

The managed 32-bit SML/NJ raises a spurious Overflow in the portable rejection
threshold expression; [the isolated probe and coverage record](../validation/smlnj32-random.md)
distinguish that host failure from the other passing configurations.
