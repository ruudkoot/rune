# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-lazy | normal | rune | O2 | compile | 1/1 | 5.920000000 | 5.920000000 to 5.920000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | correctness | 1/1 | 135.580000000 | 135.580000000 to 135.580000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | count | 1/1 | 121.810000000 | 121.810000000 to 121.810000000 | 15066222443/19947075160/538288473 |
| simple-nofib-report-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.490000000 | 4.490000000 to 4.490000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | correctness | 1/1 | 50.520000000 | 50.520000000 to 50.520000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | count | 1/1 | 49.560000000 | 49.560000000 to 49.560000000 | 15066222443/19947075160/538288473 |
| simple-nofib-report-lazy | normal | rune:new | O2 | compile | 1/1 | 4.130000000 | 4.130000000 to 4.130000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | correctness | 1/1 | 93.330000000 | 93.330000000 to 93.330000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | count | 1/1 | 105.000000000 | 105.000000000 to 105.000000000 | 8466117320/19947075160/538288473 |
| simple-nofib-report-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.530000000 | 3.530000000 to 3.530000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | correctness | 1/1 | 36.340000000 | 36.340000000 to 36.340000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | count | 1/1 | 30.680000000 | 30.680000000 to 30.680000000 | 8466117320/19947075160/538288473 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

