# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hashtbl_fold | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.830000000 | 7.830000000 to 7.830000000 | - |
| hashtbl_fold | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| hashtbl_fold | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| hashtbl_fold | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.580000000 | 0.580000000 to 0.580000000 | - |
| hashtbl_fold | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 1/1 | 0.050000000 | 0.050000000 to 0.050000000 | - |
| hashtbl_fold | smoke | native:smlnj-legacy@110.99.9 | O2 | fresh | 1/1 | 0.030000000 | 0.030000000 to 0.030000000 | - |
| hashtbl_fold | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| hashtbl_fold | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |
| hashtbl_fold | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

