# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| string_split_on_char | normal | rune | O2 | compile | 1/1 | 4.360000000 | 4.360000000 to 4.360000000 | - |
| string_split_on_char | normal | rune | O2 | correctness | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| string_split_on_char | normal | rune | O2 | count | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | 48012697/10954208/342706 |
| string_split_on_char | normal | rune:opt | O2 | compile | 1/1 | 3.190000000 | 3.190000000 to 3.190000000 | - |
| string_split_on_char | normal | rune:opt | O2 | native-compile | 1/1 | 0.820000000 | 0.820000000 to 0.820000000 | - |
| string_split_on_char | normal | rune:opt | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| string_split_on_char | normal | rune:opt | O2 | count | 1/1 | 0.140000000 | 0.140000000 to 0.140000000 | 48012697/10954208/342706 |
| string_split_on_char | normal | rune:new | O2 | compile | 1/1 | 3.030000000 | 3.030000000 to 3.030000000 | - |
| string_split_on_char | normal | rune:new | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| string_split_on_char | normal | rune:new | O2 | count | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | 32822623/10954208/342706 |
| string_split_on_char | normal | rune:jit | O2 | compile | 1/1 | 3.490000000 | 3.490000000 to 3.490000000 | - |
| string_split_on_char | normal | rune:jit | O2 | correctness | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | - |
| string_split_on_char | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 32822623/10954208/342706 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

