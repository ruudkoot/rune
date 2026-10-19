# crout-decomposition provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/crout_decomposition.ml and dune. Retain the directory
MIT license, Copyright 2015 Akinori ABE, OCamlPro adaptation credit and complete
2730-by-18 embedded matrix. The source supplies the table; no external dataset
is acquired. Preserve the established Crout workload name and explain its
actual unit-lower/upper storage convention.

## Algorithm and source limitation

Keep shallow input copying, first-maximum pivot ties, synchronized row swaps,
sequential dot sums, upper/below-diagonal update order, the 1e-6 pivot guard,
right-block processing, explicit L/U construction, dense permutation matrix
and both original dense products. Pivot selection inspects the raw input column,
not an updated Schur-complement column. This is retained source behavior.

The full original recomposition is not equal to its input: maximum residual
is 10452/1195, about 8.746443514644351. Exact rational execution independently
reproduces every original result to less than 1e-15. Its skipped pivot columns
include 3, 5..17; reduced inputs have different pivot selections. A three-by-three
counterexample also demonstrates the raw-column/zero-pivot effect. The port
therefore checks the reviewed source result, not a false LU reconstruction
invariant. This benchmark is not a claim that the implementation is a reliable
general-purpose factorizer. No pivot repair is silently introduced.

## Translation, inputs and validation

OCaml float arrays become RealArray rows with outer Arrays. Preserve mutable
scalar/tuple accumulator refs, shallow row-pointer copies, distinct zero rows,
loops and operation ordering. The dense permutation product is not replaced by
row reindexing in the benchmark. All selected indices/counters fit 31 bits;
measured arithmetic is binary64 on the supported SML hosts.

Smoke 6 and normal 128 select source row prefixes, retaining all 18 columns;
large preserves all 2730 rows. Document this explicit reduced-input adapter.
Read-only source input text initializes on first run through a memoized SML
delay, keeping file I/O out of host export. Repeated calls reuse unchanged input;
new prefix arrays and per-run reference parsing/validation remain measured work.
The original embeds its full table at startup.

Check dimensions, finiteness and every returned element against complete
original fixtures using 2e-9+2e-9*abs(reference). This is a selected-output
rounding budget, not a bound on decomposition error versus the input matrix.
The final line reports rows:columns:checked. Original full-size and adapted prefix executions, plus
full rational comparisons, are retained; universal large SML execution is not claimed.

Semantic checks cover swaps and input preservation, rectangular/right-block
processing, the exact source counterexample, perturbed/nonfinite/wrong-shaped
results and tolerance boundaries. Original full-size residual and exact-source
agreement are recorded distinctly from portable-host validation.

## References and diagnostics

Crout's [1941 paper](https://doi.org/10.1109/T-AIEE.1941.5058258) anchors the
method family; the retained program defines this variant's pivot logic,
unit-lower storage and limitation. Dense permutation construction, row aliasing,
scalar/tuple refs, loop specialization, boxing, locality and pivot branches are
source-based questions until supported by compiler inspection or measurements.
Standard comparisons use identical SML; OCaml and rational arithmetic supply
correctness references for the actual source behavior.
