# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fft-sandmark | normal | rune | O2 | compile | 1/1 | 1.210000000 | 1.210000000 to 1.210000000 | - |
| fft-sandmark | normal | rune | O2 | correctness | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | - |
| fft-sandmark | normal | rune | O2 | count | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | 50775204/47338824/1098265 |
| fft-sandmark | normal | rune:opt | O2 | compile | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | - |
| fft-sandmark | normal | rune:opt | O2 | native-compile | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| fft-sandmark | normal | rune:opt | O2 | correctness | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| fft-sandmark | normal | rune:opt | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 50775204/47338824/1098265 |
| fft-sandmark | normal | rune:new | O2 | compile | 1/1 | 1.180000000 | 1.180000000 to 1.180000000 | - |
| fft-sandmark | normal | rune:new | O2 | correctness | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | - |
| fft-sandmark | normal | rune:new | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 27520604/47338824/1098265 |
| fft-sandmark | normal | rune:jit | O2 | compile | 1/1 | 1.120000000 | 1.120000000 to 1.120000000 | - |
| fft-sandmark | normal | rune:jit | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| fft-sandmark | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 27520604/47338824/1098265 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

