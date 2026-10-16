# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| eliza-lazy | normal | rune | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| eliza-lazy | normal | rune | O2 | correctness | 1/1 | 39.090000000 | 39.090000000 to 39.090000000 | - |
| eliza-lazy | normal | rune | O2 | count | 1/1 | 35.760000000 | 35.760000000 to 35.760000000 | 8129471305/23361352888/614692047 |
| eliza-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| eliza-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| eliza-lazy | normal | rune:opt | O2 | correctness | 1/1 | 17.720000000 | 17.720000000 to 17.720000000 | - |
| eliza-lazy | normal | rune:opt | O2 | count | 1/1 | 18.960000000 | 18.960000000 to 18.960000000 | 8129471305/23361352888/614692047 |
| eliza-lazy | normal | rune:new | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| eliza-lazy | normal | rune:new | O2 | correctness | 1/1 | 33.860000000 | 33.860000000 to 33.860000000 | - |
| eliza-lazy | normal | rune:new | O2 | count | 1/1 | 35.950000000 | 35.950000000 to 35.950000000 | 5085071813/23361352888/614692047 |
| eliza-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| eliza-lazy | normal | rune:jit | O2 | correctness | 1/1 | 16.500000000 | 16.500000000 to 16.500000000 | - |
| eliza-lazy | normal | rune:jit | O2 | count | 1/1 | 14.360000000 | 14.360000000 to 14.360000000 | 5085071813/23361352888/614692047 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

