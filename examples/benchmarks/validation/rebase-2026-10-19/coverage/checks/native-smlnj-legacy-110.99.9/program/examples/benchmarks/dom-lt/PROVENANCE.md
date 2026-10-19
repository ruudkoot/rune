# dom-lt provenance

### Algorithm and workload

Compute immediate dominators of rooted flow graphs with the source Lengauer–Tarjan
algorithm: prune unreachable nodes, renumber vertices, build predecessors, perform
DFS, update semidominators, link/compress the balanced ancestor structure and
resolve final dominators. Retain Patricia maps, 64-bit bitmap sets, mutable integer
arrays, persistent environment records and continuation/state callbacks.

### History, authorship and pinned dependencies

[The nofib dom-lt snapshot](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/dom-lt) is revision
b7391df4540ac8b11b35e1b2e2c15819b5171798. Dom.hs credits Matt Morrow, copyright
2009, and declares BSD3, with ancestry in the dom-lt package. Its exact historical
package version is not stated; the pinned module is the program source identity.
The benchmark wrapper's individual author is unstated. Keep original Main,
Dom, Makefile and fixtures under dom-lt/upstream.

The original GHC 9.4.7 environment uses containers 0.6.7. DEPENDENCIES.json pins
its official source archive by URL/version/SHA-256; selected complete original
map/set/bit modules, package metadata and full LICENSE are retained. Their notices
credit Daan Leijen, Andriy Palamarchuk, wren romano, Joachim Breitner, Clark Gaebel
and Johan Tibel as declared in those files. Preserve these individual notices.

The fixed ghc-examples.in contains seventeen real GHC control-flow graphs,
according to the source Makefile. Its producing GHC version/program names and
individual dataset authorship/notice are not supplied. Preserve the original
CRLF bytes and unterminated last line. DATA-IDENTITIES.json records graph/reference
file hashes and lengths.

### Reviewed source repair and portable adaptations

[The source issue](../validation/dom-lt-source-issue.md) proves that the pinned
kernel reuses a stale semidominator threshold and returns wrong parents on
fifteen supplied graphs. Its length-only consumer conceals the error. The port
uses the reviewed minimum-threshold correction; the exact patch, failing original
O0/O2 results and independent model remain. Corrected original and SML results
agree on all 86 checked graphs. The unrepaired source variant is deferred, with
its concrete correctness blocker and refresh condition in source-variants.tsv.

Port the required containers algorithms rather than substituting a balanced-tree
or association-list dictionary. Retain big-endian Patricia branching, strict map
insertion, bitmap-leaf union/difference/filter, signed enumeration and fold order.
Use fixed Word64 masks/leaves on every host. Portable bit-index routines replace
GHC's native bit-scan operations; finite list enumeration is strict in SML.
Original IntSet.fold is foldr; descending callback execution matters to renumbering.

Translate the continuation/state layer with an answer type specialized to this
program's pair-list result, preserving higher-order callbacks and immutable
sixteen-field environment updates. Standard SML mutable arrays replace STUArray
operations. Array.array initializes storage to zero where unsafeNewArray_ leaves
it unspecified; retain all explicit source initialization loops and document that
additional allocator cost. The standard bounds-checked API is used; compilers may eliminate proved checks. A separate semantic
instance tracks source writes and rejects uninitialized reads; instrumentation
is disabled in the measured instance. No compiler/runtime prerequisite is added.

### Inputs, profiles and consumers

| Profile | Source repetition argument | Actual full passes |
|---|---:|---:|
| Smoke | 0 | 1 |
| Normal | 400 | 401 |
| Large | 2000 | 2001 |

The source loops inclusively over 0..argument. Normal and large retain its
parameters; smoke reduces FAST's argument fifty to zero, still processing all
seventeen graphs once. Parse graph data once per Benchmark.run and retain it
through the repetition loop, as in Main. The source subset reader accepts tuple,
list and decimal-integer data with whitespace/CRLF; validate rooted closed graphs.

For each graph and pass, compare every ordered parent pair with the reviewed
corrected-original reference, then retain the source i+length result and final
sum. This adds validation to the length consumer; no explicit result cache is
introduced across passes. Source GHC disables full laziness; there is no claimed
identical portable SML optimization switch. Record compiler options and inspect
optimization effects rather than assume an exact execution count across hosts.

Reported results are 2183 for smoke, 2238783 for normal and 38385183 for large.
They match all source fixtures despite the repaired parent values. Profile graph
labels, indices and sums fit signed 31-bit arithmetic; bitmap semantics remain
explicitly 64-bit. All checking is exact, with no floating-point tolerance.
Full final SML large-profile runs remain unrecorded unless listed in validation.

### Correctness and host findings

The 119-check target covers all 86 ordered graph results with initialized-read
tracking; original containers set/map/fold observations; signed keys, bitmap bit
63, duplicate semantics and noncommutative map union; the three-node threshold
counterexample; same-length wrong-parent rejection; inclusive repetitions;
initialization negative/positive controls; invalid graphs and source checksum.

Private Rune and five native hosts pass every assertion. Native 32-bit SML/NJ
110.99.9 fails because its documented runtime Word64 shift-by-zero operation
produces the wrong bit mask. An isolated unchanged-helper probe reproduces it.
Retain actual failures and reject their measurements; do not hide them by changing
valid arithmetic. Canonical profile/engine results are recorded separately.
The source threshold defect and external host arithmetic defect are distinct.

### Literature and diagnostic interpretation

The source cites [Lengauer and Tarjan's A Fast Algorithm for Finding Dominators in
a Flowgraph](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/a%20fast%20algorithm%20for%20finding.pdf) (1979), Muchnick's Advanced Compiler Design and Implementation (1997)
and Brisk/Sarrafzadeh's 2007 interference-graph work. These are its declared
references, not a claim to have independently reviewed every paper. The pinned
code, minimal counterexample and model comparisons establish this repair's scope.

Investigate Patricia/bitmap operations, DFS, path compression, balanced linking,
CPS specialization, persistent environment updates, array initialization/bounds
and complete-result validation. These are source-based diagnostic questions.
Reference agreement and recorded counts/timings are separate evidence; do not
infer a compiler or collector cause from performance ratios alone.
