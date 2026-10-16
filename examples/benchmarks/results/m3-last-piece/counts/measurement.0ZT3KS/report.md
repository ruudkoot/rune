# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| last-piece-strict | normal | rune | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| last-piece-strict | normal | rune | O2 | correctness | 1/1 | 3.650000000 | 3.650000000 to 3.650000000 | - |
| last-piece-strict | normal | rune | O2 | count | 1/1 | 3.770000000 | 3.770000000 to 3.770000000 | 1024954488/850582848/12694286 |
| last-piece-strict | normal | rune:opt | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| last-piece-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| last-piece-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| last-piece-strict | normal | rune:opt | O2 | count | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | 1024954488/850582848/12694286 |
| last-piece-strict | normal | rune:new | O2 | compile | 1/1 | 3.590000000 | 3.590000000 to 3.590000000 | - |
| last-piece-strict | normal | rune:new | O2 | correctness | 1/1 | 4.170000000 | 4.170000000 to 4.170000000 | - |
| last-piece-strict | normal | rune:new | O2 | count | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | 421360052/850582848/12694286 |
| last-piece-strict | normal | rune:jit | O2 | compile | 1/1 | 1.650000000 | 1.650000000 to 1.650000000 | - |
| last-piece-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.550000000 | 1.550000000 to 1.550000000 | - |
| last-piece-strict | normal | rune:jit | O2 | count | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | 421360052/850582848/12694286 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

