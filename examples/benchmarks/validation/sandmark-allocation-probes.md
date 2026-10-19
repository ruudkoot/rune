# Sandmark allocation and stack probe review

Reviewed 2026-10-16 at Sandmark
5605805954a00497ed197c930641cddd580e1507, benchmarks/simple-tests/.
Four additional microbenchmarks depend on an optimization barrier to preserve
the operation they measure. They are deferred under the roadmap's existing
feature policy, alongside the previously reviewed [morestacks](sandmark-opaque-call.md).

| Program | Reviewed modes and operation | Missing portable facility |
|---|---|---|
| alloc | A thousand discarded mutable-record creations per outer iteration. | Opaque application of create prevents removal of its otherwise unused allocation work. |
| lists | Nine integer, real, tuple, string, record and array element modes. | Opaque application of create_list preserves generation of otherwise discarded lists. |
| stacks | Four integer/real and small/large argument modes, each called 5,000 times. | An opaque function preserves repeated calls whose recursive arithmetic results are discarded. |
| stress | Fixed-seed allocation with a configurable retained-reference fraction. | The non-retaining branch forces discarded reference creation through an opaque function. |

The [pinned OCaml interface](https://github.com/ocaml/ocaml/blob/99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93/stdlib/sys.mli)
defines Sys.opaque_identity with the compiler's %opaque primitive. Retained
OCaml 4.14.1 Cmm shows opaque function values and indirect calls in
[each reviewed program](../../../../rune-benchmark-results/m5-allocation-audit/). The scripts compile
these sources for inspection without executing their large default loops.
Complete original source bytes, aggregate Unlicense and source digests are
retained as classification fixtures; individual authorship/grants are unstated.

Checking a pure result can keep algorithmic work observable, but it cannot
guarantee a particular call or allocation remains after optimization. Adding
checksums, OS effects or a new compiler primitive would change these specific
microprobes' protocol. This review adds no prerequisite compiler/runtime feature.
Reconsider a reviewed portable barrier protocol or an upstream workload with
observable algorithmic results that preserves the intended measurement.

Each disposition is guarded by its exact program path and source SHA256.
Changed sources and unreviewed paths require fresh review. Opaque wrappers on
algorithmic programs remain individually reviewed. Three new tests exercise
the four reviewed probes, changed-source reconsideration and path scoping;
all 41 inventory tests, including twelve new subcases, pass.

The audit rebuilt all 143 Sandmark entries and reconciled all 861 inventory
entries. Only these four dispositions/reasons changed; every other field,
source identity and alias order is preserved. Sandmark now has 61 scheduled
imports and 82 deferrals. Deferred probes remain outside runnable directories.
