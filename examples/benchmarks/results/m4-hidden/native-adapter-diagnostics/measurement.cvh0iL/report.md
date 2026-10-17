# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hidden-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 9.520000000 | 9.520000000 to 9.520000000 | - |
| hidden-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| hidden-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| hidden-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| hidden-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| hidden-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| hidden-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| hidden-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |

Failure categories and artifact paths:

- hidden-strict / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`hidden-strict/native-smlnj-legacy/correctness.0`).
