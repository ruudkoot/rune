# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| revcomp2 | normal | rune | O2 | compile | 1/1 | 2.010000000 | 2.010000000 to 2.010000000 | - |
| revcomp2 | normal | rune | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| revcomp2 | normal | rune | O2 | count | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | 96413744/169489552/3744886 |
| revcomp2 | normal | rune:opt | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| revcomp2 | normal | rune:opt | O2 | native-compile | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | - |
| revcomp2 | normal | rune:opt | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| revcomp2 | normal | rune:opt | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 96413744/169489552/3744886 |
| revcomp2 | normal | rune:new | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| revcomp2 | normal | rune:new | O2 | correctness | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| revcomp2 | normal | rune:new | O2 | count | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | 58450141/169489552/3744886 |
| revcomp2 | normal | rune:jit | O2 | compile | 1/1 | 1.900000000 | 1.900000000 to 1.900000000 | - |
| revcomp2 | normal | rune:jit | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| revcomp2 | normal | rune:jit | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 58450141/169489552/3744886 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

