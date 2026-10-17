# Hidden-line application validation

All 32 Rune primary cases pass: two policies, smoke/normal, four engines and
O0/O2. Native MLton, Poly/ML and ML Kit pass all twelve cases at host defaults.
The lazy variant passes both profiles on native 32-bit legacy SML/NJ and 2026.2.
Four legacy 64-bit cases and four strict 32-bit/development cases fail.
The primary ledger therefore retains 48 passes and eight failures.

All fourteen non-SML/NJ auxiliary invocations pass 108 checks. Each of four
32-bit/development SML/NJ invocations passes 53 checks, then fails during strict
command rendering, leaving 55 checks unreached. Each legacy 64-bit invocation
fails its first full-edge check and terminates during rendering, leaving 107
unreached. Totals: 1724 passing assertions, two failed assertions and 434
unreached. The complete 20-invocation ledger distinguishes these outcomes.

The reduced command observer passes four assertions on MLton, Poly/ML and
ML Kit. Each SML/NJ host passes the two lazy checks and the strict internal
accessor, while strict external matching reads corrupted fields. This matches
the already documented PIC constructor pattern. A separate legacy-only nursery
replay fails at 128 KiB and passes at 64 MiB; it is sensitivity evidence, not
proof of the known GC defect's cause. The benchmark keeps its canonical sources
and defaults. No host patch or benchmark workaround is included.

Eight complete normal count samples agree under Rune's execution-model rules,
including allocation across all four engines. Budget files are unchanged.
Four serial single fresh-process native smoke samples validate adapters;
two legacy SML/NJ prechecks reject output and supply no accepted timing sample.
These are adapter diagnostics, not a default-ten-sample performance study.

The unchanged GHC application runs all three scenes 20 times and matches
its entire stderr fixture plus empty stdout. Export-only observers expose
PostScript, rotated vertices and full raw/scaled edges. An independent eager
binary32 model agrees on every observed coordinate word in every scene and
records no subnormal/nonfinite arithmetic. Its one mathematical visibility
cache is reference-only; the benchmark preserves per-bottom memo arrays.

Primary validation checks only rendered x/y and path topology, while respecting
three-dimensional source equality for path continuity. Complete edge/vertex
checks are auxiliary. Decimal formatting, input grammar, output/hash adaptations,
numeric comparison quirks and finite evaluation policies are documented in
the benchmark provenance. Large full-iteration SML validation remains
unrecorded; every large scene has a complete one-iteration geometry check.

Raw initial missing-annotation native compile failures and the initial private
wrong-working-directory failure remain available. Corrected final attempts
are separate. Compiled bytecode, native heaps, object files and executables
are excluded. Source identities, configurations, all count samples and failure
transcripts are retained.

To regenerate the reference programs, place the archived reference scripts
under tests/out/benchmarks/hidden-originals and check out the pinned nofib tree
at tests/out/benchmarks/pinned/nofib. Run reference.py with GHC 9.4.7, then
independent.py. Original data and correspondence are retained in
hidden-lazy/upstream; no separate dataset authorship is inferred.

All 72 inventory regression tests pass. The five clean pinned trees reproduce
861 entries, with the hidden row gaining its reviewed authorship/permission
evidence. The supplementary inventory excludes the historical pseudo-terminal
display wrapper with its identity and concrete reason.

Full make check exits 0 with 1012 catalogue profiles. The linked validation
document retains its complete transcript. M4 remains in progress.
