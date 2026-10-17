# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fft2-lazy | normal | rune | O2 | compile | 1/1 | 1.990000000 | 1.990000000 to 1.990000000 | - |
| fft2-lazy | normal | rune | O2 | correctness | 1/1 | 85.380000000 | 85.380000000 to 85.380000000 | - |
| fft2-lazy | normal | rune | O2 | count | 1/1 | 82.970000000 | 82.970000000 to 82.970000000 | 13232018406/21093409776/641090466 |
| fft2-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.790000000 | 1.790000000 to 1.790000000 | - |
| fft2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| fft2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 41.390000000 | 41.390000000 to 41.390000000 | - |
| fft2-lazy | normal | rune:opt | O2 | count | 1/1 | 37.980000000 | 37.980000000 to 37.980000000 | 13232018406/21093409776/641090466 |
| fft2-lazy | normal | rune:new | O2 | compile | 1/1 | 1.630000000 | 1.630000000 to 1.630000000 | - |
| fft2-lazy | normal | rune:new | O2 | correctness | 1/1 | 70.350000000 | 70.350000000 to 70.350000000 | - |
| fft2-lazy | normal | rune:new | O2 | count | 1/1 | 65.630000000 | 65.630000000 to 65.630000000 | 7960361425/21093409776/641090466 |
| fft2-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| fft2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 34.510000000 | 34.510000000 to 34.510000000 | - |
| fft2-lazy | normal | rune:jit | O2 | count | 1/1 | 52.720000000 | 52.720000000 to 52.720000000 | 7960361425/21093409776/641090466 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

