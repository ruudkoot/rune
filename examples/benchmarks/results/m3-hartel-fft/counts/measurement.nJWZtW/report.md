# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fft-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| fft-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 12.420000000 | 12.420000000 to 12.420000000 | - |
| fft-nofib-lazy | normal | rune | O2 | count | 1/1 | 10.380000000 | 10.380000000 to 10.380000000 | 1859364844/5044804752/146636054 |
| fft-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.620000000 | 1.620000000 to 1.620000000 | - |
| fft-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| fft-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 7.990000000 | 7.990000000 to 7.990000000 | - |
| fft-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 5.520000000 | 5.520000000 to 5.520000000 | 1859364844/5044804752/146636054 |
| fft-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 1.390000000 | 1.390000000 to 1.390000000 | - |
| fft-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 9.770000000 | 9.770000000 to 9.770000000 | - |
| fft-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 9.670000000 | 9.670000000 to 9.670000000 | 1093822633/5044804752/146636054 |
| fft-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.320000000 | 1.320000000 to 1.320000000 | - |
| fft-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 7.660000000 | 7.660000000 to 7.660000000 | - |
| fft-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 4.990000000 | 4.990000000 to 4.990000000 | 1093822633/5044804752/146636054 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

