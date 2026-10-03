# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| reverse-complement | normal | rune | O2 | compile | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| reverse-complement | normal | rune | O2 | correctness | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| reverse-complement | normal | rune | O2 | count | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | 74253977/54443248/786188 |
| reverse-complement | normal | rune:opt | O2 | compile | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| reverse-complement | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| reverse-complement | normal | rune:opt | O2 | correctness | 1/1 | 0.180000000 | 0.180000000 to 0.180000000 | - |
| reverse-complement | normal | rune:opt | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 74253977/54443248/786188 |
| reverse-complement | normal | rune:new | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| reverse-complement | normal | rune:new | O2 | correctness | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| reverse-complement | normal | rune:new | O2 | count | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | 38901105/54443248/786188 |
| reverse-complement | normal | rune:jit | O2 | compile | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| reverse-complement | normal | rune:jit | O2 | correctness | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | - |
| reverse-complement | normal | rune:jit | O2 | count | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | 38901105/54443248/786188 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

