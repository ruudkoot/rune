# vector-concat_smlnj provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-concat_smlnj.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve integer elements, one retained input outside the loop
and concatenation of two copies. The original counter condition k<0 means
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
| normal | `1000 100` | `100899000` |
| large | `1000 100000` | `99900999000` |
