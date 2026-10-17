# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| primetest-lazy | smoke | native:mlton@20241230 | O2 | compile | 0/1 | - | - | - |
| primetest-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| primetest-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 0/1 | - | - | - |

Failure categories and artifact paths:

- primetest-lazy / native:mlton@20241230 / compile: compile-error (`primetest-lazy/native-mlton/build/compile`).
- primetest-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`primetest-lazy/native-smlnj-legacy/build/compile`).
- primetest-lazy / native:polyml@5.9.2 / compile: compile-error (`primetest-lazy/native-polyml/build/compile`).
