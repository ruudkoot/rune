# stack_push_pop provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/stdlib/stack_bench.ml`. Two modes have different workloads and retain
separate names: stack_fold and stack_push_pop, matching the upstream mode arguments. Preserve the original
source, dune declarations, aggregate notice, configuration extracts and hashes.
The individual benchmark author is unspecified.

The library replacement follows Xavier Leroy's OCaml Stack implementation at
OCaml 4.14.1 commit `99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`,
`stdlib/stack.ml`. The installed reference source matches that pinned file
byte for byte. Preserve its copyright header and LGPL 2.1 notice with the
OCaml linking exception, including the complete original LICENSE text.

## Algorithms and translation

Keep the linked list and cached mutable length. Stack push, pop and fold use
the original order; fold visits the top first. The fold mode pushes integers
1..100 once and repeatedly folds integer addition from zero. The push/pop mode
starts with one unit and repeatedly pushes then pops a unit, retaining length
one. Each mode retains its original positive iteration range and setup.

Portable SML97 uses a datatype record containing two mutable references;
OCaml stores both mutable fields in one record. This changes representation
and setup allocation, while preserving operations and lifetimes. Source
Sys.opaque_identity wraps the consumed fold value; the port consumes/validates
that value directly and accumulates it with IntInf. Push/pop validates the
cached length and consumes the completed operation count. These extra checks
and accumulators are included costs. Fold values and counters fit 31 bits;
IntInf preserves the wide aggregate on every SML host.

## Inputs, results and runtime questions

Smoke selects 100 iterations. Normal preserves the configured 2,500,000 folds
or 100,000,000 push/pop pairs. Large explicitly doubles those counts for scaling.
The modes keep their original list sizes and values. There are no datasets.
Original OCaml observers agree with independent arithmetic: fold totals are
5050 times iterations, with length/top 100; push/pop completes each requested
pair with final length one. Expected results are reviewed from these invariants.

Nine semantic checks cover empty stacks, exceptions, LIFO order, fold order,
unchanged folded stacks, workload results zero iterations and module-specific exception identity. List allocation,
mutable field updates, specialization, loop hoisting and short object lifetimes
are source-derived performance hypotheses until measured. Original and adapted
result consumption and instrumentation are distinguished. Broader large SML
validation is not universally claimed. References: pinned benchmark and OCaml
Stack sources, and the shared Sandmark runtime/measurement bibliography.
