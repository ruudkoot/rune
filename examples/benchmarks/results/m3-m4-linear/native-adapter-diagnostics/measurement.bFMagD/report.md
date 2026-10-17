# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| linear-nofib-gc-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.040000000 | 7.040000000 to 7.040000000 | - |
| linear-nofib-gc-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| linear-nofib-gc-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| linear-nofib-gc-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| linear-nofib-gc-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| linear-nofib-gc-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.700000000 | 0.700000000 to 0.700000000 | - |
| linear-nofib-gc-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| linear-nofib-gc-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |

Failure categories and artifact paths:

- linear-nofib-gc-strict / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`linear-nofib-gc-strict/native-smlnj-legacy/correctness.0`).
