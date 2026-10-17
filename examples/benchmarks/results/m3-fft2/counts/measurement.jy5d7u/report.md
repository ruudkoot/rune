# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fft2-strict | normal | rune | O2 | compile | 1/1 | 3.600000000 | 3.600000000 to 3.600000000 | - |
| fft2-strict | normal | rune | O2 | correctness | 1/1 | 89.950000000 | 89.950000000 to 89.950000000 | - |
| fft2-strict | normal | rune | O2 | count | 1/1 | 69.950000000 | 69.950000000 to 69.950000000 | 11528719466/15526652656/475038906 |
| fft2-strict | normal | rune:opt | O2 | compile | 1/1 | 2.470000000 | 2.470000000 to 2.470000000 | - |
| fft2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| fft2-strict | normal | rune:opt | O2 | correctness | 1/1 | 36.940000000 | 36.940000000 to 36.940000000 | - |
| fft2-strict | normal | rune:opt | O2 | count | 1/1 | 32.250000000 | 32.250000000 to 32.250000000 | 11528719466/15526652656/475038906 |
| fft2-strict | normal | rune:new | O2 | compile | 1/1 | 2.370000000 | 2.370000000 to 2.370000000 | - |
| fft2-strict | normal | rune:new | O2 | correctness | 1/1 | 71.830000000 | 71.830000000 to 71.830000000 | - |
| fft2-strict | normal | rune:new | O2 | count | 1/1 | 72.350000000 | 72.350000000 to 72.350000000 | 6896149741/15526652656/475038906 |
| fft2-strict | normal | rune:jit | O2 | compile | 1/1 | 2.410000000 | 2.410000000 to 2.410000000 | - |
| fft2-strict | normal | rune:jit | O2 | correctness | 1/1 | 31.940000000 | 31.940000000 to 31.940000000 | - |
| fft2-strict | normal | rune:jit | O2 | count | 1/1 | 28.510000000 | 28.510000000 to 28.510000000 | 6896149741/15526652656/475038906 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

