# wave4main-strict provenance

### Algorithm and workload

Evolve the source staggered u/v/height arrays with the original finite-difference
updates, splitting them into two spatial regions and exchanging boundary
columns. Retain all six array domains, U-then-V-then-height dependencies,
physical constants, update parentheses and boundary guards. Do not substitute
the independent unsplit-grid checker for this workload.

### History, names and notices

[nofib Hartel wave4main](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/wave4main)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. The generated module states no individual author or
separate program notice. Preserve complete Main.hs, Makefile, original fixtures
and the parent Fast2haskell shim; collection credits do not establish individual
authorship. No external dataset is required.

The -lazy/-strict names distinguish finite array/cell/triple policy. Both are
sequential computations of this pinned source; the boundary decomposition
does not introduce parallel execution or a runtime prerequisite.

### Translation, numeric semantics and demand

Represent immutable indexed boxed arrays with bounded vectors of delayed
cells. The same SML97 adapter runs on all hosts. Direct vector construction
replaces the shim's Data.Array association-list construction bridge; this
changes temporary builder allocation and is a library replacement. Bounds and
small structural descriptors are strict metadata. Prepend/append retain
original indices and build separate immutable border views at source call
sites.

The lazy policy memoizes outer triples, arrays, rows and real cells. The strict
policy materializes these finite values. Global initial fields are shared;
every requested solution performs fresh step evolution. Keep the U i=0/8 and
V j=0/8 guards before neighbor reads, including for strict data. Source zero
boundaries must not access out-of-range arrays.

Default floating values are binary64 on the configured hosts. Preserve
right-associated Coriolis sums and source multiply/divide grouping. Initial
height remains 3*i/7, depth thirty and the source fixed constants. Selected
indices/counts/checksum totals fit signed 31-bit integers. No substitute
numeric representation or arbitrary-precision kernel is introduced.

### Inputs, profiles and checks

| Profile | Repetitions | Time steps | Source setting |
|---|---:|---:|---|
| Smoke | 1 | 8 | FAST steps, reducing its fixed 500 repetitions. |
| Normal | 500 | 80 | Original normal setting. |
| Large | 500 | 400 | Original slow setting. |

Preserve repetition count and time steps separately, rather than a universal
size. Reference files record exact domains and every final value in all six
arrays, totaling 208 values. Require finite values within 1e-10 absolute plus
1e-10 relative error, then retain the original 1465-character output formatter
and exact source sumcode. The additional full numeric traversal precedes
formatting and adds validation/retention work; the coarse source checksum is
not the sole oracle.

The source five-character formatting, sign handling, rounding and overflow
stars remain. Each repetition verifies a fresh solution and consumes its
formatted result; the driver suppresses repeated stdout and returns checked
repetition/value counts. Argument/reference reads move outside the repetition
loop, replacing repeated getArgs. Host optimization of pure strict computations
is a diagnostic question, not a claimed identical opaque barrier.

Original observers record nine complete states through 400 steps, including
all bounds and source checksums. An independent full-grid implementation,
with no split/halo representation, agrees on all 1872 observed values.
Tests cover full states in both policies, memoized cells, strict materialization,
halo indices, boundary demand, out-of-range access, numerical perturbation/NaN,
corrupt values, zero work and reference-step mismatches.

### Compiler/runtime behavior and recorded validation

Investigate boxed versus specialized cells, delayed history retention, boundary
views, tuple/array materialization, closure specialization, arithmetic and
additional consumers. These are source-based hypotheses, not individual
performance attributions from timing alone.

Private normal pilots retain all 500 repetitions in both policies and match
complete original numerical/format results. The semantic target passes on the
configured engines/hosts; canonical profile outcomes and final large runs
are recorded separately. No new compiler or runtime feature is included.

### Literature and evidence scope

[Hartel and Langendoen (1993)](https://doi.org/10.1145/165180.165230), initial
survey metadata/abstract scope, supplies translated-workload context. The
specific grid scheme, constants, indexing and data dependencies come from
source inspection. The numerical interpretation is source-based, not a
newly claimed review of a hydrodynamics paper. Original and independent
state agreement supports correctness; compiler/collector effects remain
hypotheses pending separate evidence.
