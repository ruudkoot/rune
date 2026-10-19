# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| fluid-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 14.830000000 | 14.830000000 to 14.830000000 | - |
| fluid-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.320000000 | 0.320000000 to 0.320000000 | - |
| fluid-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.330000000 | 0.330000000 to 0.330000000 | - |
| fluid-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.540000000 | 1.540000000 to 1.540000000 | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.500000000 | 0.500000000 to 0.500000000 | - |
| fluid-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.460000000 | 0.460000000 to 0.460000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 12.660000000 | 12.660000000 to 12.660000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| fluid-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.120000000 | 0.120000000 to 0.120000000 | - |
| fluid-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.830000000 | 0.830000000 to 0.830000000 | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| fluid-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.300000000 | 0.300000000 to 0.300000000 | - |

Failure categories and artifact paths:

- fluid-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`fluid-lazy/native-smlnj-legacy/build/compile`).
- fluid-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`fluid-strict/native-smlnj-legacy/build/compile`).
