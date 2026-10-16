# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| wang-strict | normal | rune | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| wang-strict | normal | rune | O2 | correctness | 1/1 | 16.600000000 | 16.600000000 to 16.600000000 | - |
| wang-strict | normal | rune | O2 | count | 1/1 | 13.080000000 | 13.080000000 to 13.080000000 | 3344825462/10620352976/317067062 |
| wang-strict | normal | rune:opt | O2 | compile | 1/1 | 1.230000000 | 1.230000000 to 1.230000000 | - |
| wang-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| wang-strict | normal | rune:opt | O2 | correctness | 1/1 | 6.410000000 | 6.410000000 to 6.410000000 | - |
| wang-strict | normal | rune:opt | O2 | count | 1/1 | 6.980000000 | 6.980000000 to 6.980000000 | 3344825462/10620352976/317067062 |
| wang-strict | normal | rune:new | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| wang-strict | normal | rune:new | O2 | correctness | 1/1 | 18.080000000 | 18.080000000 to 18.080000000 | - |
| wang-strict | normal | rune:new | O2 | count | 1/1 | 18.200000000 | 18.200000000 to 18.200000000 | 2009634686/10620352976/317067062 |
| wang-strict | normal | rune:jit | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| wang-strict | normal | rune:jit | O2 | correctness | 1/1 | 8.400000000 | 8.400000000 to 8.400000000 | - |
| wang-strict | normal | rune:jit | O2 | count | 1/1 | 7.960000000 | 7.960000000 to 7.960000000 | 2009634686/10620352976/317067062 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

