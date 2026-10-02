# tak-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tak.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tak_smlnj.sml`. Their pristine sources are retained.

Keep the strict Takeuchi recurrence and original (18,12,6) input. Large
retains 5000 calls; normal selects 100. The MLton profile uses different
coordinates, so this remains a named parameter variant. The independent
memoized oracle changes only fixture generation; the kernel remains unmemoized.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags calls,recursion
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `18 12 6 1` | `7` |
| normal | `18 12 6 100` | `700` |
| large | `18 12 6 5000` | `35000` |

The recurrence is identical to classic tak and uses `../shared/tak.sml`.
The original ML Kit driver parameters and repetition profile remain separate.
