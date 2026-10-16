# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| listcopy-lazy | normal | rune | O2 | compile | 1/1 | 1.340000000 | 1.340000000 to 1.340000000 | - |
| listcopy-lazy | normal | rune | O2 | correctness | 1/1 | 5.650000000 | 5.650000000 to 5.650000000 | - |
| listcopy-lazy | normal | rune | O2 | count | 1/1 | 5.110000000 | 5.110000000 to 5.110000000 | 667845818/2507996096/75572256 |
| listcopy-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| listcopy-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| listcopy-lazy | normal | rune:opt | O2 | correctness | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| listcopy-lazy | normal | rune:opt | O2 | count | 1/1 | 3.460000000 | 3.460000000 to 3.460000000 | 667845818/2507996096/75572256 |
| listcopy-lazy | normal | rune:new | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| listcopy-lazy | normal | rune:new | O2 | correctness | 1/1 | 6.740000000 | 6.740000000 to 6.740000000 | - |
| listcopy-lazy | normal | rune:new | O2 | count | 1/1 | 5.230000000 | 5.230000000 to 5.230000000 | 407884691/2507996096/75572256 |
| listcopy-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| listcopy-lazy | normal | rune:jit | O2 | correctness | 1/1 | 3.530000000 | 3.530000000 to 3.530000000 | - |
| listcopy-lazy | normal | rune:jit | O2 | count | 1/1 | 3.410000000 | 3.410000000 to 3.410000000 | 407884691/2507996096/75572256 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

