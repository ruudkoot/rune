# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| infer-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 6.340000000 | 6.340000000 to 6.340000000 | - |
| infer-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| infer-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| infer-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| infer-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |

Failure categories and artifact paths:

- infer-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`infer-strict/native-smlnj-legacy/build/compile`).
