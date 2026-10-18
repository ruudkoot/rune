# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_split | normal | rune | O2 | compile | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| str_split | normal | rune | O2 | correctness | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | - |
| str_split | normal | rune | O2 | count | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | 129298432/1572424/14523 |
| str_split | normal | rune:opt | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| str_split | normal | rune:opt | O2 | native-compile | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| str_split | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| str_split | normal | rune:opt | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 129298432/1572424/14523 |
| str_split | normal | rune:new | O2 | compile | 1/1 | 2.520000000 | 2.520000000 to 2.520000000 | - |
| str_split | normal | rune:new | O2 | correctness | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| str_split | normal | rune:new | O2 | count | 1/1 | 0.640000000 | 0.640000000 to 0.640000000 | 67000362/1572424/14523 |
| str_split | normal | rune:jit | O2 | compile | 1/1 | 2.280000000 | 2.280000000 to 2.280000000 | - |
| str_split | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| str_split | normal | rune:jit | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 67000362/1572424/14523 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

