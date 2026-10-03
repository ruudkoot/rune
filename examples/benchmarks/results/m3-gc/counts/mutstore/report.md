# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mutstore1 | normal | rune | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| mutstore1 | normal | rune | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| mutstore1 | normal | rune | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 2847430/4531304/110503 |
| mutstore1 | normal | rune:opt | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| mutstore1 | normal | rune:opt | O2 | native-compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| mutstore1 | normal | rune:opt | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| mutstore1 | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 2847430/4531304/110503 |
| mutstore1 | normal | rune:new | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| mutstore1 | normal | rune:new | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| mutstore1 | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 1718334/4531304/110503 |
| mutstore1 | normal | rune:jit | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| mutstore1 | normal | rune:jit | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| mutstore1 | normal | rune:jit | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 1718334/4531304/110503 |
| mutstore2 | normal | rune | O2 | compile | 1/1 | 1.790000000 | 1.790000000 to 1.790000000 | - |
| mutstore2 | normal | rune | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| mutstore2 | normal | rune | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 2606428/3891304/90503 |
| mutstore2 | normal | rune:opt | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| mutstore2 | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| mutstore2 | normal | rune:opt | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| mutstore2 | normal | rune:opt | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 2606428/3891304/90503 |
| mutstore2 | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| mutstore2 | normal | rune:new | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| mutstore2 | normal | rune:new | O2 | count | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | 1634332/3891304/90503 |
| mutstore2 | normal | rune:jit | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| mutstore2 | normal | rune:jit | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| mutstore2 | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 1634332/3891304/90503 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

