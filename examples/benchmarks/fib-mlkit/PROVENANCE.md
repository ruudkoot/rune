# fib-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/fib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Retain both base cases returning one, x-2 before x-1 evaluation, and the
per-call numeric trace. Normal preserves original n=10. Replace primitive
printing by in-memory capture, including Before/After lines; this is a
trace-producing variant, not the pure MLton Fibonacci kernel. Independent
recursive trace generation and iterative Fibonacci values supply fixtures.

Diagnostic tags recursion,trace,allocation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).
