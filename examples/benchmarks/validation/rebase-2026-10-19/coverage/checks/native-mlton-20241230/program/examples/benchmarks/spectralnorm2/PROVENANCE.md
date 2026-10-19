# spectralnorm2 provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
benchmarks/benchmarksgame/spectralnorm2.ml. Header credits Sebastien Loisel,
cleanup by Troestler Christophe and modifications by Mauricio Fernandez, with
the Computer Language Benchmarks Game origin. Retain original header, source,
build/configuration data, the directory Revised BSD notice (Brent Fulgham /
Isaac Gouy), aggregate Unlicense and identities. The exact directory notice
was added during the 2026-10-16 provenance reconciliation.

## Algorithm and variants

Compute the norm by ten power-method cycles, each performing A-transpose-A from
u to v and then v to u. Preserve all forty matrix-vector passes, row/column
order, mutable row accumulators, a newly allocated temporary vector on EVERY
AtA call, and the final vv/vBv accumulation order. Coefficients are recomputed
from their integer formula inside each dot product; no dense coefficient cache
replaces this workload. Arrays start with ones/zeros. Multiplication and
transpose multiplication remain separate functions. Parallel executables have
separate dispositions.

## Portable translation and numerical validation

SML97 loop helpers and generic real arrays replace OCaml loops/specialized float
arrays. Compiler-dependent boxing, bounds checks and temporary liveness are
explicit representation concerns. The largest selected denominator fits signed
31 bits. Real operations retain source order and binary64 host assumptions.
No external dataset or generator is involved.

Smoke 8 and normal 256 are fixed portable profiles; large 5,500 preserves the
published configuration and source fallback 2,000 remains provenance. The original
prints nine decimals. An observer changes only formatting to seventeen digits
for reviewed scalar references. The runtime checker requires finite values and
abs(error)<=2e-12+2e-12*abs(reference), then returns a checked-size marker.
Seven semantic checks include analytic one/two-dimensional cases, exact
coefficients, rejected perturbation and NaN/infinity through the actual checker.

Original bounded OCaml and independent fsum dot products agree on smoke/normal;
original large reference is available. Validation is scalar, matching the source
observation. Large SML execution is claimed only for recorded cases.

## Runtime questions and references

Floating operations, array representation, coefficient conversion/division,
loop specialization and repeated temporary allocation are source-based
hypotheses until measured or established by IR. Original OCaml is a correctness
reference; compiler reports compare identical SML. See the retained Benchmark
Game program, published attribution and shared numerical/measurement survey.

The [official task description](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/spectralnorm.html)
provides algorithm context. Each reference is specific to its finite matrix size;
the tolerance does not assert a fixed error to the infinite-operator norm.
