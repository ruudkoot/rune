# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| set_add_rem | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 8.170000000 | 8.170000000 to 8.170000000 | - |
| set_add_rem | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| set_add_rem | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| set_add_rem | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| set_add_rem | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| set_add_rem | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| set_add_rem | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| set_add_rem | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| set_add_rem | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |

Failure categories and artifact paths:

