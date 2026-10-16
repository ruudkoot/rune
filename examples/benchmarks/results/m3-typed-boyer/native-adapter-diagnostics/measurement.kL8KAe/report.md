# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| boyer-nofib-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 5.730000000 | 5.730000000 to 5.730000000 | - |
| boyer-nofib-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 5.640000000 | 5.640000000 to 5.640000000 | - |
| boyer-nofib-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 6.770000000 | 6.770000000 to 6.770000000 | - |
| boyer-nofib-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | - |
| boyer-nofib-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 5.500000000 | 5.500000000 to 5.500000000 | - |
| boyer-nofib-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 5.170000000 | 5.170000000 to 5.170000000 | - |
| boyer-nofib-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| boyer-nofib-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 3.230000000 | 3.230000000 to 3.230000000 | - |
| boyer-nofib-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | - |

Failure categories and artifact paths:

