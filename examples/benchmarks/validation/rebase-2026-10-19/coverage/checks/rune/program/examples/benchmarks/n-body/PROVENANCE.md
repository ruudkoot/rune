# n-body provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/n-body`.

### Algorithm and history

The Computer Language Benchmarks Game implementation is contributed by Olof
Kraigher and Don Stewart. The pinned source retains its compiler pragmas and
historical GCC note. It supplies no individual licence; this gap remains explicit.
The full source and build settings are retained with SHA256 identities.

### Variants and translation

Preserve all 35 Double slots (three position values, three velocity values, one mass for each body),
right-fold momentum initialization, pair visitation, and immediate velocity
updates. Each body's position is updated after its pairs, as in the original.
Energy subtracts pair potentials before adding that body's kinetic energy.
Portable SML arrays replace pointer/malloc storage; checked indexing and tuple
vectors replace unsafe pointer arithmetic and Haskell Vector3 values. The FFI
only supplies storage access here; no foreign computation or runtime facility
is required. All numerical constants, timestep 0.01, and solar-mass formula remain.
The classic nbody uses immutable body records and different update/reduction
structure, so it remains a separate established-name workload.

### Inputs, validation and references

Profiles select 10/10000/500000 steps. Large preserves original FAST 500000;
original NORM 5000000/SLOW 25000000 and optional50000000 remain recorded.
Read-only GHC observers give both energies and all 35 state values at17 digits.
An independent Newtonian pair-force integrator updates all positions after the
pair sweep and checks the complete fixtures. SML accepts only finite values
within absolute 2e-10 plus relative 2e-10 error per value for smoke/normal.
Large uses absolute 2e-8 plus relative 2e-10: the independent integrator differs
from GHC by up to 1.86e-9 after 500000 steps, versus 3.26e-12 after 10000.
Bounds are explicit profile arguments and both reject deliberate perturbations. This bounds differences
in binary64 evaluation while detecting perturbations in energy or individual
state fields; targeted checks reject truncation, nonfinite values and deviations
outside the bound. The chosen bound is tighter than the original nine-decimal
energy output's quantization near zero. Complete-state validation is added work.
Large SML execution is not universally claimed.

Mutable storage, boxing of real tuples, checked access, reduction order and
numerical operations are source-derived diagnostic hypotheses until measured.
References: retained Kraigher/Stewart source and the suite's
[Benchmarks Game literature entry](../literature.md).
