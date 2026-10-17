# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| prolog-lazy | normal | rune | O2 | compile | 1/1 | 1.800000000 | 1.800000000 to 1.800000000 | - |
| prolog-lazy | normal | rune | O2 | correctness | 1/1 | 37.760000000 | 37.760000000 to 37.760000000 | - |
| prolog-lazy | normal | rune | O2 | count | 1/1 | 36.080000000 | 36.080000000 to 36.080000000 | 5889099991/21340559704/641566741 |
| prolog-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.760000000 | 1.760000000 to 1.760000000 | - |
| prolog-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| prolog-lazy | normal | rune:opt | O2 | correctness | 1/1 | 21.160000000 | 21.160000000 to 21.160000000 | - |
| prolog-lazy | normal | rune:opt | O2 | count | 1/1 | 18.450000000 | 18.450000000 to 18.450000000 | 5889099991/21340559704/641566741 |
| prolog-lazy | normal | rune:new | O2 | compile | 1/1 | 1.640000000 | 1.640000000 to 1.640000000 | - |
| prolog-lazy | normal | rune:new | O2 | correctness | 1/1 | 35.540000000 | 35.540000000 to 35.540000000 | - |
| prolog-lazy | normal | rune:new | O2 | count | 1/1 | 33.850000000 | 33.850000000 to 33.850000000 | 3490037513/21340559704/641566741 |
| prolog-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.700000000 | 1.700000000 to 1.700000000 | - |
| prolog-lazy | normal | rune:jit | O2 | correctness | 1/1 | 18.090000000 | 18.090000000 to 18.090000000 | - |
| prolog-lazy | normal | rune:jit | O2 | count | 1/1 | 15.750000000 | 15.750000000 to 15.750000000 | 3490037513/21340559704/641566741 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

