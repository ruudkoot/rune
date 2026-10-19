# kittmergesort_no_basislib provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kittmergesort_no_basislib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Preserve copying mergesort and the integer 167/mod2147 seed-1 generator.
The no-Basis source selects 25000 elements, while the canonical file selects
100000; the algorithm/generator are byte-equivalent after mini-Basis
replacement and are shared in BenchKittSort. Full sorted-element validation
and independently generated fixtures replace console progress output.
Normal retains 25000; large selects 100000.

Diagnostic tags sorting,copying,lists are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).
