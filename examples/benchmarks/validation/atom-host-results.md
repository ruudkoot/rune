# Atom host results

All Rune engines at O0/O2, MLton, 32-bit SML/NJ 110.99.9, SML/NJ 2026.2,
Poly/ML and ML Kit pass the selected smoke/normal profiles. Legacy 64-bit
SML/NJ 110.99.9 produces incorrect binary32 positions in both policies and
both profiles. The 56-case canonical ledger retains 52 passes and four
incorrect-result outcomes.

The 50-check program has 18 complete passing invocations and two with two
failed checks each (996 passing assertions, four failures). Legacy 64-bit
failures concern the 100-position prefixes; direct ties-to-even, signed-zero,
domain and source-demand probes pass. The [REAL specification](https://smlfamily.github.io/Basis/real.html)
requires ties to even for round and its equivalent toInt TO_NEAREST form.
Those passing probes do not explain the workload failure.

A separate unchanged-kernel trace probe reports first differences. One default
run sees lazy position 44 as 3F24DE6D instead of 3F249351 and strict position 54
as 3EF609F7 instead of 3EF40177. A later default replay sees different indices
and values. The larger-nursery replay passes the auxiliary checks, trace probe
and both smoke cases; both 2500-position normal cases still fail. This establishes
sensitivity to runtime allocation settings, with an unreduced application cause.

The [existing legacy real-root report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md)
and [legacy issue 299](https://github.com/smlnj/legacy/issues/299) are relevant
investigation references. Public issue metadata fetched on 2026-10-17 shows
issue 299 closed on 2026-09-30; the tested host remains the 110.99.9 release. This note does not assign a reduced cause or report
results on an updated compiler. The benchmark retains source arithmetic,
rounding helper and default host options.

The two serial legacy correctness prechecks reject results before sampling.
Four MLton/PolyML fresh diagnostics pass. Count and timing archives retain each
scope; incorrect results cannot supply timing samples. Default failures and
separate @SMLalloc=64m diagnostics remain distinct. Source identities, raw trace
differences and all nursery outcomes accompany the archive.
