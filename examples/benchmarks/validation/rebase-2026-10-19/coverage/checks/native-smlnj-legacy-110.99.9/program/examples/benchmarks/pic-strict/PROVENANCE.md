# pic-strict provenance

Finite evaluation: strict.

## Algorithm and workload

Run the source electrostatic particle-in-cell application on a 16-by-16 toroidal
mesh for ten timesteps. Generate deterministic particle positions, accumulate
their charge at neighboring cells, compute potential and electric fields, push
particles and update the timestep. Repeated runs start with fresh particles.
The primary source consumes only the final timestep through formatting/hash.

## History, authorship, revision and variants

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/pic, all ten
Haskell modules and Makefile. Headers credit Patricia Fasel, Los Alamos National
Laboratory, August 1990. Pic.hs grants public copying/use provided its full
notice and authorship statements are reproduced. Preserve that complete notice
on the translated kernel and independent reference model, and retain all
original files. Data are generated internally; no external particle dataset is
introduced. Preserve the established pic name with explicit evaluation suffixes.

The directory also retains David E. Culler's 1987 Id code, Olaf Lubeck's Id
implementations and two call graphs. These have different array/accumulator
organization and interpolation code, and are not declared duplicates. The
[historical variant inventory](../source-variants.tsv) records their individual dispositions,
authors, source hashes and missing dataflow/setup facilities. Their notices do
not automatically inherit Fasel's Haskell grant. No Id runtime feature is added.

## Source behavior retained

The ACTIVE fineMesh constructs constants: 3 at corners, 4 on horizontal edges,
5 on vertical edges and 6 inside. Its actual interpolation is commented out,
and it never forces the recursive coarse-mesh argument. Retain those constants.

potential calls vCycle rho phi, reversing the names of its first two arguments.
pushParticle returns acceleration/velocity maxima, while timeStep binds them
with swapped names; retain the resulting timestep formula. The top-edge
operator's row-high neighbor is n-2 rather than 1, except at corners. Positions
wrap only once by plus/minus 16. Initial potential uses depth three; timestep
depths cycle through zero, one and two. These are observed source definitions,
not corrections inferred from the physical model.

## Portable translation and evaluation

Immutable meshes use privately constructed SML arrays of memoized numeric cells;
writes stop when construction finishes. Association order, per-particle charge
update order and six-element neighbor LIST arguments remain. Array construction
adds complete/unique-write checks. Position and velocity remain separate finite
lists, with delayed tuple components and shared acceleration/velocity values.
Whole intermediate mesh computations and the coarse solve also remain delayed.

The lazy policy avoids the coarse computation discarded by fineMesh, unused
velocity lists during charge density, and terminal particle lists when only
the timestep is requested. The strict policy eagerly constructs finite cells/
lists and the positive-depth coarse dependency graph. Both retain the depth-zero
and timestep-zero guards before entering further recursion. Infinite recursion
from eager evaluation of an unselected branch is not introduced.

Use binary64 as the source Double requires. Preserve numerical operation order,
indexed stencils, scalar maximum order, truncation and square root. The real-based
genRand formula retains its integer truncate/divide/multiply stage. Selected
seeds stay below 16 and that stage stays below about 504 million, fitting signed
31-bit int; indices, depths and profile counters are also bounded. Explicit
Word64 implements the source 64-bit GHC hash wrapping on every SML host.

The driver reads arguments/reference once, validates each final timestep with
absolute bound 1e-12 plus relative bound 1e-10, and checks finite GEN17 rendering
and exact numerical roundtrip. SML formatting replaces GHC shortest formatting.
The source forward hash is consumed through an independent reverse polynomial
check of the same text; golden GHC/Python hash vectors also test it separately.
A stable particles:checked-runs report omits renderer-dependent hash values.
Numeric/reference I/O, complete hash checking and the added construction checks
are measured costs.

## Inputs, correctness and references

| Profile | Repeated simulations | Particles | Source |
|---|---:|---:|---|
| smoke | 1 | 18 | FAST particle input, fewer repetitions |
| normal | 500 | 80 | unchanged NORM_OPTS |
| large | 1000 | 300 | unchanged SLOW_OPTS |

Original FAST=200/18 remains in Makefile and reference runs. The mesh, ten steps,
depth rules, input formulas and selected normal/large parameters are unchanged.
Default resource limits apply.

All unmodified GHC FAST/NORM/SLOW runs finish with their original empty stdout.
Export-only observers provide timestep prefixes zero through ten and complete
mesh/position/velocity states at particle counts 1,2,3,18,80,300. A separate Python
binary64 model agrees exactly on every recorded number. It uses the constant
fineMesh closed form instead of the unused multigrid dependency graph, providing
an independent calculation of the observable results.

Auxiliary full-state checks use absolute 1e-10 plus relative 1e-10. They add
terminal demand and are separate from the measured timestep-only consumer.
Tests cover every prefix, exact modular hashes, driver rendering, wrong numeric
fixtures, repeat reset, shape errors, source argument/stencil/statistics quirks
and unused coarse/velocity/terminal-list demand. These bounds validate source
results; no physical-accuracy guarantee is claimed.

[Hockney and Eastwood, Computer Simulation Using Particles](https://www.routledge.com/Computer-Simulation-Using-Particles/Eastwood-Hockney/p/book/9780852743928)
provides particle/grid and field-solve context. The pinned program defines the
specific computation checked here; the publication's model properties are not
transferred to its historical quirks. [Partain](https://doi.org/10.1007/978-1-4471-3215-8_17)
supplies nofib context. The publisher description/contents and source form the
recorded review scope.

## Compiler/runtime diagnostic questions

Investigate persistent arrays, indexing, association lists, memoized payloads,
unused coarse work, finite eager construction, higher-order stencil callbacks,
short circuiting, numeric boxing and retained closures. Separate source analysis,
reference agreement and measured sensitivity. Identical SML is the compiler
comparison; Haskell and the independent model supply correctness references.
