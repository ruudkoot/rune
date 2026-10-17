# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| minimax-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 5.000000000 | 5.000000000 to 5.000000000 | - |
| minimax-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| minimax-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| minimax-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| minimax-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.090000000 | 0.090000000 to 0.090000000 | - |
| minimax-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.100000000 | 0.100000000 to 0.100000000 | - |
| minimax-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.370000000 | 0.370000000 to 0.370000000 | - |
| minimax-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| minimax-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |

Failure categories and artifact paths:

