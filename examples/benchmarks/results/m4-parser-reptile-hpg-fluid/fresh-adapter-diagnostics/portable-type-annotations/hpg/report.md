# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| hpg-lazy | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 10.380000000 | 10.380000000 to 10.380000000 | - |
| hpg-lazy | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | - |
| hpg-lazy | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.560000000 | 0.560000000 to 0.560000000 | - |
| hpg-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 2.240000000 | 2.240000000 to 2.240000000 | - |
| hpg-lazy | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.000000000 | 1.000000000 to 1.000000000 | - |
| hpg-lazy | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 1.000000000 | 1.000000000 to 1.000000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 7.670000000 | 7.670000000 to 7.670000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| hpg-strict | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.270000000 | 0.270000000 to 0.270000000 | - |
| hpg-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 2.070000000 | 2.070000000 to 2.070000000 | - |
| hpg-strict | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 0.880000000 | 0.880000000 to 0.880000000 | - |
| hpg-strict | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 0.810000000 | 0.810000000 to 0.810000000 | - |

Failure categories and artifact paths:

- hpg-lazy / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`hpg-lazy/native-smlnj-legacy/correctness.0`).
- hpg-strict / native:smlnj-legacy@110.99.9 / correctness: incorrect-result (`hpg-strict/native-smlnj-legacy/correctness.0`).
