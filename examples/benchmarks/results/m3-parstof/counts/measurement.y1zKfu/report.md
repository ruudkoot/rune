# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| parstof-strict | normal | rune | O2 | compile | 1/1 | 3.050000000 | 3.050000000 to 3.050000000 | - |
| parstof-strict | normal | rune | O2 | correctness | 1/1 | 27.190000000 | 27.190000000 to 27.190000000 | - |
| parstof-strict | normal | rune | O2 | count | 1/1 | 31.280000000 | 31.280000000 to 31.280000000 | 3420315792/3258565288/95047955 |
| parstof-strict | normal | rune:opt | O2 | compile | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| parstof-strict | normal | rune:opt | O2 | native-compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| parstof-strict | normal | rune:opt | O2 | correctness | 1/1 | 12.800000000 | 12.800000000 to 12.800000000 | - |
| parstof-strict | normal | rune:opt | O2 | count | 1/1 | 14.160000000 | 14.160000000 to 14.160000000 | 3420315792/3258565288/95047955 |
| parstof-strict | normal | rune:new | O2 | compile | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| parstof-strict | normal | rune:new | O2 | correctness | 1/1 | 25.860000000 | 25.860000000 to 25.860000000 | - |
| parstof-strict | normal | rune:new | O2 | count | 1/1 | 23.440000000 | 23.440000000 to 23.440000000 | 1932813179/3258565288/95047955 |
| parstof-strict | normal | rune:jit | O2 | compile | 1/1 | 3.100000000 | 3.100000000 to 3.100000000 | - |
| parstof-strict | normal | rune:jit | O2 | correctness | 1/1 | 13.150000000 | 13.150000000 to 13.150000000 | - |
| parstof-strict | normal | rune:jit | O2 | count | 1/1 | 11.580000000 | 11.580000000 to 11.580000000 | 1932813179/3258565288/95047955 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

