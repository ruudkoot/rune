# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pic-strict | normal | rune | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| pic-strict | normal | rune | O2 | correctness | 1/1 | 10.160000000 | 10.160000000 to 10.160000000 | - |
| pic-strict | normal | rune | O2 | count | 1/1 | 12.570000000 | 12.570000000 to 12.570000000 | 3060158435/5410569512/122807271 |
| pic-strict | normal | rune:opt | O2 | compile | 1/1 | 1.350000000 | 1.350000000 to 1.350000000 | - |
| pic-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| pic-strict | normal | rune:opt | O2 | correctness | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| pic-strict | normal | rune:opt | O2 | count | 1/1 | 3.540000000 | 3.540000000 to 3.540000000 | 3060158435/5410569512/122807271 |
| pic-strict | normal | rune:new | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| pic-strict | normal | rune:new | O2 | correctness | 1/1 | 8.650000000 | 8.650000000 to 8.650000000 | - |
| pic-strict | normal | rune:new | O2 | count | 1/1 | 11.810000000 | 11.810000000 to 11.810000000 | 1616212130/5410569512/122807271 |
| pic-strict | normal | rune:jit | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| pic-strict | normal | rune:jit | O2 | correctness | 1/1 | 2.890000000 | 2.890000000 to 2.890000000 | - |
| pic-strict | normal | rune:jit | O2 | count | 1/1 | 3.360000000 | 3.360000000 to 3.360000000 | 1616212130/5410569512/122807271 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

