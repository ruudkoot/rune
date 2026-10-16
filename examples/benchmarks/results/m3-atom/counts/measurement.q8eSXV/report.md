# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| atom-lazy | normal | rune | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| atom-lazy | normal | rune | O2 | correctness | 1/1 | 29.760000000 | 29.760000000 to 29.760000000 | - |
| atom-lazy | normal | rune | O2 | count | 1/1 | 30.940000000 | 30.940000000 to 30.940000000 | 4422453263/10864901000/325379977 |
| atom-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| atom-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| atom-lazy | normal | rune:opt | O2 | correctness | 1/1 | 12.850000000 | 12.850000000 to 12.850000000 | - |
| atom-lazy | normal | rune:opt | O2 | count | 1/1 | 16.540000000 | 16.540000000 to 16.540000000 | 4422453263/10864901000/325379977 |
| atom-lazy | normal | rune:new | O2 | compile | 1/1 | 1.380000000 | 1.380000000 to 1.380000000 | - |
| atom-lazy | normal | rune:new | O2 | correctness | 1/1 | 29.780000000 | 29.780000000 to 29.780000000 | - |
| atom-lazy | normal | rune:new | O2 | count | 1/1 | 26.950000000 | 26.950000000 to 26.950000000 | 2650587129/10864901000/325379977 |
| atom-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.580000000 | 3.580000000 to 3.580000000 | - |
| atom-lazy | normal | rune:jit | O2 | correctness | 1/1 | 13.800000000 | 13.800000000 to 13.800000000 | - |
| atom-lazy | normal | rune:jit | O2 | count | 1/1 | 13.160000000 | 13.160000000 to 13.160000000 | 2650587129/10864901000/325379977 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

