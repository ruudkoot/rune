# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| veritas-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 26.850000000 | 26.850000000 to 26.850000000 | - |
| veritas-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 1.060000000 | 1.060000000 to 1.060000000 | - |
| veritas-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.820000000 | 0.820000000 to 0.820000000 | - |
| veritas-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 9.410000000 | 9.410000000 to 9.410000000 | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| veritas-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| veritas-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 24.750000000 | 24.750000000 to 24.750000000 | - |
| veritas-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| veritas-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| veritas-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 3.790000000 | 3.790000000 to 3.790000000 | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| veritas-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |

Failure categories and artifact paths:

- veritas-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`veritas-lazy/native-smlnj-legacy/build/compile`).
- veritas-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`veritas-strict/native-smlnj-legacy/build/compile`).
