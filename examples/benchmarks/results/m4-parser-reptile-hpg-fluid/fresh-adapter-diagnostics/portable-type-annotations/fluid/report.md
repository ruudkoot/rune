# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fluid-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 14.960000000 | 14.960000000 to 14.960000000 | - |
| fluid-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| fluid-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.310000000 | 0.310000000 to 0.310000000 | - |
| fluid-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 4.980000000 | 4.980000000 to 4.980000000 | - |
| fluid-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.370000000 | 1.370000000 to 1.370000000 | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.470000000 | 0.470000000 to 0.470000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 10.750000000 | 10.750000000 to 10.750000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.130000000 | 0.130000000 to 0.130000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| fluid-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 7.410000000 | 7.410000000 to 7.410000000 | - |
| fluid-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.870000000 | 0.870000000 to 0.870000000 | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |

Failure categories and artifact paths:

- fluid-lazy / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`fluid-lazy/native-smlnj-legacy/correctness.0`).
- fluid-strict / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`fluid-strict/native-smlnj-legacy/correctness.0`).
