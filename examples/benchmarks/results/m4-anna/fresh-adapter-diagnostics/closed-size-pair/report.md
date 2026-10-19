# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| anna-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 30.220000000 | 30.220000000 to 30.220000000 | - |
| anna-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| anna-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| anna-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 5.470000000 | 5.470000000 to 5.470000000 | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.640000000 | 0.640000000 to 0.640000000 | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 20.920000000 | 20.920000000 to 20.920000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| anna-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |

Failure categories and artifact paths:

- anna-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`anna-lazy/native-smlnj-legacy/build/compile`).
- anna-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`anna-strict/native-smlnj-legacy/build/compile`).
