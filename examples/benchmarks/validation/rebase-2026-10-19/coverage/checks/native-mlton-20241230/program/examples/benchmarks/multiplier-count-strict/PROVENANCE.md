# multiplier-count-strict provenance

### Algorithm and workload

Simulate the source binary shift/add multiplier as streams of bit signals.
Preserve combinational gates, balanced wide gates, full-adder carry chains,
word multiplexors, latches, shifting registers and the ready-driven input
interface. Inputs are the infinite pairs (2+3*i,11+2*i), starting at i=1,
truncated to the selected input width. The product register has twice that
width. Do not replace the bit-level circuit with arithmetic multiplication.

### History, authorship and consumers

[John T. O'Donnell's July 1992 multiplier source](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/multiplier/Main.hs), University
of Glasgow, is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. Preserve the
Copyright (c) 1992 header and original Main/Makefile/fixtures under
multiplier-lazy/upstream. No separate individual redistribution grant is stated.
This is a sequential functional stream simulation; no hardware or parallel
runtime is required.

The active go function selects verbose traceMult. Its inactive runMult driver
instead sums the ready signal and prints the count. Preserve that materially
different consumer as multiplier-count-lazy/strict, with a supplementary source
inventory entry. It does not demand the product register/adder; source inspection
and a pending-product test establish that boundary. It is a ready/control-path
workload, not a claim to force the complete product calculation. Generic component
utilities without a selected simulation driver remain in the original snapshot;
they are support code rather than additional executable workloads.

### Evaluation and translation

-lazy preserves the active source lift21: its two input spines are matched but
its output bit is delayed. -strict adds output-head forcing at that binary
combinator, corresponding to the source's commented strict alternative. Both
retain source headstrict on unary and three-/four-input lifting. Truth-table
gates inspect both input bits; AND/OR are not replaced by short-circuit boolean
operators. The source forceBit predicate and strictness points remain explicit.

Use memoized bit and word spines, paired adder outputs and the original mutually
recursive signals. Word combinators delay both tail access and wire arguments;
forcing either while constructing a future word node creates an invalid circular
demand. wideGate's length traverses only outer spines. Carry-chain matching and
zero-width adder base-case demand follow the source. The independent clock model
is a correctness oracle and is not the measured circuit implementation.

Word-to-integer display uses modular Word64 accumulation and signed conversion,
preserving the source's 64-bit Int behavior for long bit vectors. The fixed
input generator, cycle counters and observed register values fit signed 31-bit
integers in the selected profiles. Preserve explicit wire widths even where
leading zeros make the output identical across widths. Numeric validation is
exact; no floating-point tolerance applies.

### Inputs and profiles

| Profile | Input bit width | Clock cycles |
|---|---:|---:|
| Smoke | 32 | 16 |
| Normal | 256 | 2000 |
| Large | 512 | 2000 |

Normal and large retain the original width/cycle parameters. Smoke reduces
FAST's 2000 cycles to sixteen, using its exact header and trace prefix. Every
trace result is compared character by character with the original full output:
1093 bytes for smoke, 132037 for normal/large. The stable report gives width,
cycles and checked characters. Buffer each bounded formatted row before lazy
character assembly, replacing repetitive stdout with exact validation.

Count variants preserve runMult's sum of the first requested ready bits. The
original and independent model give three for smoke and 222 for normal/large.
The report gives width, cycles and that validated sum. The source count consumer's
limited demand is intentional and differs from the full trace contract. The
driver rejects nonpositive widths and bounds selected cycles to 2000, making
the original valid-input precondition explicit rather than entering its empty
wide-gate recursion on zero width.

### Correctness and recorded scope

Unmodified GHC 9.4.7 matches every supplied FAST/NORM/SLOW fixture. Export-only
observers expose complete traces and count results at eight width/cycle choices.
An independent masked shift/add state machine matches all those original outputs,
including small-width truncation and all published 2000-cycle profiles.

The 56-check target covers five small original traces/counts under both policies,
truth tables, unary/binary strictness, non-short-circuit AND, latch delay, lazy
word callbacks/tails, spine-only length, zero-width adder demand, signed 64-bit
wrap, incorrect output, memoization and the count consumer's unforced product.
Native host checks and canonical matrices are recorded separately. Earlier
recursive-forcing failures and snapshots are translation-development evidence,
not compiler bugs. Full normal trace pilots match original text under resource
guards; final canonical source identities remain distinct from older pilots.
Full SML large traces are unrecorded unless explicitly listed in validation.

### Literature and diagnostic questions

[O'Donnell's research bibliography](https://www.dcs.gla.ac.uk/~jtod/research/)
lists Hardware description with recursion equations (1987), providing functional
circuit-simulation context. It is not an exact specification of this benchmark.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite
context. The pinned program defines the actual circuit and strictness points.

Investigate higher-order gate specialization, memoized feedback, bit-stream
allocation, carry propagation, wide-gate traversal and the consumer's forcing.
These are source-based diagnostic questions. Original/model agreement and demand
controls establish recorded behavior; allocation or timing differences alone do
not identify a compiler or collector cause.
