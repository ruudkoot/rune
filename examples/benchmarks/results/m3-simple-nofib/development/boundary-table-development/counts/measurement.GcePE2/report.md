# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-strict | normal | rune | O2 | compile | 1/1 | 7.500000000 | 7.500000000 to 7.500000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | correctness | 1/1 | 197.640000000 | 197.640000000 to 197.640000000 | - |
| simple-nofib-report-strict | normal | rune | O2 | count | 1/1 | 230.840000000 | 230.840000000 to 230.840000000 | 14119761062/15960600264/407573469 |
| simple-nofib-report-strict | normal | rune:opt | O2 | compile | 1/1 | 9.500000000 | 9.500000000 to 9.500000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | native-compile | 1/1 | 2.360000000 | 2.360000000 to 2.360000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | correctness | 1/1 | 72.780000000 | 72.780000000 to 72.780000000 | - |
| simple-nofib-report-strict | normal | rune:opt | O2 | count | 1/1 | 49.550000000 | 49.550000000 to 49.550000000 | 14119761062/15960600264/407573469 |
| simple-nofib-report-strict | normal | rune:new | O2 | compile | 1/1 | 5.650000000 | 5.650000000 to 5.650000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | correctness | 1/1 | 106.220000000 | 106.220000000 to 106.220000000 | - |
| simple-nofib-report-strict | normal | rune:new | O2 | count | 1/1 | 110.510000000 | 110.510000000 to 110.510000000 | 7823816336/15960600264/407573469 |
| simple-nofib-report-strict | normal | rune:jit | O2 | compile | 1/1 | 4.980000000 | 4.980000000 to 4.980000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | correctness | 1/1 | 41.200000000 | 41.200000000 to 41.200000000 | - |
| simple-nofib-report-strict | normal | rune:jit | O2 | count | 1/1 | 37.160000000 | 37.160000000 to 37.160000000 | 7823816336/15960600264/407573469 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

