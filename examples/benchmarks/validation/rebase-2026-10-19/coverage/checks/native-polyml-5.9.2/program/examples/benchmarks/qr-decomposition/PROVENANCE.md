# qr-decomposition provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/qr_decomposition.ml and dune. Retain the directory
MIT license, Copyright 2015 Akinori ABE, OCamlPro adaptation credit and complete
219-by-30 embedded matrix. No external dataset is acquired. The header mentions
Gram-Schmidt; the executed qr function uses explicit Householder matrices.
The established workload name remains qr-decomposition.

## Algorithm and translation

Transpose input into working columns. Build each Householder matrix, update
Q by dense multiplication of copied row suffixes, update later working columns
and extract triangular R. Preserve the first-stage shallow row-pointer blit,
subsequent row slices, original-row snapshots before writes, signed-zero-aware
copysign and source scalar operation order. Keep explicit dense Householder
matrices and the source gemm/axpy loop order; do not replace them by compact
reflectors, Gram-Schmidt or an optimized BLAS routine.

OCaml float arrays become RealArray rows under an outer Array. Array.sub/blit
become explicit fresh slices/pointer copies. Scalar accumulator refs remain
refs; for loops become portable tail loops. These library/representation changes
can affect copying, allocation and unboxing. Selected indices fit 31 bits and
all numerical operations use binary64 on the supported hosts. This strict
source has no separately meaningful lazy variant.

## Inputs, checks and observation

Smoke/normal use the first 5/64 rows and all 30 columns. Large preserves the
complete 219-row source input. Prefix selection is an explicit reduced-input
adapter; it does not synthesize a new matrix distribution. Read-only input text
loads once on the first run through a memoized SML delay, then unchanged rows
are reused across repeated calls. New prefix arrays and reference validation
costs are measured. The original embeds the full array at process startup.

Check Q/R dimensions and finiteness, triangular zeros, every independent
entry of QQ^T against identity with absolute 1e-9, and every reconstruction
entry against input with 1e-9+1e-10*abs(input). Test Q before reconstruction to
avoid extra post-use retention. These selected-input budgets are not a general
rank/conditioning theorem. The repeated columns make the matrix rank deficient;
compare invariants rather than a unique signed Q basis. Original full output
is finite with maximum reconstruction error about 5.18e-13; reduced cases also
pass. Its actual algorithm/result records are retained. The final driver prints
rows:columns:checked. Large SML execution is claimed only where explicitly recorded.

Semantic/negative checks cover rectangular and wide inputs, source signed-zero
behavior, reflection, input preservation, nonorthogonal Q, nontriangular R,
perturbed/nonfinite results and tolerance boundaries. Validation adds a bounded
orthogonality pass and a full result scan to the original computation.

## References and diagnostics

Householder's [1958 paper](https://web.stanford.edu/class/cme324/classics/householder.pdf)
anchors reflection-based triangularization. Source inspection identifies the
particular dense matrices, aliasing and copied suffixes. Dot-product refs,
real boxing, matrix layout, slices, memory locality and Householder allocation
are performance hypotheses until supported by inspection or measurement.
Standard reports compare identical SML; OCaml is a correctness reference.
