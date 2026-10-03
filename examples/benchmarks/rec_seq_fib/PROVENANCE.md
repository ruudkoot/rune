# rec_seq_fib provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_fib.ml`,
executable `rec_seq_fib.exe`.

## Algorithm, history and variants

Compute strict Fibonacci with Sandmark's retained repetition profiles.

The individual author is not stated. The source, dune executable manifest,
and SHA256 identities are retained alongside the aggregate public-domain notice.
This is the sequential member; its effect-based sibling remains inventoried
with effect-handler support as its blocker. SML97 follows left-to-right operand
evaluation instead of OCaml's usual right-to-left evaluation. These kernels are
pure, so values agree while call order/stack behavior can differ. Consumed
runtime arguments/results replace Sys.opaque_identity without adding compiler
features. Every repetition contributes to a checked IntInf sum rather than
discarding the upstream accumulator and printing only its last value.

## Translation, inputs and validation

The 0/1 base cases and binary recurrence match classic MLton fib exactly.
Both named drivers share one implementation in shared/fib.sml. This kernel is
extracted unchanged from the existing classic port; the two upstream sources
and launchers remain available. Smoke/normal use one call at 20 and two at 30;
large preserves original four at 40, versus MLton's original 41. Kernel values
and original accumulators fit 31 bits. Iterative Fibonacci independently gives
6765/832040/102334155; unchanged OCaml agrees with the individual values.
Summed fixtures are 6765/1664080/409336620. Exponential calls, strict operand
order and stack behavior are source-derived questions until measured. See the
classic Fibonacci provenance and the shared literature survey. Large SML
execution is not universally claimed.
