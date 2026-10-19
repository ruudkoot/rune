# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hpg-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 12.560000000 | 12.560000000 to 12.560000000 | - |
| hpg-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.920000000 | 0.920000000 to 0.920000000 | - |
| hpg-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.950000000 | 0.950000000 to 0.950000000 | - |
| hpg-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.240000000 | 1.240000000 to 1.240000000 | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 1.470000000 | 1.470000000 to 1.470000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 13.080000000 | 13.080000000 to 13.080000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.360000000 | 0.360000000 to 0.360000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.430000000 | 0.430000000 to 0.430000000 | - |
| hpg-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 0/1 | - | - | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.680000000 | 0.680000000 to 0.680000000 | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.100000000 | 1.100000000 to 1.100000000 | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 1.070000000 | 1.070000000 to 1.070000000 | - |

Failure categories and artifact paths:

- hpg-lazy / native:smlnj-legacy@110.99.9 / compile: compile-error (`hpg-lazy/native-smlnj-legacy/build/compile`).
- hpg-strict / native:smlnj-legacy@110.99.9 / compile: compile-error (`hpg-strict/native-smlnj-legacy/build/compile`).
