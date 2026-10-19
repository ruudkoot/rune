# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| veritas-strict | normal | rune | O2 | compile | 1/1 | 14.470000000 | 14.470000000 to 14.470000000 | - |
| veritas-strict | normal | rune | O2 | correctness | 1/1 | 22.150000000 | 22.150000000 to 22.150000000 | - |
| veritas-strict | normal | rune | O2 | count | 1/1 | 20.380000000 | 20.380000000 to 20.380000000 | 2152605410/7279952776/202523857 |
| veritas-strict | normal | rune:opt | O2 | compile | 1/1 | 11.430000000 | 11.430000000 to 11.430000000 | - |
| veritas-strict | normal | rune:opt | O2 | native-compile | 1/1 | 2.100000000 | 2.100000000 to 2.100000000 | - |
| veritas-strict | normal | rune:opt | O2 | correctness | 1/1 | 9.350000000 | 9.350000000 to 9.350000000 | - |
| veritas-strict | normal | rune:opt | O2 | count | 1/1 | 8.920000000 | 8.920000000 to 8.920000000 | 2152605410/7279952776/202523857 |
| veritas-strict | normal | rune:new | O2 | compile | 1/1 | 12.350000000 | 12.350000000 to 12.350000000 | - |
| veritas-strict | normal | rune:new | O2 | correctness | 1/1 | 18.190000000 | 18.190000000 to 18.190000000 | - |
| veritas-strict | normal | rune:new | O2 | count | 1/1 | 21.080000000 | 21.080000000 to 21.080000000 | 1283234714/7279952776/202523857 |
| veritas-strict | normal | rune:jit | O2 | compile | 1/1 | 14.270000000 | 14.270000000 to 14.270000000 | - |
| veritas-strict | normal | rune:jit | O2 | correctness | 1/1 | 11.390000000 | 11.390000000 to 11.390000000 | - |
| veritas-strict | normal | rune:jit | O2 | count | 1/1 | 11.200000000 | 11.200000000 to 11.200000000 | 1283234714/7279952776/202523857 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

