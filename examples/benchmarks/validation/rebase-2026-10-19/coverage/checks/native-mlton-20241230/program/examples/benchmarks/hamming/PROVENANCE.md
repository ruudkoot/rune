# hamming provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/hamming/hamming.ml` and its dune executable. The individual author
is unspecified. Preserve the original source, build declarations, aggregate
public-domain notice and SHA256 identities. Reviewed run-configuration extracts
include complete source-file identities. There are no upstream datasets.

## Algorithm, history and variants

Keep the mutually recursive shared Hamming stream, its 2/3/5 mapped streams,
nested two-way merge and duplicate elimination. OCaml heads are strict and
list cells/tails use memoized Lazy values. The SML97 BenchLazy adapter keeps
those boundaries and the three root map indirections. A separate fully eager
infinite list would not terminate; it is not a meaningful runnable variant.
This differs from a heap generator or an unbounded mathematical Hamming list.

The original two-component number uses a base of 10^18 and signed Int64
multiplication/addition with wraparound. Preserve both components and every
arithmetic step, using portable IntInf carriers with explicit signed 64-bit
wrapping. Preserve truncating division/remainder, signed component comparison
and the original decimal low-component padding. No reliance on host Int width
or optional Int64 support is introduced. Carrier allocation is an adaptation
and a source-derived performance hypothesis.

## Translation, inputs and validation

The original skips 88,000 values and defaults to 200 outputs. Normal retains
that exact window. Smoke explicitly selects a smaller prefix, skip 100/count 10.
Large retains the bytecode configuration's count 10,000 after skip 88,000;
the native configuration's count 1,000,000 remains recorded as an unselected
upstream parameter. A checked skip argument and full-result fixture replace
stdout-only observation. Results consume every selected value, compare the
complete newline-delimited output and report its actual last value. Checking,
string construction and reference-file acquisition costs are explicit.

Original OCaml agrees with an independent fixed-width cursor implementation
on every value of all three profiles. A separate arbitrary-precision heap
reference agrees with normal, then establishes that the original first diverges
from mathematical Hamming numbers at zero-based index 88,967. Large deliberately
preserves those wrapped source results. The complete large fixture also passes
Rune's stack VM at -O0; broader large SML validation is not claimed.

Eight semantic checks cover carries, overflow, formatting, shared merge prefixes,
memoization, strict mapped heads and unused-tail demand. A direct experiment
with the managed OCaml compiler observes left-to-right scrutinee forcing; the
port follows that observed order. Earlier test attempts had an incorrect order
expectation and are retained separately. Stream retention, map closures and
wide-number representation are hypotheses until measured. References: retained
source, configurations and the Sandmark runtime literature survey.
