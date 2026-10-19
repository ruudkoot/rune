# rec_seq_evenodd provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_evenodd.ml`,
executable `rec_seq_evenodd.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Mutual tail recursion for parity, with a short-circuit even/odd expression.

Preserve even(0)=true, odd(0)=false, alternating tail calls, and
`even n andalso not(odd n)`. An odd input skips the odd call, as OCaml && does.
The classic MLton even-odd driver evaluates both parity functions to check
agreement, so this evaluation difference remains a separately named workload.
Smoke uses one iteration at 33 (false), normal two at 100000 (true), and large
preserves the original two at 500000000. All inputs/intermediates fit 31 bits.
The result counts true repetitions rather than discarding the upstream OR
accumulator and printing only its last value. Every repetition remains consumed.
Parity modulo 2 independently supplies results0/2/2, and unchanged OCaml agrees
with the individual smoke/normal booleans. No universal large execution is claimed.
Tail-call handling, mutual recursion and short-circuit work are source-derived
performance questions until measured.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.
