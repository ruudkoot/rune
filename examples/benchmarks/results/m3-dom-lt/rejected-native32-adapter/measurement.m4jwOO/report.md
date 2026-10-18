# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| dom-lt | smoke | native:smlnj32@110.99.9 | O2 | compile | 1/1 | 0.840000000 | 0.840000000 to 0.840000000 | - |
| dom-lt | smoke | native:smlnj32@110.99.9 | O2 | correctness | 0/1 | - | - | - |

Failure categories and artifact paths:

- dom-lt / native:smlnj32@110.99.9 / correctness: runtime-failure (`dom-lt/native-smlnj32/correctness.0`).
