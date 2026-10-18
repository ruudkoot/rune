# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-strict | normal | rune | O2 | compile | 1/1 | 6.690000000 | 6.690000000 to 6.690000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | correctness | 1/1 | 140.490000000 | 140.490000000 to 140.490000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | count | 1/1 | 120.520000000 | 120.520000000 to 120.520000000 | 15343781153/20206114304/542984888 |
| simple-nofib-report-strict | normal | rune:opt | O2 | compile | 1/1 | 4.240000000 | 4.240000000 to 4.240000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | correctness | 1/1 | 48.940000000 | 48.940000000 to 48.940000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | count | 1/1 | 47.720000000 | 47.720000000 to 47.720000000 | 15343781153/20206114304/542984888 |
| simple-nofib-report-strict | normal | rune:new | O2 | compile | 1/1 | 3.930000000 | 3.930000000 to 3.930000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | correctness | 1/1 | 90.850000000 | 90.850000000 to 90.850000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | count | 1/1 | 101.320000000 | 101.320000000 to 101.320000000 | 8622572291/20206114304/542984888 |
| simple-nofib-report-strict | normal | rune:jit | O2 | compile | 1/1 | 3.950000000 | 3.950000000 to 3.950000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | correctness | 1/1 | 33.290000000 | 33.290000000 to 33.290000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | count | 1/1 | 30.850000000 | 30.850000000 to 30.850000000 | 8622572291/20206114304/542984888 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

