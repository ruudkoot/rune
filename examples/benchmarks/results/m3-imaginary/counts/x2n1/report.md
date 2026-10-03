# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| x2n1-lazy | normal | rune | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| x2n1-lazy | normal | rune | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| x2n1-lazy | normal | rune | O2 | count | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | 8891804/10348632/278739 |
| x2n1-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | - |
| x2n1-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| x2n1-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| x2n1-lazy | normal | rune:opt | O2 | count | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | 8891804/10348632/278739 |
| x2n1-lazy | normal | rune:new | O2 | compile | 1/1 | 1.570000000 | 1.570000000 to 1.570000000 | - |
| x2n1-lazy | normal | rune:new | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| x2n1-lazy | normal | rune:new | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 4857472/10348632/278739 |
| x2n1-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| x2n1-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| x2n1-lazy | normal | rune:jit | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 4857472/10348632/278739 |
| x2n1-strict | normal | rune | O2 | compile | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | - |
| x2n1-strict | normal | rune | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| x2n1-strict | normal | rune | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 8231801/7948440/198733 |
| x2n1-strict | normal | rune:opt | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| x2n1-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| x2n1-strict | normal | rune:opt | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| x2n1-strict | normal | rune:opt | O2 | count | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | 8231801/7948440/198733 |
| x2n1-strict | normal | rune:new | O2 | compile | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |
| x2n1-strict | normal | rune:new | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| x2n1-strict | normal | rune:new | O2 | count | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | 4407472/7948440/198733 |
| x2n1-strict | normal | rune:jit | O2 | compile | 1/1 | 1.710000000 | 1.710000000 to 1.710000000 | - |
| x2n1-strict | normal | rune:jit | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| x2n1-strict | normal | rune:jit | O2 | count | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | 4407472/7948440/198733 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

