# vector-rev-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-rev.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve pair elements, regeneration inside every iteration
and two reversal allocations. The original counter condition k<0 means
initial trials+1 executions, retained explicitly. Large preserves upstream
length/counter. Complete indexed validation and IntInf result accumulation
replace the head-only or aggregate-only observation. Fixtures follow the
independent ordered-sequence sum. These representation/lifetime variants
remain distinct from each other and MLton fixed-width vectors.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags vectors,allocation,representation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `240` |
| normal | `10000 10` | `1099890000` |
| large | `10000 10000` | `999999990000` |
