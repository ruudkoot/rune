# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| nucleic2-lazy | normal | rune | O2 | compile | 1/1 | 10.030000000 | 10.030000000 to 10.030000000 | - |
| nucleic2-lazy | normal | rune | O2 | correctness | 1/1 | 120.560000000 | 120.560000000 to 120.560000000 | - |
| nucleic2-lazy | normal | rune | O2 | count | 1/1 | 108.400000000 | 108.400000000 to 108.400000000 | 14776376458/11338412464/281601640 |
| nucleic2-lazy | normal | rune:opt | O2 | compile | 1/1 | 9.260000000 | 9.260000000 to 9.260000000 | - |
| nucleic2-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 3.080000000 | 3.080000000 to 3.080000000 | - |
| nucleic2-lazy | normal | rune:opt | O2 | correctness | 1/1 | 57.510000000 | 57.510000000 to 57.510000000 | - |
| nucleic2-lazy | normal | rune:opt | O2 | count | 1/1 | 56.690000000 | 56.690000000 to 56.690000000 | 14776376458/11338412464/281601640 |
| nucleic2-lazy | normal | rune:new | O2 | compile | 1/1 | 8.880000000 | 8.880000000 to 8.880000000 | - |
| nucleic2-lazy | normal | rune:new | O2 | correctness | 1/1 | 108.530000000 | 108.530000000 to 108.530000000 | - |
| nucleic2-lazy | normal | rune:new | O2 | count | 1/1 | 108.390000000 | 108.390000000 to 108.390000000 | 9220150554/11338412464/281601640 |
| nucleic2-lazy | normal | rune:jit | O2 | compile | 1/1 | 11.990000000 | 11.990000000 to 11.990000000 | - |
| nucleic2-lazy | normal | rune:jit | O2 | correctness | 1/1 | 55.220000000 | 55.220000000 to 55.220000000 | - |
| nucleic2-lazy | normal | rune:jit | O2 | count | 1/1 | 76.500000000 | 76.500000000 to 76.500000000 | 9220150554/11338412464/281601640 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

