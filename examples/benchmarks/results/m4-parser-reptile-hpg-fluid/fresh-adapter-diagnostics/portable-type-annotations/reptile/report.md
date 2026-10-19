# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| reptile-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.630000000 | 7.630000000 to 7.630000000 | - |
| reptile-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| reptile-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| reptile-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 5.490000000 | 5.490000000 to 5.490000000 | - |
| reptile-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.780000000 | 0.780000000 to 0.780000000 | - |
| reptile-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 9.560000000 | 9.560000000 to 9.560000000 | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 7.870000000 | 7.870000000 to 7.870000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 6.760000000 | 6.760000000 to 6.760000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| reptile-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 5.260000000 | 5.260000000 to 5.260000000 | - |
| reptile-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | - |
| reptile-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |

Failure categories and artifact paths:

