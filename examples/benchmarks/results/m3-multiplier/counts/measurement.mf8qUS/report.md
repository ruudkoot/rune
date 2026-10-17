# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| multiplier-count-strict | normal | rune | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| multiplier-count-strict | normal | rune | O2 | correctness | 1/1 | 12.250000000 | 12.250000000 to 12.250000000 | - |
| multiplier-count-strict | normal | rune | O2 | count | 1/1 | 14.070000000 | 14.070000000 to 14.070000000 | 1865587860/5176370544/151144838 |
| multiplier-count-strict | normal | rune:opt | O2 | compile | 1/1 | 1.930000000 | 1.930000000 to 1.930000000 | - |
| multiplier-count-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| multiplier-count-strict | normal | rune:opt | O2 | correctness | 1/1 | 9.370000000 | 9.370000000 to 9.370000000 | - |
| multiplier-count-strict | normal | rune:opt | O2 | count | 1/1 | 8.130000000 | 8.130000000 to 8.130000000 | 1865587860/5176370544/151144838 |
| multiplier-count-strict | normal | rune:new | O2 | compile | 1/1 | 1.750000000 | 1.750000000 to 1.750000000 | - |
| multiplier-count-strict | normal | rune:new | O2 | correctness | 1/1 | 15.300000000 | 15.300000000 to 15.300000000 | - |
| multiplier-count-strict | normal | rune:new | O2 | count | 1/1 | 13.480000000 | 13.480000000 to 13.480000000 | 1122211001/5176370544/151144838 |
| multiplier-count-strict | normal | rune:jit | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| multiplier-count-strict | normal | rune:jit | O2 | correctness | 1/1 | 7.780000000 | 7.780000000 to 7.780000000 | - |
| multiplier-count-strict | normal | rune:jit | O2 | count | 1/1 | 8.300000000 | 8.300000000 to 8.300000000 | 1122211001/5176370544/151144838 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

