# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| compress2-strict | normal | rune | O2 | compile | 1/1 | 1.420000000 | 1.420000000 to 1.420000000 | - |
| compress2-strict | normal | rune | O2 | correctness | 1/1 | 25.430000000 | 25.430000000 to 25.430000000 | - |
| compress2-strict | normal | rune | O2 | count | 1/1 | 27.720000000 | 27.720000000 to 27.720000000 | 5274890603/18715996576/466692440 |
| compress2-strict | normal | rune:opt | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| compress2-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| compress2-strict | normal | rune:opt | O2 | correctness | 1/1 | 14.410000000 | 14.410000000 to 14.410000000 | - |
| compress2-strict | normal | rune:opt | O2 | count | 1/1 | 15.740000000 | 15.740000000 to 15.740000000 | 5274890603/18715996576/466692440 |
| compress2-strict | normal | rune:new | O2 | compile | 1/1 | 1.500000000 | 1.500000000 to 1.500000000 | - |
| compress2-strict | normal | rune:new | O2 | correctness | 1/1 | 29.340000000 | 29.340000000 to 29.340000000 | - |
| compress2-strict | normal | rune:new | O2 | count | 1/1 | 27.830000000 | 27.830000000 to 27.830000000 | 3120212170/18715996576/466692440 |
| compress2-strict | normal | rune:jit | O2 | compile | 1/1 | 1.520000000 | 1.520000000 to 1.520000000 | - |
| compress2-strict | normal | rune:jit | O2 | correctness | 1/1 | 14.090000000 | 14.090000000 to 14.090000000 | - |
| compress2-strict | normal | rune:jit | O2 | count | 1/1 | 16.290000000 | 16.290000000 to 16.290000000 | 3120212170/18715996576/466692440 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

