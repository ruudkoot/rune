# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| mergesort | normal | rune | O2 | compile | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | - |
| mergesort | normal | rune | O2 | correctness | 1/1 | 2.150000000 | 2.150000000 to 2.150000000 | - |
| mergesort | normal | rune | O2 | count | 1/1 | 1.950000000 | 1.950000000 to 1.950000000 | 279740820/129641504/2592172 |
| mergesort | normal | rune:opt | O2 | compile | 1/1 | 2.120000000 | 2.120000000 to 2.120000000 | - |
| mergesort | normal | rune:opt | O2 | native-compile | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| mergesort | normal | rune:opt | O2 | correctness | 1/1 | 0.740000000 | 0.740000000 to 0.740000000 | - |
| mergesort | normal | rune:opt | O2 | count | 1/1 | 0.760000000 | 0.760000000 to 0.760000000 | 279740820/129641504/2592172 |
| mergesort | normal | rune:new | O2 | compile | 1/1 | 3.130000000 | 3.130000000 to 3.130000000 | - |
| mergesort | normal | rune:new | O2 | correctness | 1/1 | 1.560000000 | 1.560000000 to 1.560000000 | - |
| mergesort | normal | rune:new | O2 | count | 1/1 | 1.460000000 | 1.460000000 to 1.460000000 | 160360793/129641504/2592172 |
| mergesort | normal | rune:jit | O2 | compile | 1/1 | 2.290000000 | 2.290000000 to 2.290000000 | - |
| mergesort | normal | rune:jit | O2 | correctness | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| mergesort | normal | rune:jit | O2 | count | 1/1 | 0.710000000 | 0.710000000 to 0.710000000 | 160360793/129641504/2592172 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

