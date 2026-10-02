# tailfib-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tailfib.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tailfib_smlnj.sml`. Their pristine sources are retained.

Keep the original 38-step accumulator recurrence; large retains fifty million
repetitions. MLton tailfib instead selects 44 steps and one million repetitions.
Runtime parameterization and an IntInf checksum are driver adaptations.
Independent iterative Fibonacci supplies fixtures; the kernel is unmemoized.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags calls,recursion
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `38 1000` | `39088169000` |
| large | `38 50000000` | `1954408450000000` |
