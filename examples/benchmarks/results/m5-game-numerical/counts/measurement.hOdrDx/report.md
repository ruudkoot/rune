# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandelbrot6 | normal | rune | O2 | compile | 1/1 | 1.690000000 | 1.690000000 to 1.690000000 | - |
| mandelbrot6 | normal | rune | O2 | correctness | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| mandelbrot6 | normal | rune | O2 | count | 1/1 | 0.440000000 | 0.440000000 to 0.440000000 | 93976082/10148480/361356 |
| mandelbrot6 | normal | rune:opt | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| mandelbrot6 | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| mandelbrot6 | normal | rune:opt | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| mandelbrot6 | normal | rune:opt | O2 | count | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | 93976082/10148480/361356 |
| mandelbrot6 | normal | rune:new | O2 | compile | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| mandelbrot6 | normal | rune:new | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| mandelbrot6 | normal | rune:new | O2 | count | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | 54297412/10148480/361356 |
| mandelbrot6 | normal | rune:jit | O2 | compile | 1/1 | 1.480000000 | 1.480000000 to 1.480000000 | - |
| mandelbrot6 | normal | rune:jit | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| mandelbrot6 | normal | rune:jit | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 54297412/10148480/361356 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

