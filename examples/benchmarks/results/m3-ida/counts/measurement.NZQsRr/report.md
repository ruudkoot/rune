# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| ida-strict | normal | rune | O2 | compile | 1/1 | 3.860000000 | 3.860000000 to 3.860000000 | - |
| ida-strict | normal | rune | O2 | correctness | 1/1 | 62.080000000 | 62.080000000 to 62.080000000 | - |
| ida-strict | normal | rune | O2 | count | 1/1 | 45.010000000 | 45.010000000 to 45.010000000 | 3731302834/10203091992/298778427 |
| ida-strict | normal | rune:opt | O2 | compile | 1/1 | 3.600000000 | 3.600000000 to 3.600000000 | - |
| ida-strict | normal | rune:opt | O2 | native-compile | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | - |
| ida-strict | normal | rune:opt | O2 | correctness | 1/1 | 25.400000000 | 25.400000000 to 25.400000000 | - |
| ida-strict | normal | rune:opt | O2 | count | 1/1 | 21.780000000 | 21.780000000 to 21.780000000 | 3731302834/10203091992/298778427 |
| ida-strict | normal | rune:new | O2 | compile | 1/1 | 3.390000000 | 3.390000000 to 3.390000000 | - |
| ida-strict | normal | rune:new | O2 | correctness | 1/1 | 55.430000000 | 55.430000000 to 55.430000000 | - |
| ida-strict | normal | rune:new | O2 | count | 1/1 | 48.940000000 | 48.940000000 to 48.940000000 | 2155129090/10203091992/298778427 |
| ida-strict | normal | rune:jit | O2 | compile | 1/1 | 2.960000000 | 2.960000000 to 2.960000000 | - |
| ida-strict | normal | rune:jit | O2 | correctness | 1/1 | 21.560000000 | 21.560000000 to 21.560000000 | - |
| ida-strict | normal | rune:jit | O2 | count | 1/1 | 19.490000000 | 19.490000000 to 19.490000000 | 2155129090/10203091992/298778427 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

