# Contrast enhancement validation

Canonical coverage records 27 of 28 passing smoke/normal cases. Every Rune
O0/O2 engine and all six native hosts pass smoke. Normal passes everywhere
except default legacy 64-bit SML/NJ, where the complete pixel checker rejects
an incorrect result. That failure remains in coverage.tsv.

All twenty 98-assertion semantic invocations pass: 1960 assertions, none failed
or unreached. This target includes smoke rasters; it does not replace the
separately failing normal-profile run. Original outputs cover all eight methods
and all selected image profiles. Independent RGB/crop checks and a bit/Murmur
model support input and hash fidelity.

The source thresholds, window boundaries, cache update, memo sharing/clearing,
bright skips and integer truncation remain. Common SML97 word reconstruction
replaces nonuniform optional packer names. Wide squared sums and byte-storage
library costs are explicit. Selected data are ASCII P3 with unchanged RGB
values; original P3/P6 complete-image outputs agree.

Four normal Rune count samples agree, with an uninterrupted zero-exit guard.
Three serial single fresh-process native smoke diagnostics pass. They are
adapter checks, not ten-sample comparative performance claims.

Three separate default legacy normal diagnostics produce two failures and one
pass; three 64 MiB nursery diagnostics pass. This supports a runtime/GC
hypothesis, not a causal reduction, and does not replace the canonical failure.
An initial replay omitted benchmark stdin and is retained as setup evidence
only. Earlier optional-packer compile failures are separate from final tests.

Complete notices, sources, dataset identities, raw outputs and independent
models accompany the evidence. Public Rune O0/O2 semantic targets and the
114-test inventory/five-pin checks pass. Final large SML coverage is unrecorded.
The full repository acceptance run exits zero with 1325 profiles and all
compiler/runedoc/runeopt cross-build comparisons.
