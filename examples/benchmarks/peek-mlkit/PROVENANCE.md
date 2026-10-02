# peek-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/peek.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/peek_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Keep the generative-exception property list with one integer
entry, regenerated for each outer iteration. Large preserves ten million
lookups five times. MLton tests mixed widths and deeper lists; this variant
requires no Int64 and is portable on Poly/ML. Inner sums fit 31 bits; outer
checksums use IntInf. Independent arithmetic gives 13*lookups*repetitions.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags exceptions,closures,lookup
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `1300` |
| normal | `100000 5` | `6500000` |
| large | `10000000 5` | `650000000` |
