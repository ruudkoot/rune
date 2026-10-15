# LU_decomposition provenance

## Algorithm and workload

Unpivoted Gaussian elimination copies a flat row-major real matrix, iterates
k/row/column, caches one multiplier per row, and stores lower multipliers below
the upper factor. Preserve the original packed update order and separate lower
and upper constructions. The source calls this function lup but performs no
row exchanges. Lower has a unit diagonal; upper includes the packed diagonal.

## History, sources and variants

Sandmark revision `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-numerical/LU_decomposition.ml` and its sequential dune
executable. The individual source author is unstated. Original source, build
manifest, published run configuration, aggregate Unlicense and identities are
retained. Parallel executables have separate inventory dispositions. Preserve
the established name; the numerical-analysis collection's Crout program remains
a separate workload, with different storage/computation to audit.

## Portable translation and representation

SML97 loop helpers replace inclusive for loops. Generic real arrays retain flat
row-major indexing; compiler-dependent boxing replaces OCaml's specialized float
array representation. Array.tabulate copies elements; boxed implementations
share immutable real values until replaced. Actual liveness of the original,
packed and expanded factors depends on the compiler/runtime. No pivoting,
conditioning transform or generator substitution changes the original algorithm.

The shared generator follows pinned OCaml 4.14.1 Random at
`99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`. Preserve its modified lagged-Fibonacci
transition, floating draw order and exact default state. Input uses the original
expression Random.float 100.0 + 1.0. The original library source and full LGPL2.1
notice with OCaml linking exception are retained locally. Fixed state setup is
precomputed as documented in the shared array ports; draws occur within run.
All selected sizes and flat indices fit 31 bits; arithmetic values use real.

## Profiles, correctness and numerical bounds

Smoke4, normal256 and large1024. Large preserves the published run configuration;
the source's CLI fallback1200 is retained in provenance and the portable argument
range. Normal is smaller for practical comparisons and larger than the initial
64 pilot, reducing fixture parsing's share of total work. There is no external
dataset: all input matrices derive from the pinned default generator.

The source discards its factors. The portable driver consumes every packed,
lower and upper entry against an original-OCaml fixture, using
`abs(observed-reference) <= 1e-9 + 1e-10*abs(reference)`. Both values and the bound
must be finite. The fixture contains exactly size*size packed values. Streaming
line acquisition avoids whole-file string-size limits. Reference loading and
three complete comparisons are measured driver additions, especially visible
on smaller inputs. A checked size marker is returned only after those checks.

This is a replay tolerance against the original binary64 algorithm, rather than
a forward-error or conditioning guarantee. Independent 60-digit Decimal
elimination and residual reconstruction validate smoke/normal reference factors.
Normal's scaled residual is about 1.50e-16; packed forward discrepancy against
high precision is about 7.52e-10. Residual scaling uses
max(1,abs(A_ij)+sum_k abs(L_ik*U_kj)), with a generous 64*size*2^-52 acquisition
check. That independent accuracy check differs from the runtime replay bound.
Original observers have explicit time/address-space limits and all selected
factor fixtures are finite. Large SML coverage is claimed only for recorded runs.

Fourteen semantic checks cover exact small factors, input preservation, allowed
rounding, rejected absolute/relative perturbations and NaN/infinity. Failed
results cannot contribute measurements. Any host discrepancy is recorded with
its profile/configuration instead of receiving an alternate expected result.

## Runtime questions and literature

Array boxing, bounds checks, index arithmetic, cached multipliers, copied-factor
liveness and checking overhead are source-based diagnostic hypotheses until
measurements or IR inspection establish their effects. Compiler comparisons
use identical SML sources; original OCaml results supply correctness references.

[Higham, What Is an LU Factorization?](https://nhigham.com/2021/04/20/what-is-an-lu-factorization/)
(2021) explains the relationship with Gaussian elimination, loop forms and
leading-principal-minor conditions. This benchmark preserves its row-major
k/i/j order. See the shared Sandmark/measurement survey and retained source.
