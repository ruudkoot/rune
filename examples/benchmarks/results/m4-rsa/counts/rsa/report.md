# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| rsa-lazy | normal | rune | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| rsa-lazy | normal | rune | O2 | correctness | 1/1 | 206.470000000 | 206.470000000 to 206.470000000 | - |
| rsa-lazy | normal | rune | O2 | count | 1/1 | 194.440000000 | 194.440000000 to 194.440000000 | 52550033696/73384617288/1835227713 |
| rsa-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| rsa-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| rsa-lazy | normal | rune:opt | O2 | correctness | 1/1 | 91.600000000 | 91.600000000 to 91.600000000 | - |
| rsa-lazy | normal | rune:opt | O2 | count | 1/1 | 92.370000000 | 92.370000000 to 92.370000000 | 52550033696/73384617288/1835227713 |
| rsa-lazy | normal | rune:new | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| rsa-lazy | normal | rune:new | O2 | correctness | 1/1 | 199.980000000 | 199.980000000 to 199.980000000 | - |
| rsa-lazy | normal | rune:new | O2 | count | 1/1 | 178.590000000 | 178.590000000 to 178.590000000 | 29515479631/73384617288/1835227713 |
| rsa-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.000000000 | 2.000000000 to 2.000000000 | - |
| rsa-lazy | normal | rune:jit | O2 | correctness | 1/1 | 80.050000000 | 80.050000000 to 80.050000000 | - |
| rsa-lazy | normal | rune:jit | O2 | count | 1/1 | 77.420000000 | 77.420000000 to 77.420000000 | 29515479631/73384617288/1835227713 |
| rsa-strict | normal | rune | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| rsa-strict | normal | rune | O2 | correctness | 1/1 | 223.000000000 | 223.000000000 to 223.000000000 | - |
| rsa-strict | normal | rune | O2 | count | 1/1 | 196.590000000 | 196.590000000 to 196.590000000 | 52549741134/73384005360/1835210570 |
| rsa-strict | normal | rune:opt | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| rsa-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| rsa-strict | normal | rune:opt | O2 | correctness | 1/1 | 83.760000000 | 83.760000000 to 83.760000000 | - |
| rsa-strict | normal | rune:opt | O2 | count | 1/1 | 81.540000000 | 81.540000000 to 81.540000000 | 52549741134/73384005360/1835210570 |
| rsa-strict | normal | rune:new | O2 | compile | 1/1 | 1.410000000 | 1.410000000 to 1.410000000 | - |
| rsa-strict | normal | rune:new | O2 | correctness | 1/1 | 149.060000000 | 149.060000000 to 149.060000000 | - |
| rsa-strict | normal | rune:new | O2 | count | 1/1 | 149.520000000 | 149.520000000 to 149.520000000 | 29515311869/73384005360/1835210570 |
| rsa-strict | normal | rune:jit | O2 | compile | 1/1 | 1.530000000 | 1.530000000 to 1.530000000 | - |
| rsa-strict | normal | rune:jit | O2 | correctness | 1/1 | 66.970000000 | 66.970000000 to 66.970000000 | - |
| rsa-strict | normal | rune:jit | O2 | count | 1/1 | 65.500000000 | 65.500000000 to 65.500000000 | 29515311869/73384005360/1835210570 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

