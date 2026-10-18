# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| map_add_duplicate | normal | rune | O2 | compile | 1/1 | 4.130000000 | 4.130000000 to 4.130000000 | - |
| map_add_duplicate | normal | rune | O2 | correctness | 1/1 | 3.330000000 | 3.330000000 to 3.330000000 | - |
| map_add_duplicate | normal | rune | O2 | count | 1/1 | 2.730000000 | 2.730000000 to 2.730000000 | 310411575/239898264/4255511 |
| map_add_duplicate | normal | rune:opt | O2 | compile | 1/1 | 4.550000000 | 4.550000000 to 4.550000000 | - |
| map_add_duplicate | normal | rune:opt | O2 | native-compile | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | - |
| map_add_duplicate | normal | rune:opt | O2 | correctness | 1/1 | 1.270000000 | 1.270000000 to 1.270000000 | - |
| map_add_duplicate | normal | rune:opt | O2 | count | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | 310411575/239898264/4255511 |
| map_add_duplicate | normal | rune:new | O2 | compile | 1/1 | 3.550000000 | 3.550000000 to 3.550000000 | - |
| map_add_duplicate | normal | rune:new | O2 | correctness | 1/1 | 2.750000000 | 2.750000000 to 2.750000000 | - |
| map_add_duplicate | normal | rune:new | O2 | count | 1/1 | 2.380000000 | 2.380000000 to 2.380000000 | 160924006/239898264/4255511 |
| map_add_duplicate | normal | rune:jit | O2 | compile | 1/1 | 3.190000000 | 3.190000000 to 3.190000000 | - |
| map_add_duplicate | normal | rune:jit | O2 | correctness | 1/1 | 1.160000000 | 1.160000000 to 1.160000000 | - |
| map_add_duplicate | normal | rune:jit | O2 | count | 1/1 | 1.170000000 | 1.170000000 to 1.170000000 | 160924006/239898264/4255511 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

