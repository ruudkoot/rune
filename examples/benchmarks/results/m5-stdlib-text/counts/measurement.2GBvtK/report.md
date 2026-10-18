# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_set | normal | rune | O2 | compile | 1/1 | 3.240000000 | 3.240000000 to 3.240000000 | - |
| bytes_set | normal | rune | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| bytes_set | normal | rune | O2 | count | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | 14680361/16159688/403589 |
| bytes_set | normal | rune:opt | O2 | compile | 1/1 | 4.170000000 | 4.170000000 to 4.170000000 | - |
| bytes_set | normal | rune:opt | O2 | native-compile | 1/1 | 0.940000000 | 0.940000000 to 0.940000000 | - |
| bytes_set | normal | rune:opt | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| bytes_set | normal | rune:opt | O2 | count | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | 14680361/16159688/403589 |
| bytes_set | normal | rune:new | O2 | compile | 1/1 | 3.290000000 | 3.290000000 to 3.290000000 | - |
| bytes_set | normal | rune:new | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| bytes_set | normal | rune:new | O2 | count | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | 10054952/16159688/403589 |
| bytes_set | normal | rune:jit | O2 | compile | 1/1 | 3.920000000 | 3.920000000 to 3.920000000 | - |
| bytes_set | normal | rune:jit | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| bytes_set | normal | rune:jit | O2 | count | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | 10054952/16159688/403589 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

