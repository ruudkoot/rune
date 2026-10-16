# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| scs-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 11.220000000 | 11.220000000 to 11.220000000 | - |
| scs-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| scs-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| scs-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| scs-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| scs-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | - |
| scs-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | - |
| scs-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| scs-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |

Failure categories and artifact paths:

