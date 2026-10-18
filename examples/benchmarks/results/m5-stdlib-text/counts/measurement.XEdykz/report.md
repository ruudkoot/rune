# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| bytes_concat | normal | rune | O2 | compile | 1/1 | 3.440000000 | 3.440000000 to 3.440000000 | - |
| bytes_concat | normal | rune | O2 | correctness | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| bytes_concat | normal | rune | O2 | count | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | 40884360/56859624/1101315 |
| bytes_concat | normal | rune:opt | O2 | compile | 1/1 | 3.630000000 | 3.630000000 to 3.630000000 | - |
| bytes_concat | normal | rune:opt | O2 | native-compile | 1/1 | 1.140000000 | 1.140000000 to 1.140000000 | - |
| bytes_concat | normal | rune:opt | O2 | correctness | 1/1 | 0.190000000 | 0.190000000 to 0.190000000 | - |
| bytes_concat | normal | rune:opt | O2 | count | 1/1 | 0.150000000 | 0.150000000 to 0.150000000 | 40884360/56859624/1101315 |
| bytes_concat | normal | rune:new | O2 | compile | 1/1 | 4.210000000 | 4.210000000 to 4.210000000 | - |
| bytes_concat | normal | rune:new | O2 | correctness | 1/1 | 0.410000000 | 0.410000000 to 0.410000000 | - |
| bytes_concat | normal | rune:new | O2 | count | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | 27095519/56859624/1101315 |
| bytes_concat | normal | rune:jit | O2 | compile | 1/1 | 3.890000000 | 3.890000000 to 3.890000000 | - |
| bytes_concat | normal | rune:jit | O2 | correctness | 1/1 | 0.170000000 | 0.170000000 to 0.170000000 | - |
| bytes_concat | normal | rune:jit | O2 | count | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | 27095519/56859624/1101315 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

