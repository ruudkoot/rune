# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| genfft-strict | normal | rune | O2 | compile | 1/1 | 3.550000000 | 3.550000000 to 3.550000000 | - |
| genfft-strict | normal | rune | O2 | correctness | 1/1 | 12.090000000 | 12.090000000 to 12.090000000 | - |
| genfft-strict | normal | rune | O2 | count | 1/1 | 11.550000000 | 11.550000000 to 11.550000000 | 2795410922/7059070984/178245725 |
| genfft-strict | normal | rune:opt | O2 | compile | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| genfft-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.260000000 | 0.260000000 to 0.260000000 | - |
| genfft-strict | normal | rune:opt | O2 | correctness | 1/1 | 5.750000000 | 5.750000000 to 5.750000000 | - |
| genfft-strict | normal | rune:opt | O2 | count | 1/1 | 7.600000000 | 7.600000000 to 7.600000000 | 2795410922/7059070984/178245725 |
| genfft-strict | normal | rune:new | O2 | compile | 1/1 | 1.220000000 | 1.220000000 to 1.220000000 | - |
| genfft-strict | normal | rune:new | O2 | correctness | 1/1 | 13.470000000 | 13.470000000 to 13.470000000 | - |
| genfft-strict | normal | rune:new | O2 | count | 1/1 | 14.970000000 | 14.970000000 to 14.970000000 | 1697386791/7059070984/178245725 |
| genfft-strict | normal | rune:jit | O2 | compile | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | - |
| genfft-strict | normal | rune:jit | O2 | correctness | 1/1 | 6.220000000 | 6.220000000 to 6.220000000 | - |
| genfft-strict | normal | rune:jit | O2 | count | 1/1 | 6.200000000 | 6.200000000 to 6.200000000 | 1697386791/7059070984/178245725 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

