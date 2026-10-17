# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lambda-monad-strict | normal | rune | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| lambda-monad-strict | normal | rune | O2 | correctness | 1/1 | 5.670000000 | 5.670000000 to 5.670000000 | - |
| lambda-monad-strict | normal | rune | O2 | count | 1/1 | 5.370000000 | 5.370000000 to 5.370000000 | 977626812/2378963192/59328079 |
| lambda-monad-strict | normal | rune:opt | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| lambda-monad-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| lambda-monad-strict | normal | rune:opt | O2 | correctness | 1/1 | 2.400000000 | 2.400000000 to 2.400000000 | - |
| lambda-monad-strict | normal | rune:opt | O2 | count | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | 977626812/2378963192/59328079 |
| lambda-monad-strict | normal | rune:new | O2 | compile | 1/1 | 1.600000000 | 1.600000000 to 1.600000000 | - |
| lambda-monad-strict | normal | rune:new | O2 | correctness | 1/1 | 5.880000000 | 5.880000000 to 5.880000000 | - |
| lambda-monad-strict | normal | rune:new | O2 | count | 1/1 | 6.680000000 | 6.680000000 to 6.680000000 | 481143510/2378963192/59328079 |
| lambda-monad-strict | normal | rune:jit | O2 | compile | 1/1 | 2.320000000 | 2.320000000 to 2.320000000 | - |
| lambda-monad-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.680000000 | 2.680000000 to 2.680000000 | - |
| lambda-monad-strict | normal | rune:jit | O2 | count | 1/1 | 2.690000000 | 2.690000000 to 2.690000000 | 481143510/2378963192/59328079 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

