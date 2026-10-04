# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hamming | normal | rune | O2 | compile | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| hamming | normal | rune | O2 | correctness | 1/1 | 34.810000000 | 34.810000000 to 34.810000000 | - |
| hamming | normal | rune | O2 | count | 1/1 | 29.820000000 | 29.820000000 to 29.820000000 | 5161420848/5327153384/133525705 |
| hamming | normal | rune:opt | O2 | compile | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | - |
| hamming | normal | rune:opt | O2 | native-compile | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| hamming | normal | rune:opt | O2 | correctness | 1/1 | 11.860000000 | 11.860000000 to 11.860000000 | - |
| hamming | normal | rune:opt | O2 | count | 1/1 | 19.050000000 | 19.050000000 to 19.050000000 | 5161420848/5327153384/133525705 |
| hamming | normal | rune:new | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| hamming | normal | rune:new | O2 | correctness | 1/1 | 26.370000000 | 26.370000000 to 26.370000000 | - |
| hamming | normal | rune:new | O2 | count | 1/1 | 23.920000000 | 23.920000000 to 23.920000000 | 2970405110/5327153384/133525705 |
| hamming | normal | rune:jit | O2 | compile | 1/1 | 1.280000000 | 1.280000000 to 1.280000000 | - |
| hamming | normal | rune:jit | O2 | correctness | 1/1 | 7.330000000 | 7.330000000 to 7.330000000 | - |
| hamming | normal | rune:jit | O2 | count | 1/1 | 7.310000000 | 7.310000000 to 7.310000000 | 2970405110/5327153384/133525705 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

