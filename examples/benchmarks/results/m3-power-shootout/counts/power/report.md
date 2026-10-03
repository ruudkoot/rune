# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| power | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| power | normal | rune | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| power | normal | rune | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 10915103/19228448/549044 |
| power | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| power | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| power | normal | rune:opt | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| power | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 10915103/19228448/549044 |
| power | normal | rune:new | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| power | normal | rune:new | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| power | normal | rune:new | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 6463254/19228448/549044 |
| power | normal | rune:jit | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| power | normal | rune:jit | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| power | normal | rune:jit | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 6463254/19228448/549044 |
| power-nofib | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| power-nofib | normal | rune | O2 | correctness | 1/1 | 19.430000000 | 19.430000000 to 19.430000000 | - |
| power-nofib | normal | rune | O2 | count | 1/1 | 19.110000000 | 19.110000000 to 19.110000000 | 3743653753/6271354232/178104495 |
| power-nofib | normal | rune:opt | O2 | compile | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| power-nofib | normal | rune:opt | O2 | native-compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| power-nofib | normal | rune:opt | O2 | correctness | 1/1 | 8.230000000 | 8.230000000 to 8.230000000 | - |
| power-nofib | normal | rune:opt | O2 | count | 1/1 | 8.350000000 | 8.350000000 to 8.350000000 | 3743653753/6271354232/178104495 |
| power-nofib | normal | rune:new | O2 | compile | 1/1 | 1.980000000 | 1.980000000 to 1.980000000 | - |
| power-nofib | normal | rune:new | O2 | correctness | 1/1 | 18.090000000 | 18.090000000 to 18.090000000 | - |
| power-nofib | normal | rune:new | O2 | count | 1/1 | 19.370000000 | 19.370000000 to 19.370000000 | 2216782451/6271354232/178104495 |
| power-nofib | normal | rune:jit | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| power-nofib | normal | rune:jit | O2 | correctness | 1/1 | 7.230000000 | 7.230000000 to 7.230000000 | - |
| power-nofib | normal | rune:jit | O2 | count | 1/1 | 7.610000000 | 7.610000000 to 7.610000000 | 2216782451/6271354232/178104495 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

