# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-report-lazy | normal | rune | O2 | compile | 1/1 | 7.440000000 | 7.440000000 to 7.440000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | correctness | 1/1 | 199.820000000 | 199.820000000 to 199.820000000 | - |
| simple-nofib-report-lazy | normal | rune | O2 | count | 1/1 | 242.500000000 | 242.500000000 to 242.500000000 | 13972594304/15701561120/402877054 |
| simple-nofib-report-lazy | normal | rune:opt | O2 | compile | 1/1 | 6.890000000 | 6.890000000 to 6.890000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | correctness | 1/1 | 72.920000000 | 72.920000000 to 72.920000000 | - |
| simple-nofib-report-lazy | normal | rune:opt | O2 | count | 1/1 | 50.560000000 | 50.560000000 to 50.560000000 | 13972594304/15701561120/402877054 |
| simple-nofib-report-lazy | normal | rune:new | O2 | compile | 1/1 | 3.830000000 | 3.830000000 to 3.830000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | correctness | 1/1 | 104.160000000 | 104.160000000 to 104.160000000 | - |
| simple-nofib-report-lazy | normal | rune:new | O2 | count | 1/1 | 113.960000000 | 113.960000000 to 113.960000000 | 7738484176/15701561120/402877054 |
| simple-nofib-report-lazy | normal | rune:jit | O2 | compile | 1/1 | 6.700000000 | 6.700000000 to 6.700000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | correctness | 1/1 | 42.420000000 | 42.420000000 to 42.420000000 | - |
| simple-nofib-report-lazy | normal | rune:jit | O2 | count | 1/1 | 38.980000000 | 38.980000000 to 38.980000000 | 7738484176/15701561120/402877054 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

