# fannkuchredux provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/fannkuchredux.ml. Paolo Ribeca's August 2011 header
credits Oleg Mazurov's Java version. Retain the source/build data, directory
Revised BSD notice (Brent Fulgham / Isaac Gouy), aggregate Unlicense and identities.
The original workers 32 are sequential chunks, not threads. No external dataset
or new parallel/runtime feature is required. The nofib Foreign/forkIO program
is a separate deferred implementation.

## Algorithm and known variants

Preserve factorial unranking, three mutable permutation/scratch/counter arrays,
all 32 chunks, absolute-index checksum signs, source middle-only flip counting,
next-permutation carries and the complete progress-digit/output stream.
The classic SML/NJ fannkuch implementation has a different generator/counter and
full-prefix reversal routine; it supplies an independent correctness reference,
not a shared implementation of this optimized kernel.

The source count convention returns 1 for zero-first permutations. Keep that
convention, including its skipped scratch copy, instead of changing it to the
usual zero-flip definition. Full checksums/maxima agree with the independent
standard implementation at every selected size; the source-specific convention
is separately covered by semantic checks.

## Reviewed terminal-boundary repair

The Dune executable explicitly uses -unsafe -noassert. On valid input 3, the
checked original exits 2 with index-out-of-bounds after printing 012345. A small
export-only observer locates the terminal carry's read of c[length]. That
transition occurs after the final permutation and its successor state is unused.
The -unsafe original happens to finish at that size, but its invalid read/write
is not portable semantics or a correctness oracle.

The port adds one reviewed guard: update the counter only while i<length,
otherwise end the carry. It preserves the preceding terminal p-array mutations
and every next call, including the final one. The post-terminal array is not a
valid next permutation and is never consumed. The exact repair diff and original
checked/unsafe evidence are retained. A corrected checked OCaml reference and
an independent managed-MLton implementation agree through n=12, including full
original text and all 32 chunk partitions. No unsafe-array primitive is added.

## Numeric and library translation

The source eagerly constructs factorials 0..20, which fit its signed 63-bit int.
The portable table uses IntInf, preserving even the unused larger entries.
Only entries through 12 are converted to default int. Main permutation/index and
per-chunk checksum operations remain default int: at n=12 the observed maximum 65
and chunk length 14,968,800 bound every partial chunk sum by 972,972,000, within
signed 31 bits. The reference records every chunk and final-aggregation prefix.
The cold 32-chunk aggregation uses IntInf explicitly; selected source values
cannot overflow 63 bits. This does not move arbitrary precision into flip loops.

Partial Array.blit uses an indexed copy of exactly the source prefix; the
arrays are distinct. Record layout, bounds checks and generic array/IntInf
representations depend on the SML compiler. Explicit loops/refs preserve mutation
and array access order, including the source native compiler's right-first
allocation order where relevant. These are recorded translation costs.

## Profiles, validation and references

The [official task](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/fannkuchredux.html)
describes permutation order, checksum signs and size 12. Its historical Lisp
reference is listed in the shared bibliography; the port's correctness evidence
comes from retained programs and the independent reference implementation.

Smoke 5, normal 9 and large 12 preserve permutation size as the parameter. Large 12
is the published input; source fallback 7 remains provenance. The suite requires
an explicit validated input and reference file. It compares every generated
progress/output chunk to a complete reviewed fixture and returns a checked-size
marker. Fixture acquisition and checking replace original stdout IO and are
included in execution. Original selected arithmetic is explicit; arbitrary
other CLI inputs are not certified by these profile references.

Ten semantic checks cover factorial 20, factoradic order, the zero-first
convention, terminal carry, empty chunks, all 32 partitions, exact small output
and rejected perturbations/trailers. Original/repaired source identities, compiler
options, whole outputs, chunk bounds and the independent MLton oracle are retained.
Large SML execution is claimed only where explicitly recorded.

The retained Benchmark Game source supplies benchmark-specific history; see the
shared compiler/measurement survey. Specialized array operations, bounds checks,
ref unboxing, permutation/flip control flow and cold arbitrary-precision setup
are source-based questions until established by measurement or compiler inspection.
Performance comparisons use identical SML; corrected OCaml/independent SML are
correctness references, with the repair clearly distinguished from upstream.

[Source program](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/benchmarksgame/fannkuchredux.ml).
