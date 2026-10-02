# kitreynolds3_no_basislib provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kitreynolds3_no_basislib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Preserve the custom list helpers and shared subtree construction. The search carries explicit ancestor lists.
Replace primitive mini-Basis string/equality/printing helpers with equivalent
SML97 operations, removing only unused primitive declarations. The original
depth is 10. Unlike the standard-Basis variant, its original main
selects this depth once. All path labels strictly decrease, independently
proving that the observed result is false. No memoization is introduced.

Diagnostic tags closures,sharing,allocation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).
