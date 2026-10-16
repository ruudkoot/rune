# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| revcomp2 | smoke | native:mlton@20241230 | O2 | compile | 0/1 | - | - | - |
| revcomp2 | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| revcomp2 | smoke | native:polyml@5.9.2 | O2 | compile | 0/1 | - | - | - |

Failure categories and artifact paths:

- revcomp2 / native:mlton@20241230 / compile: compile-error (`revcomp2/native-mlton/build/compile`).
- revcomp2 / native:smlnj-legacy@110.99.9 / compile: compile-error (`revcomp2/native-smlnj-legacy/build/compile`).
- revcomp2 / native:polyml@5.9.2 / compile: compile-error (`revcomp2/native-polyml/build/compile`).
