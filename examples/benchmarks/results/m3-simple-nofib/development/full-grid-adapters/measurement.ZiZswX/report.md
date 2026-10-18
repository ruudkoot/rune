# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 10.440000000 | 10.440000000 to 10.440000000 | - |
| simple-nofib-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| simple-nofib-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| simple-nofib-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| simple-nofib-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| simple-nofib-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.130000000 | 1.130000000 to 1.130000000 | - |
| simple-nofib-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | - |
| simple-nofib-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |

Failure categories and artifact paths:

- simple-nofib-lazy / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`simple-nofib-lazy/native-smlnj-legacy/correctness.0`).
