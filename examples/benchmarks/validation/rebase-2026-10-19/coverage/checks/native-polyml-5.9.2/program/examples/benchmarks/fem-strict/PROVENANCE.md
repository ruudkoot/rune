# fem-strict provenance

### Algorithm and workload

Perform two-dimensional truss structural analysis: parse model arrays,
assign free degrees, construct the variable-bandwidth diagonal-address vector,
assemble element stiffness/load contributions, compute the recursive LL
factorization and forward/back substitution, recover all nodal displacements
and element forces, then render and hash the report.

Keep the original one-dimensional boxed vector/matrix representation,
association-list accumulation order and skyline/variable-bandwidth indexing.
The routine named beam2d implements axial bar stiffness; preserve its unused
EI parameter and zero rotational entries. No dense pivoted solver replaces
the benchmark's recursive factorization.

### History, authorship, source variants and notices

[nofib real/fem](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/fem)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. README credits Dr. Junxian Liu, Imperial College;
module headers date the vector/matrix and application work to March 1991.
Preserve all eighteen Haskell modules, Makefile, README, MAIL and datasets.
The inspected program/data headings state no separate redistribution grant;
do not infer one from historical correspondence.

The April 1994 correspondence, forwarded by Paul H. J. Kelly, identifies
Glasgow/distr as the properly packaged Haskell version and describes earlier
Miranda/Hope+ origins and incompletely tested compiler-specific directories.
Those historical directories are not additional implementations in this pin.
The -lazy/-strict names distinguish portable finite-array materialization.

Retain the complete inC tree as a historical comparison with fixed mutable
arrays, separate input/output and timing scripts. No maintained nofib target
builds/invokes that C program; its explicit ancillary disposition does not
assign Haskell author credit to uncredited C headers. Generated assembly/C
or runtime-specific facilities are not prerequisites of this Haskell workload.

### Translation and exact numeric decisions

Represent Haskell Float values exactly in SML real while rounding every
source arithmetic operation to binary32, using the existing portable
BenchLinearFloat rounding helper. Keep multiplication/addition grouping,
sqrt/refinement order, signed zero and binary32 bit validation. This is a
numeric-semantics adapter with binary64 storage and explicit rounding cost;
it is not a claim of native binary32 layout or Haskell-equivalent timing.

Preserve the unusual database parser: tokens containing a decimal point are
real fields, other tokens are integer fields; float digits, decimal powers,
division and addition round in source order. Do not replace that parser with
a generic decimal read. Retain its digit fallback behavior. Selected dataset
indices, offsets, counts and report totals fit signed 31-bit integers.

Use bounded immutable boxed arrays/vectors with memoized cells, retaining the
source flattened matrix/list-index builder and ordered accumulating updates.
The lazy policy demands cells as needed; the strict policy forces finite
values after construction. Both retain memoized recursive-array control:
install the vector/matrix knot before materialization, preserving the diagonal
recurrence, LL factor, forward vector and backward vector. Dependencies may
force cells in a different index order. Share the factor and final displacement
vector where the source does, avoiding duplicate solves in the benchmark.

Finite bounds/position metadata uses explicit strict bridges. The common
representation retains memo cells even in the strict policy. Record that
library/layout cost, not an assumed identical source runtime representation.
Unused library exports remain in the retained originals; the portable modules
cover every dependency of the selected Main computation.

The original report uses shortest Float formatting. The portable report uses
nine fixed decimal places through the common SML real formatter, preserving
headings, field order, padding rules and all values. An output-only Haskell
observer applies that same formatting; no numerical kernel changes. Complete
report bytes are validated separately from exact binary32 final values.

Preserve the original post-report hash as explicit modular 64-bit arithmetic,
comparing its Word64 bit pattern on every host. This fixes the tested source
machine-integer width without introducing arbitrary-precision kernel math.
Do not rely on the report hash alone to validate floating values.

### Inputs, profiles and result validation

| Profile | Repetitions | Model |
|---|---:|---|
| Smoke | 1 | Author-supplied data.0, the small two-free-degree model. |
| Normal | 100 | Original fem.stdin, 36 nodes and 62 free degrees. |
| Large | 500 | Original fem.stdin with the source SLOW count. |

Original FAST uses twenty full-model repetitions; smoke deliberately reduces
both repetition count and model size. Normal/large retain source counts and
input. data.3 is byte-identical to fem.stdin; retain both provenance paths.
The other author datasets are covered by broader semantic checks.
No random or external dataset is required.

Each iteration runs the original final-result path once, renders the report,
checks every final displacement/force bit, complete report bytes and 64-bit
hash. Require finite values and zero binary32-ulp deviation from reviewed
original final results. Parse inputs/references outside the loop, replacing
source lazy stdin/getArgs/salt plumbing. No opaque optimization barrier is
assumed. Return validated repetition/report-byte/final-value counts.

Intermediate snapshots belong to separate correctness tests: parsed arrays,
degree maps, diagonal addresses, stiffness, factor, loads, forward/back solve,
full displacement and forces all agree bit for bit across four datasets on
the validated configurations. They are not extra solves in timed workloads.
Original FAST/NORM/SLOW executables fully evaluate their original reports/hash
and print no stdout, as recorded.

An independent binary64 dense assembly and partial-pivot solve, using reviewed
binary32 input data, checks physical assembly, factor residual, free-degree
equilibrium and forces. Its norm bounds are explicit: assembly 2e-6, LL residual
1e-5, solution 1e-12 plus 2e-4 times solution infinity norm, scaled equilibrium
1e-5, and forces 1e-10 plus 1e-5 times force norm. A one-percent solution
perturbation is rejected. These independent-model tolerances do not loosen
the runtime's exact original-bit requirement.

### Compiler/runtime concerns and recorded validation

Investigate binary32 adapter overhead, boxed/lazy array cells, cyclic sharing,
list-index matrix builders, skyline sparsity, strict materialization, closure
specialization and report/validation costs. Treat these as source-based
hypotheses until separate measurements support a narrower explanation.

Direct tests cover complete original states and reports, binary32 ties/
subnormal/overflow/sign cases, recursive arrays in both dependency directions,
band-matrix knots, update order, bounds, overwritten cells, materialization,
zero work and deliberately perturbed values/reports/hashes.

Legacy 64-bit SML/NJ has default-configuration numeric failures. The same
program passes the other managed hosts; repeated legacy defaults vary and
separate 64 MiB nursery diagnostics pass. This is consistent with the existing
GC-root report, not proof of the application's exact cause. Preserve all
failures, standard defaults and expected bits. Diagnostic heap settings are
separate configurations, never substituted for the standard comparison.

Canonical smoke/normal cases, semantic counts, timing/count scopes and full
repository acceptance are recorded in the validation ledger. Native group
labels use host defaults; Rune O0/O2 are explicit. Unrecorded large checks
are not inferred from smaller inputs.

### Literature and evidence scope

[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides application-suite context at the existing survey scope.
The original README and April 1994 MAIL provide program-specific authorship,
model and version history. MAIL names Functional Programming for Finite
Element Analysis and a submitted Functional Programming for Scientific
Computation; these are source-declared historical references, not a claimed
verified journal publication or full paper review.

The stiffness formulas, variable-bandwidth scheme, numeric parser and
dependency/sharing decisions come from source inspection. Original exact
states and the independent dense physical model establish correctness at
recorded inputs; compiler/runtime performance explanations remain hypotheses.
