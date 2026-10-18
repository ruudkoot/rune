# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| wave4main-strict | normal | rune | O2 | compile | 1/1 | 1.670000000 | 1.670000000 to 1.670000000 | - |
| wave4main-strict | normal | rune | O2 | correctness | 1/1 | 14.320000000 | 14.320000000 to 14.320000000 | - |
| wave4main-strict | normal | rune | O2 | count | 1/1 | 14.870000000 | 14.870000000 to 14.870000000 | 3403612024/950685904/18376772 |
| wave4main-strict | normal | rune:opt | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| wave4main-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| wave4main-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.950000000 | 3.950000000 to 3.950000000 | - |
| wave4main-strict | normal | rune:opt | O2 | count | 1/1 | 4.010000000 | 4.010000000 to 4.010000000 | 3403612024/950685904/18376772 |
| wave4main-strict | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| wave4main-strict | normal | rune:new | O2 | correctness | 1/1 | 9.410000000 | 9.410000000 to 9.410000000 | - |
| wave4main-strict | normal | rune:new | O2 | count | 1/1 | 9.550000000 | 9.550000000 to 9.550000000 | 1630597982/950685904/18376772 |
| wave4main-strict | normal | rune:jit | O2 | compile | 1/1 | 1.310000000 | 1.310000000 to 1.310000000 | - |
| wave4main-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.330000000 | 2.330000000 to 2.330000000 | - |
| wave4main-strict | normal | rune:jit | O2 | count | 1/1 | 2.400000000 | 2.400000000 to 2.400000000 | 1630597982/950685904/18376772 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

