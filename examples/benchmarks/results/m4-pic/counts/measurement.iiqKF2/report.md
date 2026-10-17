# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| pic-lazy | normal | rune | O2 | compile | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | - |
| pic-lazy | normal | rune | O2 | correctness | 1/1 | 19.420000000 | 19.420000000 to 19.420000000 | - |
| pic-lazy | normal | rune | O2 | count | 1/1 | 14.380000000 | 14.380000000 to 14.380000000 | 3017696529/6534234104/164300295 |
| pic-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| pic-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| pic-lazy | normal | rune:opt | O2 | correctness | 1/1 | 7.210000000 | 7.210000000 to 7.210000000 | - |
| pic-lazy | normal | rune:opt | O2 | count | 1/1 | 8.970000000 | 8.970000000 to 8.970000000 | 3017696529/6534234104/164300295 |
| pic-lazy | normal | rune:new | O2 | compile | 1/1 | 1.580000000 | 1.580000000 to 1.580000000 | - |
| pic-lazy | normal | rune:new | O2 | correctness | 1/1 | 12.930000000 | 12.930000000 to 12.930000000 | - |
| pic-lazy | normal | rune:new | O2 | count | 1/1 | 13.900000000 | 13.900000000 to 13.900000000 | 1684065689/6534234104/164300295 |
| pic-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.970000000 | 1.970000000 to 1.970000000 | - |
| pic-lazy | normal | rune:jit | O2 | correctness | 1/1 | 8.920000000 | 8.920000000 to 8.920000000 | - |
| pic-lazy | normal | rune:jit | O2 | count | 1/1 | 7.170000000 | 7.170000000 to 7.170000000 | 1684065689/6534234104/164300295 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

