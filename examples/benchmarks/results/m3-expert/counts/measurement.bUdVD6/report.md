# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| expert-strict | normal | rune | O2 | compile | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | - |
| expert-strict | normal | rune | O2 | correctness | 1/1 | 17.810000000 | 17.810000000 to 17.810000000 | - |
| expert-strict | normal | rune | O2 | count | 1/1 | 18.650000000 | 18.650000000 to 18.650000000 | 2863859474/8050053296/252911408 |
| expert-strict | normal | rune:opt | O2 | compile | 1/1 | 1.960000000 | 1.960000000 to 1.960000000 | - |
| expert-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| expert-strict | normal | rune:opt | O2 | correctness | 1/1 | 7.890000000 | 7.890000000 to 7.890000000 | - |
| expert-strict | normal | rune:opt | O2 | count | 1/1 | 7.770000000 | 7.770000000 to 7.770000000 | 2863859474/8050053296/252911408 |
| expert-strict | normal | rune:new | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| expert-strict | normal | rune:new | O2 | correctness | 1/1 | 15.210000000 | 15.210000000 to 15.210000000 | - |
| expert-strict | normal | rune:new | O2 | count | 1/1 | 15.550000000 | 15.550000000 to 15.550000000 | 1704631817/8050053296/252911408 |
| expert-strict | normal | rune:jit | O2 | compile | 1/1 | 1.910000000 | 1.910000000 to 1.910000000 | - |
| expert-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.850000000 | 6.850000000 to 6.850000000 | - |
| expert-strict | normal | rune:jit | O2 | count | 1/1 | 6.820000000 | 6.820000000 to 6.820000000 | 1704631817/8050053296/252911408 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

