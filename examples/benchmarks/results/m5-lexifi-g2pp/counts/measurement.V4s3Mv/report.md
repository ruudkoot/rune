# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lexifi-g2pp | normal | rune | O2 | compile | 1/1 | 4.040000000 | 4.040000000 to 4.040000000 | - |
| lexifi-g2pp | normal | rune | O2 | correctness | 1/1 | 155.690000000 | 155.690000000 to 155.690000000 | - |
| lexifi-g2pp | normal | rune | O2 | count | 1/1 | 134.020000000 | 134.020000000 to 134.020000000 | 26038765444/3638731424/58600828 |
| lexifi-g2pp | normal | rune:opt | O2 | compile | 1/1 | 4.000000000 | 4.000000000 to 4.000000000 | - |
| lexifi-g2pp | normal | rune:opt | O2 | native-compile | 1/1 | 0.490000000 | 0.490000000 to 0.490000000 | - |
| lexifi-g2pp | normal | rune:opt | O2 | correctness | 1/1 | 51.260000000 | 51.260000000 to 51.260000000 | - |
| lexifi-g2pp | normal | rune:opt | O2 | count | 1/1 | 54.020000000 | 54.020000000 to 54.020000000 | 26038765444/3638731424/58600828 |
| lexifi-g2pp | normal | rune:new | O2 | compile | 1/1 | 2.550000000 | 2.550000000 to 2.550000000 | - |
| lexifi-g2pp | normal | rune:new | O2 | correctness | 1/1 | 114.070000000 | 114.070000000 to 114.070000000 | - |
| lexifi-g2pp | normal | rune:new | O2 | count | 1/1 | 131.280000000 | 131.280000000 to 131.280000000 | 16760772634/3638731424/58600828 |
| lexifi-g2pp | normal | rune:jit | O2 | compile | 1/1 | 3.410000000 | 3.410000000 to 3.410000000 | - |
| lexifi-g2pp | normal | rune:jit | O2 | correctness | 1/1 | 48.000000000 | 48.000000000 to 48.000000000 | - |
| lexifi-g2pp | normal | rune:jit | O2 | count | 1/1 | 40.200000000 | 40.200000000 to 40.200000000 | 16760772634/3638731424/58600828 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

