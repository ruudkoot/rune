# wc-input1-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/wc-input1.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/wc-input1_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Keep the million-byte newline-every-ten distribution and
twenty scans in large. Generate once per call, scan the same file repeatedly,
then delete it. Replace the random temporary name by fixed input.txt in
the fresh working directory. Retain input1 traversal and explicit close.
Suppress console reporting and consume every actual count; ceil(bytes/10)
is the independent fixture formula. No upstream input file is needed.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags io,bytes,streams
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 5` | `50000` |
| large | `1000000 20` | `2000000` |
