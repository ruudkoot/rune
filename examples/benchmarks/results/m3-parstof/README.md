# Parstof parser validation

All 56 smoke/normal primary cases pass across both policies, all Rune O0/O2
engines and six managed SML hosts. All twenty semantic groups complete their
81 assertions: 1620 passes, no failures and none incomplete. The registered
lexer/kernel/check/test sources are byte-identical to those semantic subjects;
the public Rune O0/O2 target also passes.

Complete original token streams and AST/error results cover ten inputs.
An independent ordered regular-expression lexer agrees on 1898 tokens;
a structural validator checks AST constructor ownership, arity, primitive
types and selected 31-bit bounds. This is not a second full parser proof.
Original FAST/NORM/SLOW outputs match all supplied fixtures.

Lazy success recognition leaves AST/lexical attributes unused, preserving the
source consumer. Strict policy constructs finite attributes. Both retain
memoized character/token control, source backtracking/recovery, cached grammar
closures, shared input and the exact source checksum. Separate JSON renderers
exercise full AST states without adding that consumer to timed profiles.

Direct controls cover delayed/shared callbacks, strict forcing, ordered
alternatives, sequence/failure short circuits, farther/tied error priority,
known-error recovery, deferred error text, cached grammar use, zero work
and rejection of bad input/checksums. Selected inputs and decoded character
values remain within byte characters and signed 31-bit bounds. Wider Haskell
character cases outside those profiles are not claimed as portable Unicode.

Earlier portability attempts remain in development/. The initial character
sort defaulted to integers in ML Kit, while unannotated cached parser refs
received incompatible weak types on SML/NJ. That first matrix has 972 passes
and 648 assertions incomplete because of compile errors. After the character
annotation alone, it has 1134 passes and 486 incomplete on three SML/NJ builds.
Explicit source-derived result types on all 42 nonterminals resolve those
remaining errors. Neither attempt has an incorrect-result assertion.
These are common portable typing fixes, not host-specific algorithms or
claims of compiler defects; final coverage passes every host.

Eight full-normal Rune count samples agree; both process guards exit zero
without interruption. Six serial single fresh-process native smoke samples
and every preflight pass before heavy checks. They validate adapters rather
than establish a ten-sample comparison. A final same-source private normal
pilot passes both 100-by-eight runs under default Rune O1 with an uninterrupted
guard; its combined diagnostic time is not an O0/O2 comparison. The earlier
pre-callback-delay pilot is retained separately. Full selected large SML runs
remain unrecorded.

All 132 inventory regressions and the five-pin 861-entry replay pass.
Source/embedded-data notices are unstated and not assigned from helper credits;
complete originals, fixtures, translation scripts and read-only observers
are retained. Canonical fixture identity/group maps replace only byte-verified
copies; per-run outputs and commands remain intact. Full make JOBS=4 check exits zero with 1403 profiles and all compiler,
runedoc and runeopt cross-build comparisons. The complete transcript is
recorded in the validation ledger; selected large SML scopes remain unrecorded.
