# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| str_search_forward | normal | rune | O2 | compile | 1/1 | 3.610000000 | 3.610000000 to 3.610000000 | - |
| str_search_forward | normal | rune | O2 | correctness | 1/1 | 0.350000000 | 0.350000000 to 0.350000000 | - |
| str_search_forward | normal | rune | O2 | count | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | 49533271/581864/18559 |
| str_search_forward | normal | rune:opt | O2 | compile | 1/1 | 3.340000000 | 3.340000000 to 3.340000000 | - |
| str_search_forward | normal | rune:opt | O2 | native-compile | 1/1 | 0.910000000 | 0.910000000 to 0.910000000 | - |
| str_search_forward | normal | rune:opt | O2 | correctness | 1/1 | 0.070000000 | 0.070000000 to 0.070000000 | - |
| str_search_forward | normal | rune:opt | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 49533271/581864/18559 |
| str_search_forward | normal | rune:new | O2 | compile | 1/1 | 2.420000000 | 2.420000000 to 2.420000000 | - |
| str_search_forward | normal | rune:new | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| str_search_forward | normal | rune:new | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 23164872/581864/18559 |
| str_search_forward | normal | rune:jit | O2 | compile | 1/1 | 2.330000000 | 2.330000000 to 2.330000000 | - |
| str_search_forward | normal | rune:jit | O2 | correctness | 1/1 | 0.110000000 | 0.110000000 to 0.110000000 | - |
| str_search_forward | normal | rune:jit | O2 | count | 1/1 | 0.080000000 | 0.080000000 to 0.080000000 | 23164872/581864/18559 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

