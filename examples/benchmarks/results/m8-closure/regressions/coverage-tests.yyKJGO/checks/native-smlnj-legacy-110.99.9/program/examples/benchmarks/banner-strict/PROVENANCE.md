# banner-strict provenance

nofib revision `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/banner/Main.hs`, `boot.sh`, `Makefile` and both templates. Mark P Jones's
1992 header describes a Basic predecessor and a Hugs version; retain the complete
explanation, font data and identities. An individual license grant is unstated.
The font is embedded program data, with no separately acquired dataset. Boot's
3500/35000/180000 template repetitions and its shootout-setting comment remain
provenance, without assuming identical implementations elsewhere.

## Algorithm, variants and source fidelity

Preserve ordered letter/digit list indexing, case mapping, punctuation lookup,
blank/slant/reversed-slant glyphs, ragged transpose, right-fold two-space joining,
leading blank line and exact output rows. Memoized and eager finite sequences
share one SML97 functor. The private suspension policy ties the source's cyclic
infinite empty-row fallback in Need and caches it across requests. That fallback
is not replaced by a finite blank glyph. Eagerly evaluating the infinite branch
cannot terminate; every fixed profile uses recognized finite ASCII glyphs.

Glyph/row heads remain delayed in Need. The transpose replacement shares its
head/tail partition; punctuation search returns its first match directly instead
of allocating a filtered candidate list. Portable list/string operations replace
library calls. Explicit memo cells, table construction and suspension policies
change representation/allocation; no compiler/runtime feature is added. The
fixed template's ASCII domain preserves the source character classifications.

## Profiles, acquisition and result checks

Smoke repeats the template 2 times. Normal 35,000 and large 180,000 preserve boot's
NORM/SLOW settings; original FAST 3,500 is also checked. The exact35-byte input and
1147-byte output templates are retained. To avoid storing repeated megabyte
files, profiles identify those templates and the original repetition count.
SML97 generates the exact logical input stream within measured execution.
This replaces boot-time file expansion/getContents with template acquisition
and explicit stream generation: generation work, IO and chunk representation
are documented measurement adaptations. Expanded input/output SHA256 identities
are recorded for each profile.

Per-line execution preserves Main's mapM_ putStr ordering and consumes each
output before moving to the next line. Every output byte is compared against
the periodically indexed original expected template, then contributes to an
explicit modulo 2^32 fingerprint. Count, ordering and EOF are checked. A profile
guard requires an ASCII, line-terminated input template, matching the pinned data.
The largest 206,460,000-byte output count fits31 bits. Control is ordinary SML97;
the driver returns count/hash after validation rather than printing the artwork.

Unchanged GHC, an independent glyph renderer and pinned templates agree. Bounded
GHC runs check all selected profiles plus original FAST, including 40,145,000
normal and 206,460,000 large output bytes. Twelve semantic checks cover full
alphabets, digits, punctuation, both slashes, whitespace, empty/mixed lines,
case mapping, variants, knot sharing and the productive lazy unknown-glyph
newline prefix. A GHC observer independently confirms that infinite prefix.
Large SML execution is claimed only for recorded cases.

## Runtime questions and references

Shared table memoization, input generation, transpose partition sharing,
finite-sequence evaluation, per-line retention and byte checking are source-based
diagnostic hypotheses until established by measurements or IR inspection.
Compiler comparisons use identical SML; original Haskell supplies correctness
references. Jones's retained explanation and the [pinned implementation](https://github.com/ghc/nofib/blob/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/banner/Main.hs)
provide program-specific history. See Partain's suite paper and the shared
measurement survey. No historical timing claim is transferred to these ports.
