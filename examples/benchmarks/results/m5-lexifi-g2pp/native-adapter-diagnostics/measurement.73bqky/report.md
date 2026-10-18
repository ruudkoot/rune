# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| lexifi-g2pp | smoke | native:mlton@20241230 | O2 | compile | 1/1 | 9.370000000 | 9.370000000 to 9.370000000 | - |
| lexifi-g2pp | smoke | native:mlton@20241230 | O2 | correctness | 1/1 | 0.590000000 | 0.590000000 to 0.590000000 | - |
| lexifi-g2pp | smoke | native:mlton@20241230 | O2 | fresh | 1/1 | 0.550000000 | 0.550000000 to 0.550000000 | - |
| lexifi-g2pp | smoke | native:smlnj-legacy@110.99.9 | O2 | compile | 1/1 | 0.750000000 | 0.750000000 to 0.750000000 | - |
| lexifi-g2pp | smoke | native:smlnj-legacy@110.99.9 | O2 | correctness | 0/1 | - | - | - |
| lexifi-g2pp | smoke | native:polyml@5.9.2 | O2 | compile | 1/1 | 0.600000000 | 0.600000000 to 0.600000000 | - |
| lexifi-g2pp | smoke | native:polyml@5.9.2 | O2 | correctness | 1/1 | 1.680000000 | 1.680000000 to 1.680000000 | - |
| lexifi-g2pp | smoke | native:polyml@5.9.2 | O2 | fresh | 1/1 | 1.610000000 | 1.610000000 to 1.610000000 | - |

Failure categories and artifact paths:

- lexifi-g2pp / native:smlnj-legacy@110.99.9 / correctness: runtime-failure (`lexifi-g2pp/native-smlnj-legacy/correctness.0`).
