# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| parser-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 12.450000000 | 12.450000000 to 12.450000000 | - |
| parser-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.700000000 | 0.700000000 to 0.700000000 | - |
| parser-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| parser-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 4.590000000 | 4.590000000 to 4.590000000 | - |
| parser-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| parser-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| parser-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| parser-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| parser-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 3.420000000 | 3.420000000 to 3.420000000 | - |
| parser-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 11.720000000 | 11.720000000 to 11.720000000 | - |
| parser-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.480000000 | 0.480000000 to 0.480000000 | - |
| parser-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| parser-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 4.520000000 | 4.520000000 to 4.520000000 | - |
| parser-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| parser-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.990000000 | 0.990000000 to 0.990000000 | - |
| parser-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| parser-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | - |
| parser-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |

Failure categories and artifact paths:

