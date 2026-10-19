# rec_seq_tak provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_tak.ml`,
executable `rec_seq_tak.exe`.

## Algorithm, history and variants

Run the shared strict Takeuchi kernel with Sandmark's curried-source input profiles.

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

The strict Takeuchi recurrence matches the classic kernel. The curried
OCaml calls become tuple calls to shared/tak.sml, already used by classic
and strict nofib ports. No duplicate algorithm implementation is added.
Both source histories and their profiles remain. Smoke/normal use one call
at(18,12,6) and(24,16,8); large preserves original(40,20,11), which differs
from MLton's original(33,22,11). Inputs, intermediate values and accumulators
fit 31 bits. An independent memoized recurrence supplies 7/9/12 while the
benchmark remains unmemoized; unchanged OCaml supplies the same values.
Calls, branching, evaluation order and input-shaped recursion are hypotheses
until measured. Gabriel's recursive-benchmark survey is a family reference,
not attribution of this particular source. Large SML execution is not
universally claimed.
