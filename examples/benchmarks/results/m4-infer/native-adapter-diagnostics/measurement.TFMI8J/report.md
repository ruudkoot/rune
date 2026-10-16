# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| infer-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.510000000 | 7.510000000 to 7.510000000 | - |
| infer-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| infer-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| infer-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |
| infer-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| infer-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |

Failure categories and artifact paths:

