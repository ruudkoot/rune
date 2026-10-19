# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| reptile-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 15.330000000 | 15.330000000 to 15.330000000 | - |
| reptile-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| reptile-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.720000000 | 0.720000000 to 0.720000000 | - |
| reptile-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 2.180000000 | 2.180000000 to 2.180000000 | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 2.570000000 | 2.570000000 to 2.570000000 | - |
| reptile-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 12.400000000 | 12.400000000 to 12.400000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| reptile-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.220000000 | 0.220000000 to 0.220000000 | - |
| reptile-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 4.190000000 | 4.190000000 to 4.190000000 | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.280000000 | 0.280000000 to 0.280000000 | - |
| reptile-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |

Failure categories and artifact paths:

- reptile-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`reptile-lazy/native-smlnj-legacy/build/compile`).
- reptile-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`reptile-strict/native-smlnj-legacy/build/compile`).
