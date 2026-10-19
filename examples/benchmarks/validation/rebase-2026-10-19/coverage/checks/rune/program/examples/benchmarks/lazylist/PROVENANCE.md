# lazylist provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/simple-tests/lazylist.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Preserve add_lazy's unchanged original list parameter: every new delay computes
1 plus the same original zero, not the preceding new head. The strict spine has
length n+1, and only its first delay is forced by each original iteration.
There is no incrementing lazy chain. Preserve inclusive iterations 0..iterations
and create a fresh base/list for each repetition. Unused delays remain unforced.

## Translation, inputs and validation

BenchLazy supplies SML97 memoization. The program additionally walks the
allocated spine before forcing its head, preventing elimination of the workload
when replacing Sys.opaque_identity with consumption. This adds traversal work
and can affect liveness; it does not force the other head delays. Actual lengths
and head values are summed separately. Smoke(length 10,iterations 0), normal
(1000,10000), and large(100000,100) give11:1,10011001:10001 and 10100101:101.
Normal/large preserve original run_config.json configurations; the other
10000/1000 configuration and bytecode settings remain in reviewed extracts.
Original read-only OCaml observers and independent length/head identities agree.
Semantic tests verify pending heads, their independent shared-zero references,
and zero-length extension. Closure capture, memoization, strict spine allocation,
list depth and retention are hypotheses until measured. Large SML execution is
not universally claimed. References: retained source/configs and literature survey.
