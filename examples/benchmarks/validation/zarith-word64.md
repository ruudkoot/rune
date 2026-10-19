# Zarith numeric boundary probes

Recorded 2026-10-16 with the managed SML/NJ 110.99.9 native32 host. The Zarith
semantic target checks signed Word64 comparison using an XOR sign bias. Its
constant-argument zero versus minus-one case fails on native32 at both requested
levels. The other nine configurations pass all 21 checks at both levels. These
levels affect Rune compilation; native hosts use their normal compiler settings.

An additional runtime-input probe distinguishes constant arithmetic from input
conversion. With input `~1`, `Word64.fromInt` prints `FFFFFFFFFFFFFFFF`, while
the constant expression `Word64.-(0w0,0w1)` prints `FFFFFFFF3FFFFFFF`. The correct
value for both is `FFFFFFFFFFFFFFFF`. Their XOR-biased forms retain that low-half
difference. Direct runtime-bias and direct constant-bias comparisons in this
smaller probe pass, so it does not fully isolate the larger helper's failing
constant comparison. It does establish a host arithmetic discrepancy independent
of the benchmark algorithm and expected results.

The retained [probe source](../results/m5-zarith/reference-observers/native-word-probe.sml)
and [complete host transcript](../results/m5-zarith/reference-observers/native-word-reviewed.log)
record all ten configurations. Nine pass all four probes; native32 fails only
the equality between the constant subtraction and runtime conversion. This is
consistent with the earlier [Word64 diagnostic](word64-host.md) and its linked
compiler report, but no broader root-cause claim is made here.

Selected Fibonacci/Takeuchi profiles use small positive arithmetic; their
profile correctness is recorded separately. No benchmark workaround, changed
expected result, or general certification of native32 Word64 is introduced.
