# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-lazy | normal | rune | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | correctness | 1/1 | 82.270000000 | 82.270000000 to 82.270000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | count | 1/1 | 132.570000000 | 132.570000000 to 132.570000000 | 13972594293/15701560984/402877051 |
| simple-nofib-report-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.530000000 | 4.530000000 to 4.530000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | correctness | 1/1 | 73.730000000 | 73.730000000 to 73.730000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | count | 1/1 | 54.890000000 | 54.890000000 to 54.890000000 | 13972594293/15701560984/402877051 |
| simple-nofib-report-lazy | normal | rune:new | O2 | compile | 1/1 | 3.830000000 | 3.830000000 to 3.830000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | correctness | 1/1 | 121.380000000 | 121.380000000 to 121.380000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | count | 1/1 | 146.400000000 | 146.400000000 to 146.400000000 | 7738484168/15701560984/402877051 |
| simple-nofib-report-lazy | normal | rune:jit | O2 | compile | 1/1 | 5.870000000 | 5.870000000 to 5.870000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | correctness | 1/1 | 65.130000000 | 65.130000000 to 65.130000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | count | 1/1 | 53.080000000 | 53.080000000 to 53.080000000 | 7738484168/15701560984/402877051 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

