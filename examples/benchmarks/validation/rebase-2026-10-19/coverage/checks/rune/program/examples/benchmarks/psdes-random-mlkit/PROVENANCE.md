# psdes-random-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/psdes-random.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/psdes-random_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks, following Numerical Recipes in C page 302. Preserve four
Word32 rounds, lookup arrays, seeds 13/14 and alternating half outputs. Add
an explicit reset at each driver call so repeated execution agrees with a
fresh process; do not recreate the constant lookup arrays each repetition.
Large keeps ten million outputs and its upstream EAD56832 fixture. Smaller
fixtures use an independent integer-modular Python implementation.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags word32,arithmetic,mutation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100` | `1E220B3` |
| normal | `100000` | `96543236` |
| large | `10000000` | `EAD56832` |
