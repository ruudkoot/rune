# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hidden-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 9.210000000 | 9.210000000 to 9.210000000 | - |
| hidden-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| hidden-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.040000000 | 0.040000000 to 0.040000000 | - |
| hidden-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | - |
| hidden-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| hidden-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| hidden-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |
| hidden-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.060000000 | 0.060000000 to 0.060000000 | - |

Failure categories and artifact paths:

- hidden-lazy / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`hidden-lazy/native-smlnj-legacy/correctness.0`).
