# rec_seq_sudan provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_sudan.ml`,
executable `rec_seq_sudan.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Evaluate the Sudan recurrence with explicit wide integer values.

Preserve the order-zero sum, y=0 base case, shared inner result and
nested recursive call. The original OCaml 63 -bit integer result 15569256417
exceeds31 bits. Portable IntInf preserves the selected exact values on every
SML host. This changes representation/allocation relative to OCaml's machine
integers and is explicitly included; it is not an OCaml machine-integer timing
comparison. All supported inputs (order/x/y from 0 to2) and repetition counts
up to10000000 remain within the original 63 -bit result/accumulator range, so
no modular overflow is lost. No broader unbounded OCaml equivalence is claimed.
Smoke selects(1,1,2,2), normal(1000,2,2,2), and large preserves original
(10000000,2,2,2). Every repetition is summed instead of discarding the original
accumulator. The independently derived order-one identity
F(1,x,y)=2^y*(x+2)-y-2 and iterative order-two substitution give12 and 15569256417;
unchanged OCaml agrees with those individual values. Full fixtures are 12,
15569256417000 and 155692564170000000. The source's Sudan-function link is retained.
Wide arithmetic costs, nested calls, shared inner values and repeated execution
are source-derived hypotheses until measured. No universal large execution is claimed.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.
