# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| happy-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 24.470000000 | 24.470000000 to 24.470000000 | - |
| happy-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 21.790000000 | 21.790000000 to 21.790000000 | - |
| happy-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| happy-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| happy-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| happy-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| happy-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 22.310000000 | 22.310000000 to 22.310000000 | - |
| happy-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 14.520000000 | 14.520000000 to 14.520000000 | - |
| happy-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| happy-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| happy-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 21.040000000 | 21.040000000 to 21.040000000 | - |
| happy-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| happy-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

