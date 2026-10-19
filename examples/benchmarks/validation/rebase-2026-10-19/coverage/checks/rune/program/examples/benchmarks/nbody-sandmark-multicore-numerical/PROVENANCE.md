# nbody-sandmark-multicore-numerical provenance

## Algorithm and workload

Create randomly distributed mutable bodies, apply the original momentum offset,
compute energy, advance by dt=0.01 and compute final energy. Each advance visits
every ordered i,j pair with i!=j, updating only body i's velocity. Update all
positions in a separate pass after the velocity loops.

This differs from nbody-sandmark's five fixed solar-system bodies and symmetric
i<j pair updates, and from the classic immutable SML/NJ implementation. Preserve
the existing unsuffixed classic name and -sandmark name; the category suffix
disambiguates this additional sequential workload.

## History, sources, authorship and notices

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/multicore-numerical/nbody.ml and its sequential Dune executable.
The header credits Troestler Christophe and Computer Language Benchmarks Game
ancestry. Retain the complete source, Dune file, individual directory revised-BSD
LICENSE (Brent Fulgham/Isaac Gouy), aggregate LICENSE.md and both applicable
run-plan extracts. The directory's parallel executable has a separate deferred
inventory disposition; no domain/parallel support is added here.

The OCaml 4.14.1 Random replacement is shared with the earlier sequential
Sandmark array imports. Its full source, LGPL 2.1/linking-exception notice and pin
99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93 remain beside this import too.
The tested installed reference matches that version. Inputs are generated
internally; no external dataset or unstated seed is introduced.

## Portable translation, evaluation and numerical behavior

Keep seven fields per body, six mutable. SML real refs implement mutable record
fields and a mutable array holds distinct records. Reuse the identical source
energy, momentum and state helpers from the five-body port; its unused fixed
initializer is not called. The ordered-pair advance remains a separate kernel.
Tail-recursive helpers implement inclusive loops. Field arithmetic retains
binary64 operation order; no pair symmetry, vectorization, softening, collision
rule or alternative force algorithm is introduced.

The compiled original evaluates record initializer fields right to left:
mass,vz,vy,vx,z,y,x. Explicit SML bindings preserve that random draw assignment.
The default 55-word generator state is copied per invocation, with every draw
and floating mapping retained. Initial zero-step state fixtures and an independent
generator model check the chosen order. This records the tested OCaml order;
it does not assert that the OCaml language specifies that record evaluation order.

Keep the source's offset denominator solar_mass even though body zero has a
random mass. Consequently, the routine name does not imply zero total momentum.
The random masses, positions and velocities retain their original ranges and
scales. Each run creates fresh body fields and RNG state instead of retaining
a previously advanced top-level array.

The original prints two energies with nine fractional digits. A reference-only
observer changes those two format precisions to 17 significant digits and exports
all seven final fields per body. Its prefix rounds back to the unmodified
original stdout. The SML driver checks both energies and every state field,
rejects nonfinite values and validates exact length before returning
steps:body-count:checked-number-count. Reference parsing and full checking are
measured additions.

## Inputs, result bounds and validation

| Profile | Steps | Bodies | Origin |
|---|---:|---:|---|
| smoke | 1 | 16 | bounded complete simulation |
| normal | 20 | 256 | bounded comparative workload |
| large | 500 | 1024 | unchanged source defaults |

The published run plans also select 512/2048 and 128/8192. These larger
configurations are recorded in provenance but not selected profiles. No claim
is made that every upstream run configuration has been validated in SML.
Default resource limits apply to the three selected profiles.

Each finite number uses absolute bound 1e-9 plus relative bound 1e-11 times
the expected magnitude. These tolerances allow small binary64 differences in
the recorded operation sequence; they are not energy-conservation or physical
accuracy bounds. Every energy, coordinate, velocity and mass is independently
checked. Deliberate changes exceeding the bound in each of the 30 components
of a four-body fixture must be rejected; an interior perturbation is accepted.
Short, extra, NaN and infinite results are rejected.

Original OCaml runs and full-state observers cover small cases, smoke, normal,
source-default large and larger initial arrays. A separate Python binary64
generator/simulator agrees exactly on all checked initial/small/smoke/normal
numbers. It reuses the reviewed default seed words, not the SML update code.
Original large integration has reference evidence; whole large SML validation is
claimed only where separately recorded. Auxiliary tests cover distinct/fresh
body fields, ordered two-body updates, the solar-mass offset quirk and fresh RNG
state.

## Diagnostic questions and references

Source inspection suggests numerical operation lowering, bounds checks, nested
loops, field/ref representation, mutation, random generation and validation
costs as hypotheses to investigate. Compiler comparisons use identical SML.
The original OCaml and independent model are correctness references, not timing
competitors. The retained source and Sandmark survey establish ancestry; the
Barnes-Hut literature describes a different tree approximation and is not used
to explain this all-pairs workload's measured behavior.
