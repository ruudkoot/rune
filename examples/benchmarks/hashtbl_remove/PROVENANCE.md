# hashtbl_remove provenance

### Algorithm and workload

Build and empty thousand-entry tables in the original rounded-up batch loop.

Preserve source bucket insertion, first-binding replacement/removal, duplicate
entries, three unrolled lookup comparisons, ascending bucket traversal and
growth when binding count exceeds twice the bucket count. Initial capacity is
the power of two at least sixteen and at least the requested size. Resizing
retains bucket-chain order, tail arrays and the traversal-dependent choice
between reusing cells and copying them.

### History, variants and notices

Selector hashtbl_remove is from [Sandmark stdlib](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib),
pinned at 5605805954a00497ed197c930641cddd580e1507. The source notes adaptation from OCamlPro's repository;
no individual benchmark author or separate notice is stated. Preserve the
benchmark, build include and Sandmark Unlicense under hashtbl_iter/upstream.

Pin OCaml 4.14.1 hashtbl.ml/.mli, runtime/hash.c and full LICENSE under
hashtbl_iter/upstream-library, with complete identities in DEPENDENCIES.json.
The selected library/runtime headers credit Xavier Leroy/INRIA, copyright
1996, and declare LGPL 2.1 with the linking exception. hash.c identifies its
MurmurHash3 ancestry. Library/runtime and benchmark notices remain separate.
There is no external dataset.

### Translation and numeric decisions

Use SML97 mutable bucket links, arrays and callbacks. Refs replace inline
mutable OCaml fields, adding allocation/indirection; equal integer keys are
immutable because replacement cannot change an equal integer's value.
Specialize key equality/comparison to integers. Preserve traversal flags and
restore them on exceptions. No FFI or compiler/runtime feature is required.

Generic key hashing retains the exact tagged-integer MurmurHash3 mixing,
tuple header, field order, final avalanche and nonnegative thirty-bit result.
Explicit Word32 operations preserve modular arithmetic. The two known domains
specialize away the generic C runtime object queue, object tags and count/limit
dispatch; no identical generic hashing primitive or runtime overhead is claimed.
The specialized IntHash path uses low key bits at the table mask, preserving
the source key-and-max_int result for these indices. Randomized tables are not
part of this deterministic seed-zero workload.

Only filter_map values use IntInf with explicit signed 63-bit modular doubling,
matching the pinned 64-bit OCaml semantics even on 31-bit SML hosts. This changes
numeric representation and allocation costs; it does not substitute unbounded
mathematical growth for wrapping arithmetic. Other source counters/keys/values
fit signed 31-bit integers in the selected profiles. Added result mixing uses
Word32 independently of source arithmetic.

### Source quirks, inputs and correctness

Main's generic and specialized tables are created empty before dispatch.
The find1/find2 selectors do not invoke their sibling replace closures, so every
lookup misses. Replace closures fill zero through 999 on the first batch and
reuse those tables on subsequent calls. These four selectors and both hash
selectors run outer loops from zero through iterations inclusive: zero still
performs a thousand operations. Other operation loops start at one.

Remove always performs iterations div 1000 + 1 complete build/remove batches.
Filter_map retains a thousand entries; signed overflow and eventual zero
values are part of the source workload. Find crosses the populated 1..1000
range. Duplicate insertion retains both bindings rather than overwriting one.

| Profile | Iterations | Published iterations | Expected count and digest |
|---|---:|---:|---|
| smoke | 0 | 4000000 | 0:50C5D1F |
| normal | 100000 | 4000000 | 100000:8297AA8F |

Profiles select explicit source counts; they do not change the thousand-entry
baselines or use a universal size argument. Normal reductions and selected
large counts are recorded. Full final large SML runs remain unrecorded unless
listed separately in validation.

Full binding multiplicities, values and cardinalities are checked after builds;
lookups, fold scalars and callback counts are checked as consumed. Filter_map
checks every final signed value. Hash consumers use the reviewed original
results and independent modular model. Extra full consumers, reference cells,
domain specialization and absence of an identical Sys.opaque_identity barrier
are explicit adaptations.

### Validation evidence

Original snapshots and independent duplicate-binding models cover 23 update
sequences, including resizing and signed keys. Exact original bucket layouts
before/after filtering and 1005 integer/tuple hash pairs support the port.
Original source observers and independent iteration/binding/modular models
agree on 56 edge-count cases and all 33 selected profiles. Tests cover the
unrolled lookup tail, exact traversal order across callback-triggered resizing,
duplicate removal, exception restoration, corrupted
bindings and both signed63 boundary transitions. The validation ledger separates
private pilots from canonical wrapper checks and resource failures.

### Literature and diagnostic interpretation

Preserved OCaml source establishes these bucket and hash algorithms; its
MurmurHash3 pointer records ancestry rather than a newly claimed paper review.
Independent models and exact source observations support correctness.
Bucket distribution, resize/cell reuse, indirect mutable fields, key/hash
specialization, tagged arithmetic and added consumers are source-based
performance questions. Recorded counts and timings do not isolate their costs.
