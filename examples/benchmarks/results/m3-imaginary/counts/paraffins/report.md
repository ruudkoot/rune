# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| paraffins-lazy | normal | rune | O2 | compile | 1/1 | 3.910000000 | 3.910000000 to 3.910000000 | - |
| paraffins-lazy | normal | rune | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| paraffins-lazy | normal | rune | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 822986/2982704/88418 |
| paraffins-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.380000000 | 3.380000000 to 3.380000000 | - |
| paraffins-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| paraffins-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| paraffins-lazy | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 822986/2982704/88418 |
| paraffins-lazy | normal | rune:new | O2 | compile | 1/1 | 3.120000000 | 3.120000000 to 3.120000000 | - |
| paraffins-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| paraffins-lazy | normal | rune:new | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 492282/2982704/88418 |
| paraffins-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.270000000 | 3.270000000 to 3.270000000 | - |
| paraffins-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| paraffins-lazy | normal | rune:jit | O2 | count | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | 492282/2982704/88418 |
| paraffins-strict | normal | rune | O2 | compile | 1/1 | 4.060000000 | 4.060000000 to 4.060000000 | - |
| paraffins-strict | normal | rune | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| paraffins-strict | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 266140/848560/18860 |
| paraffins-strict | normal | rune:opt | O2 | compile | 1/1 | 3.450000000 | 3.450000000 to 3.450000000 | - |
| paraffins-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| paraffins-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| paraffins-strict | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 266140/848560/18860 |
| paraffins-strict | normal | rune:new | O2 | compile | 1/1 | 3.780000000 | 3.780000000 to 3.780000000 | - |
| paraffins-strict | normal | rune:new | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| paraffins-strict | normal | rune:new | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 159342/848560/18860 |
| paraffins-strict | normal | rune:jit | O2 | compile | 1/1 | 4.230000000 | 4.230000000 to 4.230000000 | - |
| paraffins-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| paraffins-strict | normal | rune:jit | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 159342/848560/18860 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

