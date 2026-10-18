# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_uppercase_ascii | normal | rune | O2 | compile | 1/1 | 3.430000000 | 3.430000000 to 3.430000000 | - |
| bytes_uppercase_ascii | normal | rune | O2 | correctness | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| bytes_uppercase_ascii | normal | rune | O2 | count | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | 147621949/202378352/4603280 |
| bytes_uppercase_ascii | normal | rune:opt | O2 | compile | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| bytes_uppercase_ascii | normal | rune:opt | O2 | native-compile | 1/1 | 0.930000000 | 0.930000000 to 0.930000000 | - |
| bytes_uppercase_ascii | normal | rune:opt | O2 | correctness | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| bytes_uppercase_ascii | normal | rune:opt | O2 | count | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | 147621949/202378352/4603280 |
| bytes_uppercase_ascii | normal | rune:new | O2 | compile | 1/1 | 3.110000000 | 3.110000000 to 3.110000000 | - |
| bytes_uppercase_ascii | normal | rune:new | O2 | correctness | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| bytes_uppercase_ascii | normal | rune:new | O2 | count | 1/1 | 2.180000000 | 2.180000000 to 2.180000000 | 103875269/202378352/4603280 |
| bytes_uppercase_ascii | normal | rune:jit | O2 | compile | 1/1 | 3.510000000 | 3.510000000 to 3.510000000 | - |
| bytes_uppercase_ascii | normal | rune:jit | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| bytes_uppercase_ascii | normal | rune:jit | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 103875269/202378352/4603280 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

