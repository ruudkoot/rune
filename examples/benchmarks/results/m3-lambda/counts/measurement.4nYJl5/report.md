# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lambda-monad-lazy | normal | rune | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| lambda-monad-lazy | normal | rune | O2 | correctness | 1/1 | 15.730000000 | 15.730000000 to 15.730000000 | - |
| lambda-monad-lazy | normal | rune | O2 | count | 1/1 | 15.430000000 | 15.430000000 to 15.430000000 | 2684296633/7449975496/224387377 |
| lambda-monad-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| lambda-monad-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| lambda-monad-lazy | normal | rune:opt | O2 | correctness | 1/1 | 8.830000000 | 8.830000000 to 8.830000000 | - |
| lambda-monad-lazy | normal | rune:opt | O2 | count | 1/1 | 10.010000000 | 10.010000000 to 10.010000000 | 2684296633/7449975496/224387377 |
| lambda-monad-lazy | normal | rune:new | O2 | compile | 1/1 | 2.300000000 | 2.300000000 to 2.300000000 | - |
| lambda-monad-lazy | normal | rune:new | O2 | correctness | 1/1 | 22.240000000 | 22.240000000 to 22.240000000 | - |
| lambda-monad-lazy | normal | rune:new | O2 | count | 1/1 | 20.390000000 | 20.390000000 to 20.390000000 | 1497932125/7449975496/224387377 |
| lambda-monad-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| lambda-monad-lazy | normal | rune:jit | O2 | correctness | 1/1 | 7.680000000 | 7.680000000 to 7.680000000 | - |
| lambda-monad-lazy | normal | rune:jit | O2 | count | 1/1 | 7.730000000 | 7.730000000 to 7.730000000 | 1497932125/7449975496/224387377 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

