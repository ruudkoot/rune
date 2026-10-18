# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-strict | normal | rune | O2 | compile | 1/1 | 3.760000000 | 3.760000000 to 3.760000000 | - |
| simple-nofib-strict | normal | rune | O2 | correctness | 1/1 | 49.520000000 | 49.520000000 to 49.520000000 | - |
| simple-nofib-strict | normal | rune | O2 | count | 1/1 | 49.520000000 | 49.520000000 to 49.520000000 | 6608563994/6757585112/166100677 |
| simple-nofib-strict | normal | rune:opt | O2 | compile | 1/1 | 5.080000000 | 5.080000000 to 5.080000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | correctness | 1/1 | 12.370000000 | 12.370000000 to 12.370000000 | - |
| simple-nofib-strict | normal | rune:opt | O2 | count | 1/1 | 11.560000000 | 11.560000000 to 11.560000000 | 6608563994/6757585112/166100677 |
| simple-nofib-strict | normal | rune:new | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | correctness | 1/1 | 26.560000000 | 26.560000000 to 26.560000000 | - |
| simple-nofib-strict | normal | rune:new | O2 | count | 1/1 | 27.180000000 | 27.180000000 to 27.180000000 | 3450185752/6757585112/166100677 |
| simple-nofib-strict | normal | rune:jit | O2 | compile | 1/1 | 2.040000000 | 2.040000000 to 2.040000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | correctness | 1/1 | 10.780000000 | 10.780000000 to 10.780000000 | - |
| simple-nofib-strict | normal | rune:jit | O2 | count | 1/1 | 12.630000000 | 12.630000000 to 12.630000000 | 3450185752/6757585112/166100677 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

