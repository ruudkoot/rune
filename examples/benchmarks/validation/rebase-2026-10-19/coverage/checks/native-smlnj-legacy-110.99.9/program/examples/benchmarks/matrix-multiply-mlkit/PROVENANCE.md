# matrix-multiply-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/matrix-multiply.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/matrix-multiply_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Preserve Array2 dot-product multiplication and the original
all-ones distribution, regenerated for each call. Large preserves dimension
200 twice. This differs from MLton ramp data/dimension 500. Check every
result element equals n exactly (selected integral doubles are exact); sum
n^3 per call is independently derived. No floating tolerance is needed.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags arrays,numerical
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `64` |
| normal | `100 2` | `2000000` |
| large | `200 2` | `16000000` |
