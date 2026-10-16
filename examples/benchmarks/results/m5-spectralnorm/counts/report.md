# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| spectralnorm2 | normal | rune | O2 | compile | 1/1 | 3.380000000 | 3.380000000 to 3.380000000 | - |
| spectralnorm2 | normal | rune | O2 | correctness | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| spectralnorm2 | normal | rune | O2 | count | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | 107871743/1099904/21166 |
| spectralnorm2 | normal | rune:opt | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| spectralnorm2 | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| spectralnorm2 | normal | rune:opt | O2 | correctness | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| spectralnorm2 | normal | rune:opt | O2 | count | 1/1 | 0.210000000 | 0.210000000 to 0.210000000 | 107871743/1099904/21166 |
| spectralnorm2 | normal | rune:new | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| spectralnorm2 | normal | rune:new | O2 | correctness | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| spectralnorm2 | normal | rune:new | O2 | count | 1/1 | 0.570000000 | 0.570000000 to 0.570000000 | 82816409/1099904/21166 |
| spectralnorm2 | normal | rune:jit | O2 | compile | 1/1 | 1.880000000 | 1.880000000 to 1.880000000 | - |
| spectralnorm2 | normal | rune:jit | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| spectralnorm2 | normal | rune:jit | O2 | count | 1/1 | 0.200000000 | 0.200000000 to 0.200000000 | 82816409/1099904/21166 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

