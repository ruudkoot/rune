# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_string_match | normal | rune | O2 | compile | 1/1 | 2.290000000 | 2.290000000 to 2.290000000 | - |
| str_string_match | normal | rune | O2 | correctness | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | - |
| str_string_match | normal | rune | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 27811533/9622024/400565 |
| str_string_match | normal | rune:opt | O2 | compile | 1/1 | 2.410000000 | 2.410000000 to 2.410000000 | - |
| str_string_match | normal | rune:opt | O2 | native-compile | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| str_string_match | normal | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| str_string_match | normal | rune:opt | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 27811533/9622024/400565 |
| str_string_match | normal | rune:new | O2 | compile | 1/1 | 2.050000000 | 2.050000000 to 2.050000000 | - |
| str_string_match | normal | rune:new | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| str_string_match | normal | rune:new | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 16207033/9622024/400565 |
| str_string_match | normal | rune:jit | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| str_string_match | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| str_string_match | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 16207033/9622024/400565 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

