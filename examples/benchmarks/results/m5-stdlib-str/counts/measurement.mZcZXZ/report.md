# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_string_partial_match | normal | rune | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| str_string_partial_match | normal | rune | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| str_string_partial_match | normal | rune | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 24411665/9622040/400565 |
| str_string_partial_match | normal | rune:opt | O2 | compile | 1/1 | 2.410000000 | 2.410000000 to 2.410000000 | - |
| str_string_partial_match | normal | rune:opt | O2 | native-compile | 1/1 | 0.520000000 | 0.520000000 to 0.520000000 | - |
| str_string_partial_match | normal | rune:opt | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| str_string_partial_match | normal | rune:opt | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 24411665/9622040/400565 |
| str_string_partial_match | normal | rune:new | O2 | compile | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| str_string_partial_match | normal | rune:new | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| str_string_partial_match | normal | rune:new | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 15607125/9622040/400565 |
| str_string_partial_match | normal | rune:jit | O2 | compile | 1/1 | 2.630000000 | 2.630000000 to 2.630000000 | - |
| str_string_partial_match | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| str_string_partial_match | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 15607125/9622040/400565 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

