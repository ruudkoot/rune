# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mandel-old-lazy | normal | rune | O2 | compile | 1/1 | 1.490000000 | 1.490000000 to 1.490000000 | - |
| mandel-old-lazy | normal | rune | O2 | correctness | 1/1 | 1.150000000 | 1.150000000 to 1.150000000 | - |
| mandel-old-lazy | normal | rune | O2 | count | 1/1 | 1.360000000 | 1.360000000 to 1.360000000 | 226287223/407669496/11823153 |
| mandel-old-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.420000000 | 3.420000000 to 3.420000000 | - |
| mandel-old-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| mandel-old-lazy | normal | rune:opt | O2 | correctness | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| mandel-old-lazy | normal | rune:opt | O2 | count | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | 226287223/407669496/11823153 |
| mandel-old-lazy | normal | rune:new | O2 | compile | 1/1 | 1.810000000 | 1.810000000 to 1.810000000 | - |
| mandel-old-lazy | normal | rune:new | O2 | correctness | 1/1 | 1.080000000 | 1.080000000 to 1.080000000 | - |
| mandel-old-lazy | normal | rune:new | O2 | count | 1/1 | 0.930000000 | 0.930000000 to 0.930000000 | 134879862/407669496/11823153 |
| mandel-old-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.700000000 | 1.700000000 to 1.700000000 | - |
| mandel-old-lazy | normal | rune:jit | O2 | correctness | 1/1 | 0.450000000 | 0.450000000 to 0.450000000 | - |
| mandel-old-lazy | normal | rune:jit | O2 | count | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | 134879862/407669496/11823153 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

