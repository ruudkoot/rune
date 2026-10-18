# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_uppercase_ascii | normal | rune | O2 | compile | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | - |
| string_uppercase_ascii | normal | rune | O2 | correctness | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | - |
| string_uppercase_ascii | normal | rune | O2 | count | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | 94706725/93162208/2302706 |
| string_uppercase_ascii | normal | rune:opt | O2 | compile | 1/1 | 2.590000000 | 2.590000000 to 2.590000000 | - |
| string_uppercase_ascii | normal | rune:opt | O2 | native-compile | 1/1 | 0.530000000 | 0.530000000 to 0.530000000 | - |
| string_uppercase_ascii | normal | rune:opt | O2 | correctness | 1/1 | 0.250000000 | 0.250000000 to 0.250000000 | - |
| string_uppercase_ascii | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 94706725/93162208/2302706 |
| string_uppercase_ascii | normal | rune:new | O2 | compile | 1/1 | 2.460000000 | 2.460000000 to 2.460000000 | - |
| string_uppercase_ascii | normal | rune:new | O2 | correctness | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| string_uppercase_ascii | normal | rune:new | O2 | count | 1/1 | 0.630000000 | 0.630000000 to 0.630000000 | 62470641/93162208/2302706 |
| string_uppercase_ascii | normal | rune:jit | O2 | compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| string_uppercase_ascii | normal | rune:jit | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| string_uppercase_ascii | normal | rune:jit | O2 | count | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | 62470641/93162208/2302706 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

