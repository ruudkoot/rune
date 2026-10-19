# map_fold provenance

### Algorithm and workload

Fold keys, values and accumulator over the fixed ten-thousand-entry map.

Retain the source callback argument order and in-order fold; its scalar result is 99990000 on every repetition.

The source OCaml 4.14.1 library uses height-balanced persistent binary trees,
with child heights differing by at most two. Preserve rotations, cached heights,
ordered comparisons, unchanged paths and fold/traversal order. Maps and sets
retain their distinct node payloads, rather than using one map representation
for both.

### History, variants and notices

The benchmark is selector map_fold in [Sandmark's stdlib collection](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib),
pinned at 5605805954a00497ed197c930641cddd580e1507. Its Dune source notes adaptation from OCamlPro's benchmark
repository; no individual benchmark author or separate notice is stated in the
selected .ml/.inc files. Preserve those files and the suite LICENSE.md under
map_iter/upstream. The suite notice and the separate OCaml library grant remain
separate; do not infer identical licensing for the two components.
Other selectors in this executable are separate workloads; they do not become
duplicates merely because they share a library or baseline.

The installed OCaml 4.14.1 map/set source snapshot is pinned independently by
complete-file hashes in map_iter/DEPENDENCIES.json. The library modules credit Xavier
Leroy and INRIA, copyright 1996, and declare LGPL 2.1 with the OCaml linking
exception. Complete selected .ml/.mli files, full LGPL text and the distribution's
full exception text are retained under map_iter/upstream-library. Benchmark and
library authorship are distinct. No external dataset is required.

### Translation and library adapters

Port the active integer library operations in SML97. Invoke one ordered
comparison adapter per visited node; Int.compare replaces the source integer
Ord.compare implementation. Specialized integer keys/values replace the
library's generic types. Higher-order iteration, folding, predicates and
mapping callbacks remain. No compiler/runtime prerequisite is introduced.

The portable code evaluates constructor arguments from left to right.
This can change the allocation order of the two children in a double rotation
relative to OCaml's argument evaluation; exact optimized allocation order is
compiler-dependent. Explicit source let/sequence order remains in map, iter
and fold. Tree-shape agreement establishes structure, rather than identical
allocation lifetimes.

Source physical-equality checks avoid rebuilding unchanged paths. Portable
NONE/SOME change results preserve that decision and sharing; their temporary
option allocation is an explicit representation cost. Do not use structural
tree equality or substitute a different balanced-tree algorithm. Host compilers
may optimize these temporary values differently.

Preserve the map's source tail-recursive ascending association-list generator
and global ten-thousand-entry baseline. The source fields remain global in the
portable map wrapper; a compiler may change retention through whole-program
analysis. Set construction remains inside each run, creating a thousand entries
in descending order. Do not cache a per-run set or a rebuilt map result.

Sys.opaque_identity has no claimed identical SML97 barrier. Add explicit result
consumption, callback checks and full-content checks where the source ignored a
result. This increases validation work; it does not establish identical costs
to OCaml's runtime primitives or optimizer. The common SML sources are the
standard compiler comparison.

### Fixed profiles and result checks

| Profile | Iterations | Published iterations | Expected digest |
|---|---:|---:|---|
| smoke | 1 | 10000 | 5F5B9F0 |
| normal | 1000 | 10000 | 47DE5180 |

The tree sizes remain fixed upstream parameters. Normal iteration counts are
selected explicitly for practical comparative runs, with reductions from the
published run plan shown by the retained source/configuration records. Large
is supplied only for selected selectors and uses the corresponding published
count. Smoke membership cases cross the successful/unsuccessful lookup boundary.
No universal tree-size argument replaces the source's iteration parameter.

Source fold results, keys, values and iteration controls fit signed 31-bit
integers in these profiles. The added aggregate digest uses explicit Word32
modular addition; it is a consumer/check format, not a change to source kernel
arithmetic. Check exact scalar results, expected booleans or full ordered
contents and cardinalities on each relevant result. No floating-point tolerance
is used, and incorrect contents cannot contribute measurements.

Original-library observers agree with independent sorted-map/set models on
78 operation sequences, including complete tree shapes and invariants.
Instrumented source selectors agree with independent digest models at 44
edge-count combinations and all 28 selected profiles. Observer callbacks use
Obj only in the original OCaml reference process; the runnable SML programs
require no FFI or representation inspection.

The broader semantic target checks the recorded shapes, contents, balance,
fold ordering and every selector at boundary counts. A deliberately swapped
pair of map values has the same digest and is rejected by the full checker. Recorded configuration/
profile checks are separate from private pilots. Full final SML large runs
remain unrecorded unless listed explicitly in validation.

### Literature and diagnostic interpretation

The pinned library source establishes this particular balancing, identity and
traversal policy. Sandmark's suite documentation supplies collection context.
These source inspections and original/model observations support the port;
they are not a newly claimed review of a balanced-tree paper.

Investigate comparison specialization, persistent node allocation, cached
heights, duplicate-path reuse, callback specialization, global baseline
retention and the cost of explicit consumers. Treat these as source-based
hypotheses until supported by compiler analysis or measurements. Report fresh
and repeated modes separately and retain all samples and resource failures.
