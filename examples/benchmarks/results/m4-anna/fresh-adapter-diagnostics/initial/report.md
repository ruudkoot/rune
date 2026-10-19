# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| anna-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 26.870000000 | 26.870000000 to 26.870000000 | - |
| anna-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| anna-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | - |
| anna-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 4.920000000 | 4.920000000 to 4.920000000 | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | - |
| anna-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 17.450000000 | 17.450000000 to 17.450000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| anna-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| anna-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 4.430000000 | 4.430000000 to 4.430000000 | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| anna-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | - |

Failure categories and artifact paths:

- anna-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`anna-lazy/native-smlnj-legacy/build/compile`).
- anna-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`anna-strict/native-smlnj-legacy/build/compile`).
