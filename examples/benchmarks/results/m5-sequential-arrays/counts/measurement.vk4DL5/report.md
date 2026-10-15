# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| quicksort | normal | rune | O2 | compile | 1/1 | 2.250000000 | 2.250000000 to 2.250000000 | - |
| quicksort | normal | rune | O2 | correctness | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | - |
| quicksort | normal | rune | O2 | count | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | 106881501/43079016/889833 |
| quicksort | normal | rune:opt | O2 | compile | 1/1 | 2.170000000 | 2.170000000 to 2.170000000 | - |
| quicksort | normal | rune:opt | O2 | native-compile | 1/1 | 0.640000000 | 0.640000000 to 0.640000000 | - |
| quicksort | normal | rune:opt | O2 | correctness | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |
| quicksort | normal | rune:opt | O2 | count | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | 106881501/43079016/889833 |
| quicksort | normal | rune:new | O2 | compile | 1/1 | 2.110000000 | 2.110000000 to 2.110000000 | - |
| quicksort | normal | rune:new | O2 | correctness | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| quicksort | normal | rune:new | O2 | count | 1/1 | 0.610000000 | 0.610000000 to 0.610000000 | 65752796/43079016/889833 |
| quicksort | normal | rune:jit | O2 | compile | 1/1 | 2.200000000 | 2.200000000 to 2.200000000 | - |
| quicksort | normal | rune:jit | O2 | correctness | 1/1 | 0.290000000 | 0.290000000 to 0.290000000 | - |
| quicksort | normal | rune:jit | O2 | count | 1/1 | 0.340000000 | 0.340000000 to 0.340000000 | 65752796/43079016/889833 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

