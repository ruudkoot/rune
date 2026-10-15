# Banner glyph pictures

Recorded 2026-10-16. [All 56 smoke/normal cases](correctness.tsv) pass on four
Rune engines at both levels and all six managed SML hosts. Twelve semantic
checks pass all ten configurations at both levels. All eight normal count
samples pass; allocation and applicable instruction comparisons agree.

The source's glyphs, case mapping, list indexing, punctuation lookup, transpose,
joining and line ordering remain intact. Need retains the shared cyclic infinite
empty-row fallback; eager evaluation of that unselected branch cannot terminate.
All fixed profiles use finite ASCII glyphs. Tests confirm the lazy productive
newline prefix, knot sharing and full glyph/whitespace output against GHC.

Profiles supply original templates and boot repetition counts, generating exact
logical input in portable SML during measurement. That input-generation/IO
adaptation is explicit. Byte-by-byte comparison and Word32 fingerprinting consume
all output. Logical expanded input/output identities are recorded, with complete
original-GHC smoke/FAST/normal/large runs and independent renderer checks.
Normal retains 35,000 repetitions (40,145,000 output bytes); large retains 180,000
(206,460,000 bytes). Small smoke uses2. Large SML execution is not universally
claimed. Source/input/tool identities and all samples remain archived; count-run
times are not headline timings. M3 remains in progress.
