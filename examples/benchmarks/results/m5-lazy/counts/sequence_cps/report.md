# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sequence_cps | normal | rune | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| sequence_cps | normal | rune | O2 | correctness | 1/1 | 4.400000000 | 4.400000000 to 4.400000000 | - |
| sequence_cps | normal | rune | O2 | count | 1/1 | 4.590000000 | 4.590000000 to 4.590000000 | 938489746/2096398328/49599177 |
| sequence_cps | normal | rune:opt | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| sequence_cps | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| sequence_cps | normal | rune:opt | O2 | correctness | 1/1 | 1.750000000 | 1.750000000 to 1.750000000 | - |
| sequence_cps | normal | rune:opt | O2 | count | 1/1 | 2.140000000 | 2.140000000 to 2.140000000 | 938489746/2096398328/49599177 |
| sequence_cps | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| sequence_cps | normal | rune:new | O2 | correctness | 1/1 | 3.900000000 | 3.900000000 to 3.900000000 | - |
| sequence_cps | normal | rune:new | O2 | count | 1/1 | 3.780000000 | 3.780000000 to 3.780000000 | 580688139/2096398328/49599177 |
| sequence_cps | normal | rune:jit | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| sequence_cps | normal | rune:jit | O2 | correctness | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| sequence_cps | normal | rune:jit | O2 | count | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | 580688139/2096398328/49599177 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

