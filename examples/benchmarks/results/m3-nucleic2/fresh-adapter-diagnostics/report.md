# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nucleic2-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 21.090000000 | 21.090000000 to 21.090000000 | - |
| nucleic2-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| nucleic2-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| nucleic2-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 25.840000000 | 25.840000000 to 25.840000000 | - |
| nucleic2-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| nucleic2-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| nucleic2-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| nucleic2-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.640000000 | 2.640000000 to 2.640000000 | - |
| nucleic2-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 18.800000000 | 18.800000000 to 18.800000000 | - |
| nucleic2-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| nucleic2-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 1.040000000 | 1.040000000 to 1.040000000 | - |
| nucleic2-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 23.980000000 | 23.980000000 to 23.980000000 | - |
| nucleic2-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| nucleic2-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | - |
| nucleic2-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 2.190000000 | 2.190000000 to 2.190000000 | - |
| nucleic2-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 4.320000000 | 4.320000000 to 4.320000000 | - |
| nucleic2-shared-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 21.120000000 | 21.120000000 to 21.120000000 | - |
| nucleic2-shared-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| nucleic2-shared-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| nucleic2-shared-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 25.070000000 | 25.070000000 to 25.070000000 | - |
| nucleic2-shared-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| nucleic2-shared-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| nucleic2-shared-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| nucleic2-shared-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.260000000 | 2.260000000 to 2.260000000 | - |
| nucleic2-shared-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 19.590000000 | 19.590000000 to 19.590000000 | - |
| nucleic2-shared-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 3.740000000 | 3.740000000 to 3.740000000 | - |
| nucleic2-shared-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 3.720000000 | 3.720000000 to 3.720000000 | - |
| nucleic2-shared-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 24.710000000 | 24.710000000 to 24.710000000 | - |
| nucleic2-shared-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| nucleic2-shared-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| nucleic2-shared-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 7.410000000 | 7.410000000 to 7.410000000 | - |
| nucleic2-shared-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 7.630000000 | 7.630000000 to 7.630000000 | - |

Failure categories and artifact paths:

- nucleic2-lazy / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`nucleic2-lazy/native-smlnj-legacy/correctness.0`).
- nucleic2-strict / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`nucleic2-strict/native-smlnj-legacy/correctness.0`).
- nucleic2-shared-lazy / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`nucleic2-shared-lazy/native-smlnj-legacy/correctness.0`).
- nucleic2-shared-strict / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`nucleic2-shared-strict/native-smlnj-legacy/correctness.0`).
