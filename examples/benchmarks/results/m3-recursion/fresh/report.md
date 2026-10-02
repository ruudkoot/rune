# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| tak-nofib-strict | normal | rune | O2 | compile | 1/1 | 2.800000000 | 2.800000000 to 2.800000000 | - |
| tak-nofib-strict | normal | rune | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak-nofib-strict | normal | rune | O2 | fresh | 10/10 | 0.010000000 | 0.010000000 to 0.020000000 | - |
| tak-nofib-strict | normal | native:mlton@20241230 | O2 | compile | 1/1 | 4.200000000 | 4.200000000 to 4.200000000 | - |
| tak-nofib-strict | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-strict | normal | native:mlton@20241230 | O2 | fresh | 10/10 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-strict | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| tak-nofib-strict | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak-nofib-strict | normal | native:smlnj-legacy@110.99.9 | O2 | fresh | 10/10 | 0.010000000 | 0.010000000 to 0.010000000 | - |
| tak-nofib-strict | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.240000000 | 0.240000000 to 0.240000000 | - |
| tak-nofib-strict | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-strict | normal | native:polyml@5.9.2 | O2 | fresh | 10/10 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-lazy | normal | rune | O2 | compile | 1/1 | 1.030000000 | 1.030000000 to 1.030000000 | - |
| tak-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| tak-nofib-lazy | normal | rune | O2 | fresh | 10/10 | 0.020000000 | 0.020000000 to 0.020000000 | - |
| tak-nofib-lazy | normal | native:mlton@20241230 | O2 | compile | 1/1 | 7.590000000 | 7.590000000 to 7.590000000 | - |
| tak-nofib-lazy | normal | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-lazy | normal | native:mlton@20241230 | O2 | fresh | 10/10 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| tak-nofib-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.230000000 | 0.230000000 to 0.230000000 | - |
| tak-nofib-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| tak-nofib-lazy | normal | native:smlnj-legacy@110.99.9 | O2 | fresh | 10/10 | 0.030000000 | 0.030000000 to 0.037500000 | - |
| tak-nofib-lazy | normal | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| tak-nofib-lazy | normal | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| tak-nofib-lazy | normal | native:polyml@5.9.2 | O2 | fresh | 10/10 | 0.020000000 | 0.012500000 to 0.027500000 | - |

Failure categories and artifact paths:

