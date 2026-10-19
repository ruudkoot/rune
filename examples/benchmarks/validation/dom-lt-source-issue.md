# Pinned dom-lt semidominator defect

The unmodified nofib source at b7391df4540ac8b11b35e1b2e2c15819b5171798
returns incorrect immediate-dominator pairs on fifteen of its seventeen supplied
graphs. Its main program reports only the returned list length, so all published
checksum fixtures still pass.

A three-node counterexample is sufficient:

    (0,[(0,[1,2]),(1,[]),(2,[1])])

Both original GHC O0 and O2 return:

    [(0,0),(2,0),(1,2)]

The parent of node 1 must be 0. The path 0 -> 1 bypasses 2, so 2 cannot dominate
1. This is an upstream source error, independently of SML compilers.

Dom.hs reads sdno[w] into sw before looping over predecessors. Each candidate is
compared with that original value; a later larger candidate can overwrite an
earlier minimum. Move that read into the predecessor loop, after eval/sdno of the
candidate, so each comparison uses the current minimum. The exact
[repair](../dom-lt/semidominator-minimum.patch) retains the remaining algorithm,
including bucket processing.

The corrected original returns:

    [(0,0),(2,0),(1,0)]

It agrees with an independent fixed-point dominance model on all 86 checked
graphs: seventeen supplied graphs, five directed examples and 64 deterministic
generated graphs. The SML port agrees with those complete ordered pairs and
checks source initialization before every array read in its semantic target.
These finite checks do not constitute a proof for every graph.

A separate experiment clears processed buckets without fixing the threshold.
It retains all 29 observed mismatches. The suite therefore makes only the
minimum-threshold correction. Original sources, O0/O2 results, all experimental
variants and the independent model remain in the evidence archive.

Original FAST/NORM/SLOW checksums are unchanged by the repair. The benchmark adds
exact parent-pair validation on every pass, preventing the old list-length
consumer from concealing an incorrect result. The unrepaired historical variant
is deferred in the supplementary inventory; no accepted performance measurement
uses its incorrect parent results.

## Separate SML/NJ host issue

The correct portable Word64 helper computes a bit as 1 shifted by its index.
On native 32-bit SML/NJ 110.99.9, a runtime shift by zero produces 100000001 hex,
rather than 1. The isolated probe reproduces the existing
[Word64 shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
Rune and five other native configurations produce 1.

This affects bitmap sets and causes failures on that host. Its 119-check private
run records 39 passes and 80 failures. Keep those results and reject failed
measurements; no benchmark workaround replaces the valid zero shift. The related
[legacy issue 373](https://github.com/smlnj/legacy/issues/373) provides context;
a current issue-status fetch was rate-limited, so no current tracker status is
asserted. This host failure is independent of the upstream threshold defect.
