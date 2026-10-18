# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nucleic2-shared-strict | normal | rune | O2 | compile | 1/1 | 13.160000000 | 13.160000000 to 13.160000000 | - |
| nucleic2-shared-strict | normal | rune | O2 | correctness | 1/1 | 341.270000000 | 341.270000000 to 341.270000000 | - |
| nucleic2-shared-strict | normal | rune | O2 | count | 1/1 | 287.550000000 | 287.550000000 to 287.550000000 | 42891351171/3005455744/42311608 |
| nucleic2-shared-strict | normal | rune:opt | O2 | compile | 1/1 | 7.770000000 | 7.770000000 to 7.770000000 | - |
| nucleic2-shared-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| nucleic2-shared-strict | normal | rune:opt | O2 | correctness | 1/1 | 136.570000000 | 136.570000000 to 136.570000000 | - |
| nucleic2-shared-strict | normal | rune:opt | O2 | count | 1/1 | 139.440000000 | 139.440000000 to 139.440000000 | 42891351171/3005455744/42311608 |
| nucleic2-shared-strict | normal | rune:new | O2 | compile | 1/1 | 7.050000000 | 7.050000000 to 7.050000000 | - |
| nucleic2-shared-strict | normal | rune:new | O2 | correctness | 1/1 | 295.600000000 | 295.600000000 to 295.600000000 | - |
| nucleic2-shared-strict | normal | rune:new | O2 | count | 1/1 | 213.770000000 | 213.770000000 to 213.770000000 | 26681098137/3005455744/42311608 |
| nucleic2-shared-strict | normal | rune:jit | O2 | compile | 1/1 | 5.540000000 | 5.540000000 to 5.540000000 | - |
| nucleic2-shared-strict | normal | rune:jit | O2 | correctness | 1/1 | 91.210000000 | 91.210000000 to 91.210000000 | - |
| nucleic2-shared-strict | normal | rune:jit | O2 | count | 1/1 | 89.610000000 | 89.610000000 to 89.610000000 | 26681098137/3005455744/42311608 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

