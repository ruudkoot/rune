# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| veritas-lazy | smoke | native:mlton@20241230 | O2 | compile | 0/1 | - | - | - |
| veritas-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 19.100000000 | 19.100000000 to 19.100000000 | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | - |
| veritas-strict | smoke | native:mlton@20241230 | O2 | compile | 0/1 | - | - | - |
| veritas-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 4.260000000 | 4.260000000 to 4.260000000 | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |

Failure categories and artifact paths:

- veritas-lazy / native:mlton@20241230 / compile: timeout (`veritas-lazy/native-mlton/build/compile`).
- veritas-lazy / native:smlnj-legacy@110.99.9 / compile: timeout (`veritas-lazy/native-smlnj-legacy/build/compile`).
- veritas-strict / native:mlton@20241230 / compile: timeout (`veritas-strict/native-mlton/build/compile`).
- veritas-strict / native:smlnj-legacy@110.99.9 / compile: timeout (`veritas-strict/native-smlnj-legacy/build/compile`).
