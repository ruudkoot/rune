# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| ida-lazy | normal | rune | O2 | compile | 1/1 | 3.800000000 | 3.800000000 to 3.800000000 | - |
| ida-lazy | normal | rune | O2 | correctness | 1/1 | 82.040000000 | 82.040000000 to 82.040000000 | - |
| ida-lazy | normal | rune | O2 | count | 1/1 | 75.600000000 | 75.600000000 to 75.600000000 | 5193104404/16467274416/512074828 |
| ida-lazy | normal | rune:opt | O2 | compile | 1/1 | 4.680000000 | 4.680000000 to 4.680000000 | - |
| ida-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.790000000 | 0.790000000 to 0.790000000 | - |
| ida-lazy | normal | rune:opt | O2 | correctness | 1/1 | 34.200000000 | 34.200000000 to 34.200000000 | - |
| ida-lazy | normal | rune:opt | O2 | count | 1/1 | 49.420000000 | 49.420000000 to 49.420000000 | 5193104404/16467274416/512074828 |
| ida-lazy | normal | rune:new | O2 | compile | 1/1 | 5.080000000 | 5.080000000 to 5.080000000 | - |
| ida-lazy | normal | rune:new | O2 | correctness | 1/1 | 77.280000000 | 77.280000000 to 77.280000000 | - |
| ida-lazy | normal | rune:new | O2 | count | 1/1 | 75.570000000 | 75.570000000 to 75.570000000 | 3041006870/16467274416/512074828 |
| ida-lazy | normal | rune:jit | O2 | compile | 1/1 | 2.940000000 | 2.940000000 to 2.940000000 | - |
| ida-lazy | normal | rune:jit | O2 | correctness | 1/1 | 31.340000000 | 31.340000000 to 31.340000000 | - |
| ida-lazy | normal | rune:jit | O2 | count | 1/1 | 52.890000000 | 52.890000000 to 52.890000000 | 3041006870/16467274416/512074828 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

