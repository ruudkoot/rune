# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_cat | normal | rune | O2 | compile | 1/1 | 3.700000000 | 3.700000000 to 3.700000000 | - |
| bytes_cat | normal | rune | O2 | correctness | 1/1 | 1.290000000 | 1.290000000 to 1.290000000 | - |
| bytes_cat | normal | rune | O2 | count | 1/1 | 1.740000000 | 1.740000000 to 1.740000000 | 138548005/225274912/4693294 |
| bytes_cat | normal | rune:opt | O2 | compile | 1/1 | 3.490000000 | 3.490000000 to 3.490000000 | - |
| bytes_cat | normal | rune:opt | O2 | native-compile | 1/1 | 2.710000000 | 2.710000000 to 2.710000000 | - |
| bytes_cat | normal | rune:opt | O2 | correctness | 1/1 | 0.540000000 | 0.540000000 to 0.540000000 | - |
| bytes_cat | normal | rune:opt | O2 | count | 1/1 | 0.690000000 | 0.690000000 to 0.690000000 | 138548005/225274912/4693294 |
| bytes_cat | normal | rune:new | O2 | compile | 1/1 | 3.560000000 | 3.560000000 to 3.560000000 | - |
| bytes_cat | normal | rune:new | O2 | correctness | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| bytes_cat | normal | rune:new | O2 | count | 1/1 | 1.860000000 | 1.860000000 to 1.860000000 | 98567289/225274912/4693294 |
| bytes_cat | normal | rune:jit | O2 | compile | 1/1 | 3.370000000 | 3.370000000 to 3.370000000 | - |
| bytes_cat | normal | rune:jit | O2 | correctness | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| bytes_cat | normal | rune:jit | O2 | count | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | 98567289/225274912/4693294 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

