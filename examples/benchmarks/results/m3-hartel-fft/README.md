# Hartel numerical FFT and FFT source generator

All 112 canonical smoke/normal cases pass: four variants, Rune's four engines
at O0/O2, and six native hosts at compiler defaults. The numerical family's 45
checks and the generator's 39 checks pass in all ten configurations in both
invocations (1680 assertions). Complete coverage, attempt and semantic ledgers
accompany raw results. Native compiler options remain their defaults.

Sixteen normal count samples agree under execution-model rules, including
allocation across all Rune engines. Existing budgets are unchanged. Twelve
serial single fresh-process native smoke samples validate the adapters; they
are diagnostics separate from headline timing comparisons and instrumentation.

Original GHC programs match every byte of all six 360/300-line fixtures.
Complete vectors from both numerical algorithms agree with independent direct
DFTs and a closed-form repeated-ramp spectrum. The exact GHC Complex module
establishes strict fields in both modes; deferred payloads/collections distinguish
the evaluation variants. Source algorithm order, persistent array stages,
association lists and list reordering remain. Additional checks validate complete
array writes and every finite scalar. The numerical bound is benchmark-specific,
with documented reference discrepancies; it rejects errors allowed by the old
0.5 method-comparison tolerance.

All generator source bytes agree with an independent bit-mask/string renderer.
Eight dependency graphs agree with direct DFTs on nonuniform complex inputs
under documented operation meanings. SML checks compare complete source for
maxima 0..8, including EOF and a same-checksum/length transposition. Character
sharing, unused separators and partial glue have dedicated probes. Generation
runs for every iteration; reference text is confined to the checker.

Both normal Rune O2 pilots retain the original 360/300 repetitions. Their
resource guards and preserved artifact hashes are correctness/calibration
records. Smoke reduces only repetitions to one. Large vectors/text have recorded
single-invocation and auxiliary repeat coverage; whole original-repeat large
profile validation is not claimed. Source fixture scripts are preserved as
executed under tests/out/benchmarks/hartel-fft-originals; restore that location
and pinned source trees when regenerating them. Per-program provenance records
all profile, input, library, forcing and output adaptations. M3 remains in progress.

The full repository acceptance check exits 0; its complete transcript is linked
from validation.md. Compiled artifacts are excluded from this archive.
