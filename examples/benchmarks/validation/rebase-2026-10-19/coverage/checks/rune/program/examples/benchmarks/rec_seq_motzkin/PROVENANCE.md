# rec_seq_motzkin provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_motzkin.ml`,
executable `rec_seq_motzkin.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Compute Motzkin numbers through repeated unmemoized recursive products.

Preserve the n<=1 base case, recursive motz(n-1), ascending convolution
sum, and repeated recursive products. No memoization or dynamic programming
replaces this intentionally recursive kernel. Smoke/normal select one at 6 and
two at 15; large preserves the original four at 21. All kernel results and original
accumulators fit 31 bits. The SML driver consumes every repetition in an IntInf
sum rather than discarding the original accumulator and printing only the last
value. The combinatorial formula sum_k binomial(n,2k)*Catalan(k) independently
gives 51/310572/142547559, and unchanged OCaml agrees. Summed fixtures are
51/621144/570190236. The source links [OEIS A001006](https://oeis.org/A001006) and describes nonintersecting
chords; those links/wording remain in the pristine source. Repeated calls,
branching and intermediate integer lifetimes are hypotheses until measured.
No universal large SML execution is claimed.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.
