# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 9.870000000 | 9.870000000 to 9.870000000 | - |
| simple-nofib-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| simple-nofib-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| simple-nofib-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.330000000 | 1.330000000 to 1.330000000 | - |
| simple-nofib-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| simple-nofib-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| simple-nofib-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.660000000 | 0.660000000 to 0.660000000 | - |
| simple-nofib-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | - |

Failure categories and artifact paths:

- simple-nofib-strict / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`simple-nofib-strict/native-smlnj-legacy/correctness.0`).
