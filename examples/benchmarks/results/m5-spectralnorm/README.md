# Sequential spectral norm

Recorded 2026-10-16. [All 28 smoke/normal cases](correctness.tsv) pass on four Rune
engines at both levels and all six managed SML hosts. Seven actual-checker and
numerical semantic checks pass all ten configurations at both levels, including
analytic cases and rejected perturbations/nonfinite values. All four normal
count samples pass and applicable comparisons agree.

The original forty matrix-vector passes, separate A/transpose methods,
coefficient formula, accumulation order and temporary allocation on every AtA
remain intact. Per-size seventeen-digit original references and independent
fsum calculations agree; runtime bounds are explicit absolute/relative values.
Large 5,500 retains the published task input. Generic real-array representation
and scalar checking are documented adaptations. No universal large SML or
headline timing claim is made. M5 remains in progress.
