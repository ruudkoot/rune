# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_global_replace | normal | rune | O2 | compile | 1/1 | 2.540000000 | 2.540000000 to 2.540000000 | - |
| str_global_replace | normal | rune | O2 | correctness | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | - |
| str_global_replace | normal | rune | O2 | count | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | 128149291/6469864/46559 |
| str_global_replace | normal | rune:opt | O2 | compile | 1/1 | 2.880000000 | 2.880000000 to 2.880000000 | - |
| str_global_replace | normal | rune:opt | O2 | native-compile | 1/1 | 0.730000000 | 0.730000000 to 0.730000000 | - |
| str_global_replace | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| str_global_replace | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 128149291/6469864/46559 |
| str_global_replace | normal | rune:new | O2 | compile | 1/1 | 2.550000000 | 2.550000000 to 2.550000000 | - |
| str_global_replace | normal | rune:new | O2 | correctness | 1/1 | 0.640000000 | 0.640000000 to 0.640000000 | - |
| str_global_replace | normal | rune:new | O2 | count | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | 66400887/6469864/46559 |
| str_global_replace | normal | rune:jit | O2 | compile | 1/1 | 3.150000000 | 3.150000000 to 3.150000000 | - |
| str_global_replace | normal | rune:jit | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| str_global_replace | normal | rune:jit | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 66400887/6469864/46559 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

