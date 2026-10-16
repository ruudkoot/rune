# Sandmark integer arithmetic variants

Recorded 2026-10-16. Ten programs bring the catalogue to 250 programs and
744 profiles. [All 280 canonical smoke/normal cases](correctness.tsv) pass on
four Rune engines at both levels and all six managed SML hosts. Arguments in
the canonical ledger match the current manifest. Forty normal count samples
pass and applicable instruction/allocation comparisons agree. Counts remain
unbudgeted; instrumented samples do not supply headline timings.

The variants retain recursive factorial, Fibonacci's one/one bases, right-first
Takeuchi calls, four numeric modes, and the original count+1 repetition helper.
The integer-only Num translation retains tagged Small/Big paths and explicit
promotion/normalization; its unused rational branch is omitted. Signed Nativeint
arithmetic uses Word64 and the reference machine's 64-bit width. Selected
default-int and Num values fit every managed host's signed 31-bit domain.
Zarith/GMP is replaced by portable IntInf, with representation differences
documented. All library/program sources and individual notices are retained.

Pi preserves full four-coefficient composition, truncating division, streaming
digit checks and exact row formatting. Normal is calibrated to 128 digits;
large retains the published 10,000. The 1,000- and 256-digit candidate runs were
interrupted during calibration. Their completed, interrupted and unstarted
cases remain in [the attempts ledger](correctness-attempts.tsv), separate from
the final canonical cases. Partial count archives are `candidate1000/` and
`candidate256/`; only `counts/` contains the completed selected run.
The 128-digit diagnostic is retained as a bounded profile probe. No candidate
interruption is called a timeout or accepted timing sample. An earlier
fixture-ordering mistake was rejected by metadata validation before any workload
ran; its transcript is also retained.

Thirty-seven bounded original OCaml cases agree with independent factorial,
Fibonacci, memoized Takeuchi and Decimal Gauss-Legendre references. These include
all selected original profiles and every pi digit through 10,000, with the
original layout. The reference script, fixtures, compiler/library identities,
source pins and acquisition limits are under `reference-observers/`.

Twenty-one semantic checks run on all ten configurations at both requested
levels. Nine pass all checks. Native32 SML/NJ passes twenty and fails the signed
Word64 boundary check at each level, while passing all selected positive-valued
benchmark profiles. A separate four-check runtime-input probe isolates an
incorrect constant subtraction and passes on the other nine configurations.
See [the precise host diagnostic](../../validation/zarith-word64.md). No source
workaround or changed expected result is introduced.

Input acquisition, per-call result checks, decimal conversion and replacement
of original stdout IO are documented adaptations. Large SML execution is
claimed only where explicitly recorded. M5 remains in progress.
