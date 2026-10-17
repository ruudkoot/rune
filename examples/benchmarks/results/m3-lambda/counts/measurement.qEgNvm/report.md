# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lambda-simple-strict | normal | rune | O2 | compile | 1/1 | 1.850000000 | 1.850000000 to 1.850000000 | - |
| lambda-simple-strict | normal | rune | O2 | correctness | 1/1 | 3.780000000 | 3.780000000 to 3.780000000 | - |
| lambda-simple-strict | normal | rune | O2 | count | 1/1 | 3.410000000 | 3.410000000 to 3.410000000 | 629286626/173561616/7022280 |
| lambda-simple-strict | normal | rune:opt | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| lambda-simple-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| lambda-simple-strict | normal | rune:opt | O2 | correctness | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| lambda-simple-strict | normal | rune:opt | O2 | count | 1/1 | 1.440000000 | 1.440000000 to 1.440000000 | 629286626/173561616/7022280 |
| lambda-simple-strict | normal | rune:new | O2 | compile | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| lambda-simple-strict | normal | rune:new | O2 | correctness | 1/1 | 3.520000000 | 3.520000000 to 3.520000000 | - |
| lambda-simple-strict | normal | rune:new | O2 | count | 1/1 | 2.760000000 | 2.760000000 to 2.760000000 | 309138020/173561616/7022280 |
| lambda-simple-strict | normal | rune:jit | O2 | compile | 1/1 | 1.450000000 | 1.450000000 to 1.450000000 | - |
| lambda-simple-strict | normal | rune:jit | O2 | correctness | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| lambda-simple-strict | normal | rune:jit | O2 | count | 1/1 | 1.190000000 | 1.190000000 to 1.190000000 | 309138020/173561616/7022280 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

