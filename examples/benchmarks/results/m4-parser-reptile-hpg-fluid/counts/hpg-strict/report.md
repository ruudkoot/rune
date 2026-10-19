# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hpg-strict | normal | rune | O2 | compile | 1/1 | 5.190000000 | 5.190000000 to 5.190000000 | - |
| hpg-strict | normal | rune | O2 | correctness | 1/1 | 87.740000000 | 87.740000000 to 87.740000000 | - |
| hpg-strict | normal | rune | O2 | count | 1/1 | 96.640000000 | 96.640000000 to 96.640000000 | 11118183948/31745510776/986931787 |
| hpg-strict | normal | rune:opt | O2 | compile | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| hpg-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| hpg-strict | normal | rune:opt | O2 | correctness | 1/1 | 43.140000000 | 43.140000000 to 43.140000000 | - |
| hpg-strict | normal | rune:opt | O2 | count | 1/1 | 47.410000000 | 47.410000000 to 47.410000000 | 11118183948/31745510776/986931787 |
| hpg-strict | normal | rune:new | O2 | compile | 1/1 | 3.020000000 | 3.020000000 to 3.020000000 | - |
| hpg-strict | normal | rune:new | O2 | correctness | 1/1 | 99.070000000 | 99.070000000 to 99.070000000 | - |
| hpg-strict | normal | rune:new | O2 | count | 1/1 | 92.670000000 | 92.670000000 to 92.670000000 | 6719103018/31745510776/986931787 |
| hpg-strict | normal | rune:jit | O2 | compile | 1/1 | 3.670000000 | 3.670000000 to 3.670000000 | - |
| hpg-strict | normal | rune:jit | O2 | correctness | 1/1 | 41.250000000 | 41.250000000 to 41.250000000 | - |
| hpg-strict | normal | rune:jit | O2 | count | 1/1 | 43.400000000 | 43.400000000 to 43.400000000 | 6719103018/31745510776/986931787 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

