# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| scs-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.980000000 | 7.980000000 to 7.980000000 | - |
| scs-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| scs-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| scs-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| scs-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| scs-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | - |
| scs-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| scs-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |

Failure categories and artifact paths:

- scs-lazy / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`scs-lazy/native-smlnj-legacy/correctness.0`).
