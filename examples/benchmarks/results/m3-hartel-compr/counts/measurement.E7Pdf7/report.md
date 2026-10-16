# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| listcopy-strict | normal | rune | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| listcopy-strict | normal | rune | O2 | correctness | 1/1 | 4.620000000 | 4.620000000 to 4.620000000 | - |
| listcopy-strict | normal | rune | O2 | count | 1/1 | 4.730000000 | 4.730000000 to 4.730000000 | 646870604/2437132432/73407724 |
| listcopy-strict | normal | rune:opt | O2 | compile | 1/1 | 3.250000000 | 3.250000000 to 3.250000000 | - |
| listcopy-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| listcopy-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.490000000 | 3.490000000 to 3.490000000 | - |
| listcopy-strict | normal | rune:opt | O2 | count | 1/1 | 3.520000000 | 3.520000000 to 3.520000000 | 646870604/2437132432/73407724 |
| listcopy-strict | normal | rune:new | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| listcopy-strict | normal | rune:new | O2 | correctness | 1/1 | 4.920000000 | 4.920000000 to 4.920000000 | - |
| listcopy-strict | normal | rune:new | O2 | count | 1/1 | 5.170000000 | 5.170000000 to 5.170000000 | 395538720/2437132432/73407724 |
| listcopy-strict | normal | rune:jit | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| listcopy-strict | normal | rune:jit | O2 | correctness | 1/1 | 3.260000000 | 3.260000000 to 3.260000000 | - |
| listcopy-strict | normal | rune:jit | O2 | count | 1/1 | 3.290000000 | 3.290000000 to 3.290000000 | 395538720/2437132432/73407724 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

