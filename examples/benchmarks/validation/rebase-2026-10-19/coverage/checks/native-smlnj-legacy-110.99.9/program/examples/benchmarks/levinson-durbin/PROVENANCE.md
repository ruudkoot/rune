# levinson-durbin provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/numerical-analysis/levinson_durbin.ml, levinson_durbin_dataset.ml
and dune. Retain the directory MIT notice, Copyright 2015 Akinori ABE, and
OCamlPro adaptation credit. The dataset header identifies Japanese vowels
/a/, /i/, /u/, /e/, /o/, sampling rate 16,000, and [its original Tokyo source URL](http://www.gavo.t.u-tokyo.ac.jp/~mine/B3enshu2001/samples.html).
It names no separate recording author or data grant. That exact page could not
be retrieved with the available web tool on 2026-10-16; no grant is inferred
from unrelated current speech pages or the directory's software notice.

## Algorithm and variants

Compute unnormalized, non-circular autocorrelations by sequential products/sums,
then Levinson-Durbin recursion with a fresh coefficient array at every order.
Keep the source accumulator references, update order, reflection coefficient,
old-array reversed coefficient reads and multiplicative variance recurrence.
The wrapper computes autocorr(order+1); its returned coefficient count is
order+1. Preserve that source offset. Lags beyond the signal length are zero.
This is a sequential numerical workload with no meaningful lazy variant.

OCaml float arrays become SML97 RealArray, for loops become explicit tail
loops and mutable scalar accumulators remain refs. No dense solver, FFT
correlation, normalized statistics or in-place coefficient update replaces the
benchmark. Selected indices/counters fit 31 bits; numerical work uses the
supported hosts' binary64 real arithmetic. Array layout/unboxing remains
compiler/runtime dependent.

## Inputs and validation

Smoke order 8 and normal 128 are reduced settings; large preserves default
10,000. The five signals retain all 1,957/3,439/2,644/3,316/2,793 samples.
Every original value is exactly a signed 16-bit integer divided by 32,768;
all 14,149 converted samples have verified identical IEEE64 encodings. Retain
the raw dataset module, headers, conversion script and identities. Loading
portable PCM text adds input parsing. Read-only input arrays initialize on the
first run through a memoized SML delay, keeping file I/O out of host export;
fresh processes load once and repeated calls reuse unchanged inputs. Reference
fixtures are read and checked each invocation. This first-run cost is observable.

Check every coefficient and variance for all five signals. Coefficient bounds
are 2e-9 + 2e-8*abs(reference); variance bounds are 2e-10 +
2e-9*abs(reference). Reject nonfinite values and wrong labels/counts. These
selected-input budgets allow accumulated recurrence rounding; they are not a
general conditioning guarantee. Original outputs are finite at all profiles.
For smoke/normal, an independent 80-digit dense Toeplitz solve and exact integer
correlations agree: maximum coefficient difference about 1.05e-11, variance
1.83e-13. Correlation sums themselves are exact binary64 for these inputs:
integer product sums need fewer than 53 significant bits before scaling by 2^-30.
Large has complete original fixtures; independent dense solving and universal
large SML execution are not claimed.

Semantic checks cover hand-computed covariances, zero lags, first-order/white
processes, fresh-array reflection, the wrapper offset, unchanged input and
perturbed/missing/nonfinite results and tolerance boundaries. The portable
driver consumes all results and prints order:coefficient-count:checked instead
of discarding the original tuples. Validation/input costs are measured work.

## References and diagnostic questions

Levinson's [1946 paper](https://doi.org/10.1002/sapm1946251261) anchors prediction
and Toeplitz recursion. The retained program specifies this particular
unnormalized recurrence, wrapper offset and datasets. Repeated array allocation,
scalar-ref optimization, real boxing, sequential sums, object lifetimes and
conditioning are source-based hypotheses until established by inspection or
measurements. Standard comparisons use identical SML; OCaml and independent
high-precision linear algebra supply correctness references.
