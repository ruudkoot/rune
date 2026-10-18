# Transform compiler-workload validation

Of 56 primary smoke/normal cases, 54 pass. Both policies pass all Rune
O0/O2 engines, MLton, three SML/NJ builds and Poly/ML. Strict also passes
ML Kit. Lazy fails compilation on ML Kit: normal records allocation failure
at its 4 GiB compilation limit; smoke returns load status 1 with an empty
compiler log, so its cause remains unclassified. Neither failure is a
runtime result or measurement. Complete attempt logs are retained.

The twenty semantic groups plan 5460 assertions. Eighteen groups complete
all 273 checks: 4914 passes, zero assertion failures. The two combined ML Kit
semantic compilations exhaust memory at 1 GiB, leaving 546 assertions
incomplete. A separate 4 GiB combined diagnostic and a smaller lazy-only
application also fail compilation with memory diagnostics. These separate
attempts do not establish the cause of the empty-log primary smoke failure.

Complete original token/parse/prepared/transformed trees and rendered reports
cover eleven embedded examples under both policies. The benchmark uses the
actual translated lexer and parser, not precomputed ASTs. Independent checks
cover 88 original ASTs, 5072 nodes, constructor ownership/arity, ASCII fields
and bounded labels. Independent cycle arithmetic agrees with all three
original fixtures. All original FAST/NORM/SLOW executions match their fixtures.
No general compiler-transformation or network-equivalence proof is claimed.

Direct controls cover callback sharing and demand, prefix/first-result
parsing, lexer quirks, self-inlining exclusion, state-field variable analysis,
ordered comparisons, character-list length versus indentation demand,
cached grammar use, zero work, cycle wrap and deliberately wrong lengths.
The initial strict zip poison test evaluated its argument before calling zip;
its incorrect test assumption is preserved separately from the final checks.

Eight full-normal Rune count samples agree, with zero-exit uninterrupted
guards. Six serial single fresh-process native smoke samples and all preflight
phases pass before heavy validation; these are adapter diagnostics rather than
ten-sample comparisons. Both private normal 3000-report runs also pass under
default Rune O1 with an uninterrupted guard. The combined diagnostic time is
not an O0/O2 comparison. Full selected large SML runs remain unrecorded.

The public Rune O0/O2 semantic target passes and its source bytes match the
validated private subject. All 132 inventory regressions and the five-pin
861-entry replay pass. Complete originals, extracted inputs, reviewed fixtures,
translation scripts, source identities and raw outcomes are retained.
Canonical fixture maps replace only byte-verified duplicate inputs.

Full make JOBS=4 check exits zero with 1409 profiles and all compiler,
runedoc and runeopt cross-build comparisons. The complete transcript is
recorded in the validation ledger; selected large SML scopes remain unrecorded.

Staging removed three trailing spaces from the registered kernel. Tokens and
line numbers are unchanged; the public O0/O2 semantic target passes again.
Earlier raw source subjects remain intact and the cleanup is recorded.
