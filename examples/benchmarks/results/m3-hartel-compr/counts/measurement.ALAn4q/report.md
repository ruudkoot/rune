# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| listcompr-lazy | normal | rune | O2 | compile | 1/1 | 1.300000000 | 1.300000000 to 1.300000000 | - |
| listcompr-lazy | normal | rune | O2 | correctness | 1/1 | 5.490000000 | 5.490000000 to 5.490000000 | - |
| listcompr-lazy | normal | rune | O2 | count | 1/1 | 7.430000000 | 7.430000000 to 7.430000000 | 616513796/2317691984/69312252 |
| listcompr-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.700000000 | 1.700000000 to 1.700000000 | - |
| listcompr-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.380000000 | 0.380000000 to 0.380000000 | - |
| listcompr-lazy | normal | rune:opt | O2 | correctness | 1/1 | 3.170000000 | 3.170000000 to 3.170000000 | - |
| listcompr-lazy | normal | rune:opt | O2 | count | 1/1 | 3.300000000 | 3.300000000 to 3.300000000 | 616513796/2317691984/69312252 |
| listcompr-lazy | normal | rune:new | O2 | compile | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| listcompr-lazy | normal | rune:new | O2 | correctness | 1/1 | 4.740000000 | 4.740000000 to 4.740000000 | - |
| listcompr-lazy | normal | rune:new | O2 | count | 1/1 | 5.450000000 | 5.450000000 to 5.450000000 | 376584678/2317691984/69312252 |
| listcompr-lazy | normal | rune:jit | O2 | compile | 1/1 | 1.780000000 | 1.780000000 to 1.780000000 | - |
| listcompr-lazy | normal | rune:jit | O2 | correctness | 1/1 | 3.830000000 | 3.830000000 to 3.830000000 | - |
| listcompr-lazy | normal | rune:jit | O2 | count | 1/1 | 5.300000000 | 5.300000000 to 5.300000000 | 376584678/2317691984/69312252 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

