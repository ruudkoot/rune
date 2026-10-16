# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| secretary-strict | normal | rune | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| secretary-strict | normal | rune | O2 | correctness | 1/1 | 49.450000000 | 49.450000000 to 49.450000000 | - |
| secretary-strict | normal | rune | O2 | count | 1/1 | 50.790000000 | 50.790000000 to 50.790000000 | 11537535229/14846196920/421928301 |
| secretary-strict | normal | rune:opt | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| secretary-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| secretary-strict | normal | rune:opt | O2 | correctness | 1/1 | 20.090000000 | 20.090000000 to 20.090000000 | - |
| secretary-strict | normal | rune:opt | O2 | count | 1/1 | 18.240000000 | 18.240000000 to 18.240000000 | 11537535229/14846196920/421928301 |
| secretary-strict | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| secretary-strict | normal | rune:new | O2 | correctness | 1/1 | 40.500000000 | 40.500000000 to 40.500000000 | - |
| secretary-strict | normal | rune:new | O2 | count | 1/1 | 42.300000000 | 42.300000000 to 42.300000000 | 6694205012/14846196920/421928301 |
| secretary-strict | normal | rune:jit | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| secretary-strict | normal | rune:jit | O2 | correctness | 1/1 | 16.110000000 | 16.110000000 to 16.110000000 | - |
| secretary-strict | normal | rune:jit | O2 | count | 1/1 | 16.890000000 | 16.890000000 to 16.890000000 | 6694205012/14846196920/421928301 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

