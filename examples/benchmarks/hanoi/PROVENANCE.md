# hanoi provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/hanoi.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Keep the original recursive calls and move ordering, and normal ten-disk
input. Replace primitive printing by a deterministic captured trace. Validate
every move against three explicit towers and the final target tower; this
additional checking work is measured. Independent iterative Gray-code disk
selection supplies count and complete-trace checksum fixtures. No disk
representation or stopping condition changes; source printing becomes
in-memory capture and fixed result output.

Diagnostic tags recursion,trace,mutation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).
