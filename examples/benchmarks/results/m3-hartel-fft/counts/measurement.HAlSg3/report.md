# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fft-nofib-strict | normal | rune | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| fft-nofib-strict | normal | rune | O2 | correctness | 1/1 | 2.840000000 | 2.840000000 to 2.840000000 | - |
| fft-nofib-strict | normal | rune | O2 | count | 1/1 | 3.440000000 | 3.440000000 to 3.440000000 | 687654415/925891648/21606594 |
| fft-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 1.590000000 | 1.590000000 to 1.590000000 | - |
| fft-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| fft-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.090000000 | 1.090000000 to 1.090000000 | - |
| fft-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 1.110000000 | 1.110000000 to 1.110000000 | 687654415/925891648/21606594 |
| fft-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| fft-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 2.870000000 | 2.870000000 to 2.870000000 | - |
| fft-nofib-strict | normal | rune:new | O2 | count | 1/1 | 2.990000000 | 2.990000000 to 2.990000000 | 370202790/925891648/21606594 |
| fft-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 1.790000000 | 1.790000000 to 1.790000000 | - |
| fft-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 3.190000000 | 3.190000000 to 3.190000000 | - |
| fft-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 0.930000000 | 0.930000000 to 0.930000000 | 370202790/925891648/21606594 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

