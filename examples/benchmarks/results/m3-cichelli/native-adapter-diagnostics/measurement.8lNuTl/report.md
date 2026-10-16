# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| cichelli-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.480000000 | 7.480000000 to 7.480000000 | - |
| cichelli-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| cichelli-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| cichelli-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| cichelli-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| cichelli-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| cichelli-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| cichelli-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| cichelli-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |

Failure categories and artifact paths:

