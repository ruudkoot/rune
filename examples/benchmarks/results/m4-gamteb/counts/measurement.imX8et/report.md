# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| gamteb-lazy | normal | rune | O2 | compile | 1/1 | 1.890000000 | 1.890000000 to 1.890000000 | - |
| gamteb-lazy | normal | rune | O2 | correctness | 1/1 | 22.820000000 | 22.820000000 to 22.820000000 | - |
| gamteb-lazy | normal | rune | O2 | count | 1/1 | 20.690000000 | 20.690000000 to 20.690000000 | 3702968401/8153046392/229878465 |
| gamteb-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.130000000 | 4.130000000 to 4.130000000 | - |
| gamteb-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| gamteb-lazy | normal | rune:opt | O2 | correctness | 1/1 | 9.860000000 | 9.860000000 to 9.860000000 | - |
| gamteb-lazy | normal | rune:opt | O2 | count | 1/1 | 9.670000000 | 9.670000000 to 9.670000000 | 3702968401/8153046392/229878465 |
| gamteb-lazy | normal | rune:new | O2 | compile | 1/1 | 1.870000000 | 1.870000000 to 1.870000000 | - |
| gamteb-lazy | normal | rune:new | O2 | correctness | 1/1 | 21.020000000 | 21.020000000 to 21.020000000 | - |
| gamteb-lazy | normal | rune:new | O2 | count | 1/1 | 18.440000000 | 18.440000000 to 18.440000000 | 2312964491/8153046392/229878465 |
| gamteb-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.830000000 | 1.830000000 to 1.830000000 | - |
| gamteb-lazy | normal | rune:jit | O2 | correctness | 1/1 | 12.180000000 | 12.180000000 to 12.180000000 | - |
| gamteb-lazy | normal | rune:jit | O2 | count | 1/1 | 9.590000000 | 9.590000000 to 9.590000000 | 2312964491/8153046392/229878465 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

