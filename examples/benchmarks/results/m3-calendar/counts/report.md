# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| calendar-lazy | normal | rune | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| calendar-lazy | normal | rune | O2 | correctness | 1/1 | 47.460000000 | 47.460000000 to 47.460000000 | - |
| calendar-lazy | normal | rune | O2 | count | 1/1 | 45.790000000 | 45.790000000 to 45.790000000 | 9234737577/31899850256/984021826 |
| calendar-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| calendar-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| calendar-lazy | normal | rune:opt | O2 | correctness | 1/1 | 21.220000000 | 21.220000000 to 21.220000000 | - |
| calendar-lazy | normal | rune:opt | O2 | count | 1/1 | 23.120000000 | 23.120000000 to 23.120000000 | 9234737577/31899850256/984021826 |
| calendar-lazy | normal | rune:new | O2 | compile | 1/1 | 1.260000000 | 1.260000000 to 1.260000000 | - |
| calendar-lazy | normal | rune:new | O2 | correctness | 1/1 | 43.000000000 | 43.000000000 to 43.000000000 | - |
| calendar-lazy | normal | rune:new | O2 | count | 1/1 | 43.850000000 | 43.850000000 to 43.850000000 | 5612686007/31899850256/984021826 |
| calendar-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| calendar-lazy | normal | rune:jit | O2 | correctness | 1/1 | 21.200000000 | 21.200000000 to 21.200000000 | - |
| calendar-lazy | normal | rune:jit | O2 | count | 1/1 | 21.510000000 | 21.510000000 to 21.510000000 | 5612686007/31899850256/984021826 |
| calendar-strict | normal | rune | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| calendar-strict | normal | rune | O2 | correctness | 1/1 | 9.220000000 | 9.220000000 to 9.220000000 | - |
| calendar-strict | normal | rune | O2 | count | 1/1 | 10.450000000 | 10.450000000 to 10.450000000 | 2432130604/5649342512/141185602 |
| calendar-strict | normal | rune:opt | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| calendar-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| calendar-strict | normal | rune:opt | O2 | correctness | 1/1 | 4.010000000 | 4.010000000 to 4.010000000 | - |
| calendar-strict | normal | rune:opt | O2 | count | 1/1 | 4.120000000 | 4.120000000 to 4.120000000 | 2432130604/5649342512/141185602 |
| calendar-strict | normal | rune:new | O2 | compile | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | - |
| calendar-strict | normal | rune:new | O2 | correctness | 1/1 | 8.490000000 | 8.490000000 to 8.490000000 | - |
| calendar-strict | normal | rune:new | O2 | count | 1/1 | 8.370000000 | 8.370000000 to 8.370000000 | 1492089083/5649342512/141185602 |
| calendar-strict | normal | rune:jit | O2 | compile | 1/1 | 2.130000000 | 2.130000000 to 2.130000000 | - |
| calendar-strict | normal | rune:jit | O2 | correctness | 1/1 | 3.750000000 | 3.750000000 to 3.750000000 | - |
| calendar-strict | normal | rune:jit | O2 | count | 1/1 | 3.780000000 | 3.780000000 to 3.780000000 | 1492089083/5649342512/141185602 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

