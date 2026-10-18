# Modular lambda-lifter validation

Two evaluation policies run both the source plain and fully-lazy lambda lifters.
All 56 smoke/normal primary cases pass: Rune O0/O2 stack/register/JIT/native
and the six managed SML hosts. All twenty final semantic groups pass all
64 assertions, giving 1280 passes, no failures and no incomplete checks.

The semantic target checks complete original input/plain/full ASTs for seven
cases, exact input/plain/full pretty output for the fixed program, shared
delays, strict pass boundaries, free-variable sets, recursive renaming,
the retained source lambda returned-supply behavior, IntInf literals,
higher-order printer indentation, zero work and negative report/hash checks.
An independent Python evaluator checks six terminating examples before/after
both transformations, including factorial 720; all seven supercombinator
results are structurally checked for scope, closure and absence of lambdas.
The fixed example is not claimed to terminate under that evaluator.

Original FAST400/NORM4000/SLOW20000 runs reproduce all supplied fixtures.
Each SML iteration checks the complete 1948-byte report and original modular
64-bit hash. Both 4000-iteration private calibrations pass under default Rune
O1, with an uninterrupted process guard. That diagnostic timing is not an
O0/O2 compiler comparison. The full selected SML large runs remain unrecorded.

Eight full-normal Rune count samples agree. Both guards exit zero without
interruption. Six serial single fresh-process native smoke samples and every
correctness preflight pass before heavy checks; they validate adapters, not a
ten-sample comparative performance claim.

An earlier auxiliary program crashes ML Kit's region analyser with
cannot subtract effects / Mul: diffef failed. Eighteen earlier groups pass
64 assertions; two ML Kit groups execute none, leaving 128 checks incomplete.
Their full sources and compiler logs remain in development/. The same two
4000-iteration applications pass on ML Kit. Equivalent explicit calls for
the seven fixed cases also pass all 64 checks on ML Kit. The public target
uses those common explicit calls, keeps synthetic data outside the benchmark
kernel and passes all twenty final groups. No host-specific kernel, weakened
assertion, changed expected answer or runtime workaround is used.

Four guarded executable-paper authorship regressions bring inventory tests
to 132. All pass and five source pins reproduce 861 primary entries. Preserve
the complete executable paper and author block, companion sources, original
fixtures, modern salt/hash adapter and source/input identities. No separate
permission grant is inferred. Canonical identity/group maps replace only
byte-verified repeated input copies; raw per-run outcomes remain intact.
Full make JOBS=4 check exits zero with 1397 profiles and all compiler,
runedoc and runeopt cross-build comparisons. The complete transcript is
recorded in the validation ledger. Full selected SML large runs remain
unrecorded.
