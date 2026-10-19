# rec_seq_ack provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-effects/rec_seq_ack.ml`, executable `rec_seq_ack.exe`.
The file references the Larceny/R6RS benchmarks (spelled Larcenry upstream)
but does not identify an individual author/notice. Sandmark's root
public-domain notice and pristine program are retained. This sequential
member uses no effect handlers; the effect-based executable remains deferred.

Preserve the three-case Ackermann recurrence and nested strict call. Move
launcher defaults into fixed runtime profiles: smoke `(reps,m,n)=(1,3,6)`,
normal `(2,3,8)`, large the original `(2,3,11)`. Consume every repetition
in an IntInf sum rather than discard the upstream accumulator and print only
the final value. This is documented additional checking/allocation work.
The kernel retains ordinary signed integer arithmetic; selected results fit
31 bits. No filesystem data or random input is used.

The formula A(3,n)=2^(n+3)-3 independently gives 509, 2045 and 16381;
summed fixtures are 509, 4090 and 32762. The unchanged OCaml program agrees
with each individual result. Recursive calls and deep stack activity are
source-based diagnostic hypotheses, not measured conclusions. See
[Larceny overlap and the Sandmark literature](../literature.md).
