# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_index | normal | rune | O2 | compile | 1/1 | 3.830000000 | 3.830000000 to 3.830000000 | - |
| bytes_index | normal | rune | O2 | correctness | 1/1 | 0.650000000 | 0.650000000 to 0.650000000 | - |
| bytes_index | normal | rune | O2 | count | 1/1 | 0.510000000 | 0.510000000 to 0.510000000 | 61024067/68858416/1801286 |
| bytes_index | normal | rune:opt | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| bytes_index | normal | rune:opt | O2 | native-compile | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| bytes_index | normal | rune:opt | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| bytes_index | normal | rune:opt | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 61024067/68858416/1801286 |
| bytes_index | normal | rune:new | O2 | compile | 1/1 | 2.740000000 | 2.740000000 to 2.740000000 | - |
| bytes_index | normal | rune:new | O2 | correctness | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| bytes_index | normal | rune:new | O2 | count | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | 42415331/68858416/1801286 |
| bytes_index | normal | rune:jit | O2 | compile | 1/1 | 2.510000000 | 2.510000000 to 2.510000000 | - |
| bytes_index | normal | rune:jit | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| bytes_index | normal | rune:jit | O2 | count | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | 42415331/68858416/1801286 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

