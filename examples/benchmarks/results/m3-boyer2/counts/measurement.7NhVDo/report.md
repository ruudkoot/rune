# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| boyer2-strict | normal | rune | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| boyer2-strict | normal | rune | O2 | correctness | 1/1 | 71.680000000 | 71.680000000 to 71.680000000 | - |
| boyer2-strict | normal | rune | O2 | count | 1/1 | 72.590000000 | 72.590000000 to 72.590000000 | 20661107833/9553122416/238857194 |
| boyer2-strict | normal | rune:opt | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| boyer2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| boyer2-strict | normal | rune:opt | O2 | correctness | 1/1 | 33.300000000 | 33.300000000 to 33.300000000 | - |
| boyer2-strict | normal | rune:opt | O2 | count | 1/1 | 35.370000000 | 35.370000000 to 35.370000000 | 20661107833/9553122416/238857194 |
| boyer2-strict | normal | rune:new | O2 | compile | 1/1 | 1.200000000 | 1.200000000 to 1.200000000 | - |
| boyer2-strict | normal | rune:new | O2 | correctness | 1/1 | 73.910000000 | 73.910000000 to 73.910000000 | - |
| boyer2-strict | normal | rune:new | O2 | count | 1/1 | 88.790000000 | 88.790000000 to 88.790000000 | 10917129552/9553122416/238857194 |
| boyer2-strict | normal | rune:jit | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| boyer2-strict | normal | rune:jit | O2 | correctness | 1/1 | 28.150000000 | 28.150000000 to 28.150000000 | - |
| boyer2-strict | normal | rune:jit | O2 | count | 1/1 | 27.400000000 | 27.400000000 to 27.400000000 | 10917129552/9553122416/238857194 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

