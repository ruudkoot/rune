# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-strict | normal | rune | O2 | compile | 1/1 | 5.410000000 | 5.410000000 to 5.410000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | correctness | 1/1 | 104.590000000 | 104.590000000 to 104.590000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | count | 1/1 | 84.570000000 | 84.570000000 to 84.570000000 | 14119761051/15960600128/407573466 |
| simple-nofib-report-strict | normal | rune:opt | O2 | compile | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | correctness | 1/1 | 37.270000000 | 37.270000000 to 37.270000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | count | 1/1 | 38.560000000 | 38.560000000 to 38.560000000 | 14119761051/15960600128/407573466 |
| simple-nofib-report-strict | normal | rune:new | O2 | compile | 1/1 | 5.580000000 | 5.580000000 to 5.580000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | correctness | 1/1 | 119.200000000 | 119.200000000 to 119.200000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | count | 1/1 | 114.180000000 | 114.180000000 to 114.180000000 | 7823816328/15960600128/407573466 |
| simple-nofib-report-strict | normal | rune:jit | O2 | compile | 1/1 | 3.670000000 | 3.670000000 to 3.670000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | correctness | 1/1 | 39.120000000 | 39.120000000 to 39.120000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | count | 1/1 | 45.230000000 | 45.230000000 to 45.230000000 | 7823816328/15960600128/407573466 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

