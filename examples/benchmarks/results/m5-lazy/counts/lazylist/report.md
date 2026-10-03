# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lazylist | normal | rune | O2 | compile | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| lazylist | normal | rune | O2 | correctness | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| lazylist | normal | rune | O2 | count | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | 253327605/1284710584/40134607 |
| lazylist | normal | rune:opt | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| lazylist | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| lazylist | normal | rune:opt | O2 | correctness | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| lazylist | normal | rune:opt | O2 | count | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | 253327605/1284710584/40134607 |
| lazylist | normal | rune:new | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| lazylist | normal | rune:new | O2 | correctness | 1/1 | 1.430000000 | 1.430000000 to 1.430000000 | - |
| lazylist | normal | rune:new | O2 | count | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | 181965653/1284710584/40134607 |
| lazylist | normal | rune:jit | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| lazylist | normal | rune:jit | O2 | correctness | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | - |
| lazylist | normal | rune:jit | O2 | count | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | 181965653/1284710584/40134607 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

