# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| minilight | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 8.640000000 | 8.640000000 to 8.640000000 | - |
| minilight | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| minilight | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| minilight | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.820000000 | 0.820000000 to 0.820000000 | - |
| minilight | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| minilight | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| minilight | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| minilight | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| minilight | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |

Failure categories and artifact paths:

