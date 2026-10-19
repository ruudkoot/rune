# array_fold provenance

## Algorithm and workload

Fold an identity array from left to right with integer addition.

Array generation retains make-zero-array followed by index mapping into a distinct array. The selected arrays are ordinary mutable integer arrays. SML Array.foldl/app and an explicit short-circuit forall loop replace their OCaml counterparts. The original asserts unit for iter/forall; unit is encoded as zero in the report. Every final array element is independently checked.

## History, source and notices

Sandmark 5605805954a00497ed197c930641cddd580e1507, benchmarks/stdlib,
the retained original module and Dune executable. The module states no individual
author or separate notice. Preserve the aggregate LICENSE.md and original bytes.
Names follow the executable's selector strings; distinct selectors remain
distinct workloads. Result-only Sys.opaque_identity wrappers do not require a
new compiler barrier: the portable driver consumes/checks their results. No
claim is made that such wrappers prevent every optimization inside the operation.

## Portable translation and library changes

Kernels, generation and checks are SML97. Inclusive loops become tail-recursive
helpers; all selected indices, loop counts, scalar comparisons and individual
fold results fit signed 31-bit. The observer total may be larger, so the measured
driver uses explicitly modular Word32 addition, with wrapping independent of
native int width. Counters stay bounded and the final expected arithmetic uses
IntInf outside the hot loop.

The common report is calls:hex-checkword:negative:zero:positive. It consumes each
operation result; the checkword is the sum modulo 2^32, not a collision-free
replacement for validation. The array driver also checks every final input value
and the reviewed fold formula. Comparison outcomes have independent closed-form
totals over the selected integer ranges. Reviewed expected reports check all
counters as well as the checkword. These checks add measured work.

The two original comparison lists remain shared constants across loop iterations
and repeated in-process calls. Typed SML adapters replace the OCaml library/runtime calls. This is a common
portable workload across SML compilers, not a measurement of OCaml's generic
runtime dispatch. Source fixture generation uses OCaml 4.14.1. The original
executables emit no text; a reference-only Sys module override records the
strict opaque_identity arguments. Only unit/int/bool results are admitted by
that observer; its Obj inspection is confined to reference generation. Complete
unmodified original runs are checked separately.

## Inputs, correctness and diagnostic questions

The profiles retain the source parameters listed below rather than a universal
size argument. All data are generated from fixed source constants or the identity
array; no external dataset is introduced. Original selector/run-plan parameters
remain in provenance; selected profiles are calibrated portable checks.

Original OCaml observations agree with independently derived result totals.
Auxiliary SML tests cover all three profiles, zero counts, empty/singleton arrays,
short circuiting, source assertions, malformed initialization, list prefixes,
comparison/equality pivots, modular wrap and argument limits. Compilers may
specialize or eliminate invariant pure comparisons; observed result wrappers
do not prohibit that. No replacement opaque-call protocol or runtime feature is
introduced. Interpretation must include the checksum/counter/checker cost.

[The pinned suite](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib)
defines these library microbenchmarks. The shared literature survey supplies
measurement context. Loop lowering, callback specialization, library adapters,
array access, boxing, constant propagation and result-consumption overhead are
source-based diagnostic hypotheses, not established performance causes.

| Profile | Iterations | Array length |
|---|---:|---:|
| smoke | 64 | 16 |
| normal | 10000 | 1000 |
| large | 10000 | 10000 |

Upstream run parameters: array_fold 1000 100000.
