# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_blit | normal | rune | O2 | compile | 1/1 | 4.070000000 | 4.070000000 to 4.070000000 | - |
| bytes_blit | normal | rune | O2 | correctness | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| bytes_blit | normal | rune | O2 | count | 1/1 | 0.770000000 | 0.770000000 to 0.770000000 | 78063889/128058312/2681283 |
| bytes_blit | normal | rune:opt | O2 | compile | 1/1 | 4.990000000 | 4.990000000 to 4.990000000 | - |
| bytes_blit | normal | rune:opt | O2 | native-compile | 1/1 | 0.860000000 | 0.860000000 to 0.860000000 | - |
| bytes_blit | normal | rune:opt | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| bytes_blit | normal | rune:opt | O2 | count | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | 78063889/128058312/2681283 |
| bytes_blit | normal | rune:new | O2 | compile | 1/1 | 4.090000000 | 4.090000000 to 4.090000000 | - |
| bytes_blit | normal | rune:new | O2 | correctness | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| bytes_blit | normal | rune:new | O2 | count | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | 55575210/128058312/2681283 |
| bytes_blit | normal | rune:jit | O2 | compile | 1/1 | 4.540000000 | 4.540000000 to 4.540000000 | - |
| bytes_blit | normal | rune:jit | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| bytes_blit | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 55575210/128058312/2681283 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

