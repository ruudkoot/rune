# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hpg-lazy | normal | rune | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| hpg-lazy | normal | rune | O2 | correctness | 1/1 | 98.180000000 | 98.180000000 to 98.180000000 | - |
| hpg-lazy | normal | rune | O2 | count | 1/1 | 96.430000000 | 96.430000000 to 96.430000000 | 11546153901/33198172848/1036606672 |
| hpg-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| hpg-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | - |
| hpg-lazy | normal | rune:opt | O2 | correctness | 1/1 | 43.380000000 | 43.380000000 to 43.380000000 | - |
| hpg-lazy | normal | rune:opt | O2 | count | 1/1 | 51.100000000 | 51.100000000 to 51.100000000 | 11546153901/33198172848/1036606672 |
| hpg-lazy | normal | rune:new | O2 | compile | 1/1 | 4.040000000 | 4.040000000 to 4.040000000 | - |
| hpg-lazy | normal | rune:new | O2 | correctness | 1/1 | 101.470000000 | 101.470000000 to 101.470000000 | - |
| hpg-lazy | normal | rune:new | O2 | count | 1/1 | 103.110000000 | 103.110000000 to 103.110000000 | 6976076967/33198172848/1036606672 |
| hpg-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.780000000 | 3.780000000 to 3.780000000 | - |
| hpg-lazy | normal | rune:jit | O2 | correctness | 1/1 | 52.540000000 | 52.540000000 to 52.540000000 | - |
| hpg-lazy | normal | rune:jit | O2 | count | 1/1 | 45.220000000 | 45.220000000 to 45.220000000 | 6976076967/33198172848/1036606672 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

