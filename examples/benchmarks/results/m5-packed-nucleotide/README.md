# Packed nucleotide keys at two source widths

Recorded 2026-10-16. Both representations pass all 56 smoke/normal combinations
across Rune's four engines at O0/O2 and all six managed native hosts. All 32
semantic/negative checks pass all ten configurations twice, with Rune O0/O2 and
native defaults. Eight normal count samples agree under Rune's execution-model
rules, including allocation across all four engines. Existing budgets are
unchanged; these new profiles are unbudgeted. Six serial native smoke samples
validate MLton, SML/NJ and Poly/ML adapters. Counts and one-sample diagnostics
remain separate from headline timings.

Preserve the omitted last window, cumulative tables and leading-zero aliases
between lengths. The 64-bit representation packs current keys in one Word64; the 32-bit
representation splits the 18-base query after 15 digits and uses its separate
pair-key table. Both run with fixed explicit arithmetic on every host width.
The unmodified 64-bit OCaml program and independent model agree on complete
smoke/normal/large outputs. A parameter-only threshold 15 observer also agrees;
this is not a claim of executing a 32-bit OCaml compiler.

Original fixtures cover input edge behavior and all output bytes. An original
library observer and SML agree on 512 colliding keys through repeated resize,
exact fold order and every smoke pass's table entries/totals. Tests check both
widths, high packed bits, pair hashing, omitted-window bounds, cumulative aliases,
malformed inputs and wrong/truncated/extra output. The initial buffer reservation,
option lookup, tagged keys and sorting replacement are explicit adaptations.
The byte-key counter remains a separate implementation/variant.

The original generator provides fixed input identities; complete large outputs
are reference evidence, with no unrecorded large SML validation claimed. Notices,
source/dependency revisions, models, raw results, identities, all 45 inventory
fixtures and the complete clean 861-entry replay are retained. M5 remains in progress.
