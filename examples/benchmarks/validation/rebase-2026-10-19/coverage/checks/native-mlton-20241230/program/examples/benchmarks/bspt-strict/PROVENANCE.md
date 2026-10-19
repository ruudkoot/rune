# bspt-strict provenance

### Algorithm and workload

Port the complete two-dimensional binary space partitioning modeller: polygon
construction, segment splitting, region classification, area, rendering,
complement and Boolean union/intersection/subtraction. The timed batch builds
and renders the source polygon of sixty vertices from Input.temp0 through temp5.
The other source polygons remain in the upstream snapshot. Interactive commands
are also ported and covered by original output fixtures.

### History, authorship and variants

Source: [nofib real/bspt](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/bspt), pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798. Preserve the nineteen original modules,
including the common NofibUtils source, under bspt-lazy/upstream. No individual
program author or copyright notice is stated in those files; the _YORK module
suffix alone is insufficient attribution. The original emits an MGR command
stream as text; the benchmark does not require an actual graphical display.
The established name is bspt. Explicit -lazy and -strict suffixes distinguish
numeric evaluation policies while retaining common provenance and algorithms.

### Translation and evaluation decisions

The lazy version memoizes rational numeric fields. The strict version computes
those fields eagerly; both retain delayed tree/control structures, character
streams and unused area roots where source demand matters. Preserve recursive
region/face data, partition projections, simplifications and Boolean merges.
Libfuns.par is the local sequential dummy function returning its second argument;
there is no parallel-runtime dependency. Prelude.seq really forces the left
subtree to weak head normal form during tree construction and is preserved.
Tests distinguish that force from an unused right-hand partition calculation.

Rationals use the source signed 64-bit Int semantics, not unbounded mathematical
rational arithmetic. IntInf storage explicitly wraps machine addition,
multiplication and negation modulo 2^64. Preserve floor division, exceptional
minBound operations, gcd simplification and unit-denominator fast paths.
Derived equality is structural, including noncanonical fractions. Ordering uses
the source wrapped cross-products and its Eq/Ord defaults. Source rounding is
floor(x+1/2), with ties toward positive infinity. All numeric checks are exact;
there is no floating-point tolerance or host-dependent default integer width.

GHC's recorded interface identifies Prog.prog1 as an updatable global thunk for
the batch modeller. The SML batch body is likewise memoized globally, including
across repeated Benchmark.run calls in one process. Geometry is computed and
rendered on demand once; subsequent repetitions traverse shared output and copy
the source per-call mouse/screen prefix. Do not interpret 25,000 repetitions as
25,000 independent geometry builds. Preserve command parsing, mouse coordinate
offsets, clipping, formatting and command quirks. Small individual MGR command
strings are materialized before lazy stream assembly; this buffering adaptation
is distinct from the geometric algorithms.

### Inputs and result validation

All profiles read the deterministic source input batch followed by a newline.
Smoke uses one repetition rather than source FAST's 2,500. Normal retains
25,000 repetitions and large retains 125,000. Every result contains 9,761 bytes
and has source modular hash 2674C83CE2E76A07 (decimal 2771059834570107399).
Every repetition checks all characters against the reviewed original batch.render
and computes the original forward Word64 hash. The expected hash is independently
reconstructed by a reverse polynomial calculation. Comparing characters adds
validation work to the source hash consumer; report it as part of this adapter.
The report is repetitions, total characters, final hexadecimal hash. Its total
character counter uses IntInf solely for portable checking: the large total
1,220,125,000 exceeds the maximum signed 31-bit integer.

Unmodified GHC 9.4.7 agrees with every supplied FAST/NORM/SLOW hash fixture;
export-only observers supply complete batch and eleven interactive command
outputs plus rational arithmetic cases. Run sh tests/benchmarks/check-bspt.sh for the 89-check target. It exercises these
outputs, wrapped arithmetic, noncanonical ordering, ties, known areas,
incorrect-result rejection, subtree demand and numeric sharing across calls.
See the validation archive for actual host/configuration outcomes. Full SML
large-profile runs are unrecorded unless explicitly listed there.

### Runtime behavior and literature

Investigate memoization, recursive trees, rational simplification, stream
allocation, sharing across calls and consumer costs. These are hypotheses from
source inspection. Original-output agreement establishes correctness for the
recorded inputs, not a causal explanation of compiler performance. Fresh-process
runs include the initial cached geometry computation. Repeated in-process runs
retain that cache; preserve warmup samples without assuming steady state.

[Fuchs, Kedem and Naylor, On visible surface generation by a priori tree structures](https://doi.org/10.1145/800250.807481)
provides background on partition-tree rendering, not authorship or an exact
algorithmic specification for this two-dimensional modeller.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite
context. The pinned source and recorded GHC interface support the specific
evaluation and sharing explanations above.
