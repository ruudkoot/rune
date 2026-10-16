# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| circsim-strict | normal | rune | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| circsim-strict | normal | rune | O2 | correctness | 1/1 | 7.600000000 | 7.600000000 to 7.600000000 | - |
| circsim-strict | normal | rune | O2 | count | 1/1 | 9.830000000 | 9.830000000 to 9.830000000 | 2141709856/5239130120/98780173 |
| circsim-strict | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| circsim-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| circsim-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.090000000 | 3.090000000 to 3.090000000 | - |
| circsim-strict | normal | rune:opt | O2 | count | 1/1 | 3.040000000 | 3.040000000 to 3.040000000 | 2141709856/5239130120/98780173 |
| circsim-strict | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| circsim-strict | normal | rune:new | O2 | correctness | 1/1 | 6.370000000 | 6.370000000 to 6.370000000 | - |
| circsim-strict | normal | rune:new | O2 | count | 1/1 | 6.640000000 | 6.640000000 to 6.640000000 | 1041358780/5239130120/98780173 |
| circsim-strict | normal | rune:jit | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| circsim-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.770000000 | 2.770000000 to 2.770000000 | - |
| circsim-strict | normal | rune:jit | O2 | count | 1/1 | 5.160000000 | 5.160000000 to 5.160000000 | 1041358780/5239130120/98780173 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

