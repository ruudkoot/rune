# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hash | normal | rune | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| hash | normal | rune | O2 | correctness | 1/1 | 0.670000000 | 0.670000000 to 0.670000000 | - |
| hash | normal | rune | O2 | count | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | 167854247/174320064/4554774 |
| hash | normal | rune:opt | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| hash | normal | rune:opt | O2 | native-compile | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| hash | normal | rune:opt | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| hash | normal | rune:opt | O2 | count | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | 167854247/174320064/4554774 |
| hash | normal | rune:new | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| hash | normal | rune:new | O2 | correctness | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| hash | normal | rune:new | O2 | count | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | 95392874/174320064/4554774 |
| hash | normal | rune:jit | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| hash | normal | rune:jit | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| hash | normal | rune:jit | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 95392874/174320064/4554774 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

