# Hartel list-comprehension compiler and copy variants

All 112 canonical cases pass: four variants, smoke/normal, Rune's four engines
at O0/O2, and six native hosts at their compiler defaults. The complete coverage
and attempts tables accompany the canonical pass ledger. All 42 semantic checks
pass on each of the ten configurations in both invocations (840 assertions).
The fixture checks force complete input/transformed text, while headline profile
consumers preserve the original character-spine-only length demand.

Sixteen normal count samples agree under execution-model rules, including all
engine allocation comparisons. Existing budgets remain unchanged; these new
profiles are unbudgeted. Twelve serial single fresh-process samples from MLton,
legacy 64-bit SML/NJ and Poly/ML validate the measurement adapters. They are
diagnostics, not a headline comparison or evidence of steady state.

The original GHC programs match all upstream FAST/NORM/SLOW fixtures and the
selected suite inputs. Independent AST desugaring/rendering agrees with the full
626-byte transformed program, original AST observers and source variant review.
The selected profiles use 20/2000/20000 repetitions. Normal preserves upstream
FAST_OPTS; large preserves NORM_OPTS. The original 100000-repeat fixture remains
in provenance. A 20000-repeat private preflight exhausts a 4 GiB address-space
limit, motivating explicit scaling selection. Whole large SML acceptance under
the selected 8 GiB limit has not been recorded.

Discarded preflights remain separate: an early prototype's extra concatenation
introduced quadratic suffix copies and was stopped, then corrected to source
nesting before canonical checks. Later bounded resource preflights inform input
selection; they cannot contribute timing samples. The exact final source
identities, raw canonical/semantic/count logs and native adapter configurations
are retained. The full repository acceptance check exits 0; its complete transcript is linked
in validation.md. M3 remains in progress.
