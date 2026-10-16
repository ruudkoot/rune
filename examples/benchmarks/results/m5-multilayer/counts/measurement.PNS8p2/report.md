# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| naive-multilayer | normal | rune | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| naive-multilayer | normal | rune | O2 | correctness | 1/1 | 2.550000000 | 2.550000000 to 2.550000000 | - |
| naive-multilayer | normal | rune | O2 | count | 1/1 | 2.820000000 | 2.820000000 to 2.820000000 | 553975116/1505704136/33641007 |
| naive-multilayer | normal | rune:opt | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| naive-multilayer | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| naive-multilayer | normal | rune:opt | O2 | correctness | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| naive-multilayer | normal | rune:opt | O2 | count | 1/1 | 1.250000000 | 1.250000000 to 1.250000000 | 553975116/1505704136/33641007 |
| naive-multilayer | normal | rune:new | O2 | compile | 1/1 | 1.720000000 | 1.720000000 to 1.720000000 | - |
| naive-multilayer | normal | rune:new | O2 | correctness | 1/1 | 2.650000000 | 2.650000000 to 2.650000000 | - |
| naive-multilayer | normal | rune:new | O2 | count | 1/1 | 2.620000000 | 2.620000000 to 2.620000000 | 380096282/1505704136/33641007 |
| naive-multilayer | normal | rune:jit | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| naive-multilayer | normal | rune:jit | O2 | correctness | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| naive-multilayer | normal | rune:jit | O2 | count | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | 380096282/1505704136/33641007 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

