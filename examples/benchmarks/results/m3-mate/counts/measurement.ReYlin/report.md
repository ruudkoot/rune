# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mate-strict | normal | rune | O2 | compile | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | - |
| mate-strict | normal | rune | O2 | correctness | 1/1 | 94.770000000 | 94.770000000 to 94.770000000 | - |
| mate-strict | normal | rune | O2 | count | 1/1 | 100.240000000 | 100.240000000 to 100.240000000 | 20212790965/38958092520/1132472251 |
| mate-strict | normal | rune:opt | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| mate-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| mate-strict | normal | rune:opt | O2 | correctness | 1/1 | 45.210000000 | 45.210000000 to 45.210000000 | - |
| mate-strict | normal | rune:opt | O2 | count | 1/1 | 43.060000000 | 43.060000000 to 43.060000000 | 20212790965/38958092520/1132472251 |
| mate-strict | normal | rune:new | O2 | compile | 1/1 | 1.880000000 | 1.880000000 to 1.880000000 | - |
| mate-strict | normal | rune:new | O2 | correctness | 1/1 | 101.580000000 | 101.580000000 to 101.580000000 | - |
| mate-strict | normal | rune:new | O2 | count | 1/1 | 97.490000000 | 97.490000000 to 97.490000000 | 11433416405/38958092520/1132472251 |
| mate-strict | normal | rune:jit | O2 | compile | 1/1 | 1.840000000 | 1.840000000 to 1.840000000 | - |
| mate-strict | normal | rune:jit | O2 | correctness | 1/1 | 40.080000000 | 40.080000000 to 40.080000000 | - |
| mate-strict | normal | rune:jit | O2 | count | 1/1 | 38.500000000 | 38.500000000 to 38.500000000 | 11433416405/38958092520/1132472251 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

