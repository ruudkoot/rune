# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| contrast | normal | rune | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| contrast | normal | rune | O2 | correctness | 1/1 | 23.030000000 | 23.030000000 to 23.030000000 | - |
| contrast | normal | rune | O2 | count | 1/1 | 20.580000000 | 20.580000000 to 20.580000000 | 5244606692/7049198328/156185779 |
| contrast | normal | rune:opt | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| contrast | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| contrast | normal | rune:opt | O2 | correctness | 1/1 | 10.040000000 | 10.040000000 to 10.040000000 | - |
| contrast | normal | rune:opt | O2 | count | 1/1 | 8.690000000 | 8.690000000 to 8.690000000 | 5244606692/7049198328/156185779 |
| contrast | normal | rune:new | O2 | compile | 1/1 | 2.290000000 | 2.290000000 to 2.290000000 | - |
| contrast | normal | rune:new | O2 | correctness | 1/1 | 20.100000000 | 20.100000000 to 20.100000000 | - |
| contrast | normal | rune:new | O2 | count | 1/1 | 16.830000000 | 16.830000000 to 16.830000000 | 3038274517/7049198328/156185779 |
| contrast | normal | rune:jit | O2 | compile | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | - |
| contrast | normal | rune:jit | O2 | correctness | 1/1 | 7.060000000 | 7.060000000 to 7.060000000 | - |
| contrast | normal | rune:jit | O2 | count | 1/1 | 8.210000000 | 8.210000000 to 8.210000000 | 3038274517/7049198328/156185779 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

