# binarytrees5 provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/binarytrees5.ml. The header credits Troestler Christophe
and Fabrice Le Fessant. Retain the complete source, Dune/run configuration,
directory Revised BSD notice (Brent Fulgham / Isaac Gouy) and aggregate Unlicense.
The shared datatype comes from the classic SML/NJ tree benchmark, whose BSD 3-Clause
notice is retained separately. No external dataset is required.

## Algorithm, variants and representation

Construct complete immutable trees with Node(Empty,Empty) at depth 0. Build and
check a stretch tree, retain a long-lived tree, then construct/check many trees
at depths 4,6,... before the final retained-tree check. Preserve both child
allocations, loop bounds, per-tree traversal and mutable checksum accumulators.
OCaml's unused phantom type parameter is omitted. Right-first child construction
and traversal are explicit, preserving the reference native compiler's schedule.

Classic binary-trees uses a leaf shortcut and avoids calls on Empty children.
This variant calls check recursively on both children, including two Empty
visits per leaf. The complete-tree values agree, but the call/branch workload
differs. The datatype is shared; each generator keeps its source evaluation
order. The nofib variant has its own runtime-specific disposition.

## Inputs and output checks

Smoke 6, normal 16 and large 21 use maximum depth, with the original minimum 6
clamp. Large 21 preserves the published run configuration; original fallback 10
remains provenance. The suite requires an explicit valid input and reference
file instead of the original fallback-on-argument-error behavior. Iteration
counts preserve the source left shift, and all selected intermediate counts
fit signed 31 bits. Expected rows follow complete-tree formulas independently
checked against the bounded original OCaml program at all three selected sizes.

The SML kernel keeps the retained tree through its final traversal. The original
module-global tree also remains reachable during final printing; the portable
local result need not stay live after its last check. No GC/keepalive primitive
is added to extend that tail lifetime. Every original output chunk, including
tabs/spaces and final newline, is compared to a reviewed complete fixture.
The driver reads that fixture during execution and returns a checked-depth
marker, replacing original stdout IO with explicit string checking. Those
acquisition/checking costs are part of suite execution.

## References and diagnostic questions

The [official task](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/binarytrees.html)
identifies its GCBench ancestry and the depth-21 performance input. Its allocation
model uses the same node layout for leaves and interior nodes.

The retained Benchmark Game program and shared GC/measurement literature supply
history and context. This tree workload has different lifetimes and observation
rules from GCBench; no historical timing or GC conclusion is transferred.
Eight semantic checks include empty/leaf/asymmetric trees, independent complete
counts, full smoke output, minimum clamping and rejected output/trailer errors.
Large SML execution is claimed only where explicitly recorded.

Recursive calls, leaf handling, constructor layout, traversal order, lifetime
analysis and temporary allocation are source-based questions until supported
by compiler inspection or measurement. Compiler comparisons use identical SML;
OCaml provides correctness references.

[Source program](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/benchmarksgame/binarytrees5.ml).
