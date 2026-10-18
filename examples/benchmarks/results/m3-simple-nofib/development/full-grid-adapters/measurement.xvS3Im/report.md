# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 12.000000000 | 12.000000000 to 12.000000000 | - |
| simple-nofib-report-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| simple-nofib-report-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 2.230000000 | 2.230000000 to 2.230000000 | - |
| simple-nofib-report-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| simple-nofib-report-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| simple-nofib-report-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | - |
| simple-nofib-report-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 3.110000000 | 3.110000000 to 3.110000000 | - |
| simple-nofib-report-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |

Failure categories and artifact paths:

- simple-nofib-report-lazy / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`simple-nofib-report-lazy/native-smlnj-legacy/correctness.0`).
