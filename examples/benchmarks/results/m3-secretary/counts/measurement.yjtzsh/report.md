# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| secretary-lazy | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| secretary-lazy | normal | rune | O2 | correctness | 1/1 | 34.150000000 | 34.150000000 to 34.150000000 | - |
| secretary-lazy | normal | rune | O2 | count | 1/1 | 32.050000000 | 32.050000000 to 32.050000000 | 6711738827/9158171456/262998474 |
| secretary-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| secretary-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| secretary-lazy | normal | rune:opt | O2 | correctness | 1/1 | 11.790000000 | 11.790000000 to 11.790000000 | - |
| secretary-lazy | normal | rune:opt | O2 | count | 1/1 | 13.580000000 | 13.580000000 to 13.580000000 | 6711738827/9158171456/262998474 |
| secretary-lazy | normal | rune:new | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| secretary-lazy | normal | rune:new | O2 | correctness | 1/1 | 23.520000000 | 23.520000000 to 23.520000000 | - |
| secretary-lazy | normal | rune:new | O2 | count | 1/1 | 25.720000000 | 25.720000000 to 25.720000000 | 3912580675/9158171456/262998474 |
| secretary-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| secretary-lazy | normal | rune:jit | O2 | correctness | 1/1 | 10.390000000 | 10.390000000 to 10.390000000 | - |
| secretary-lazy | normal | rune:jit | O2 | count | 1/1 | 9.950000000 | 9.950000000 to 9.950000000 | 3912580675/9158171456/262998474 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

