# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_iter | normal | rune | O2 | compile | 1/1 | 2.930000000 | 2.930000000 to 2.930000000 | - |
| bytes_iter | normal | rune | O2 | correctness | 1/1 | 0.390000000 | 0.390000000 to 0.390000000 | - |
| bytes_iter | normal | rune | O2 | count | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | 39215753/46154208/1155280 |
| bytes_iter | normal | rune:opt | O2 | compile | 1/1 | 2.570000000 | 2.570000000 to 2.570000000 | - |
| bytes_iter | normal | rune:opt | O2 | native-compile | 1/1 | 1.050000000 | 1.050000000 to 1.050000000 | - |
| bytes_iter | normal | rune:opt | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| bytes_iter | normal | rune:opt | O2 | count | 1/1 | 0.160000000 | 0.160000000 to 0.160000000 | 39215753/46154208/1155280 |
| bytes_iter | normal | rune:new | O2 | compile | 1/1 | 2.850000000 | 2.850000000 to 2.850000000 | - |
| bytes_iter | normal | rune:new | O2 | correctness | 1/1 | 0.400000000 | 0.400000000 to 0.400000000 | - |
| bytes_iter | normal | rune:new | O2 | count | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | 27673128/46154208/1155280 |
| bytes_iter | normal | rune:jit | O2 | compile | 1/1 | 5.030000000 | 5.030000000 to 5.030000000 | - |
| bytes_iter | normal | rune:jit | O2 | correctness | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| bytes_iter | normal | rune:jit | O2 | count | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | 27673128/46154208/1155280 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

