# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| sphere-lazy | normal | rune | O2 | compile | 1/1 | 1.820000000 | 1.820000000 to 1.820000000 | - |
| sphere-lazy | normal | rune | O2 | correctness | 1/1 | 118.880000000 | 118.880000000 to 118.880000000 | - |
| sphere-lazy | normal | rune | O2 | count | 1/1 | 104.120000000 | 104.120000000 to 104.120000000 | 17933612049/46852252480/1319947212 |
| sphere-lazy | normal | rune:opt | O2 | compile | 1/1 | 1.670000000 | 1.670000000 to 1.670000000 | - |
| sphere-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.420000000 | 0.420000000 to 0.420000000 | - |
| sphere-lazy | normal | rune:opt | O2 | correctness | 1/1 | 50.770000000 | 50.770000000 to 50.770000000 | - |
| sphere-lazy | normal | rune:opt | O2 | count | 1/1 | 59.800000000 | 59.800000000 to 59.800000000 | 17933612049/46852252480/1319947212 |
| sphere-lazy | normal | rune:new | O2 | compile | 1/1 | 2.430000000 | 2.430000000 to 2.430000000 | - |
| sphere-lazy | normal | rune:new | O2 | correctness | 1/1 | 125.940000000 | 125.940000000 to 125.940000000 | - |
| sphere-lazy | normal | rune:new | O2 | count | 1/1 | 123.000000000 | 123.000000000 to 123.000000000 | 10608714268/46852252480/1319947212 |
| sphere-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.410000000 | 3.410000000 to 3.410000000 | - |
| sphere-lazy | normal | rune:jit | O2 | correctness | 1/1 | 61.510000000 | 61.510000000 to 61.510000000 | - |
| sphere-lazy | normal | rune:jit | O2 | count | 1/1 | 54.530000000 | 54.530000000 to 54.530000000 | 10608714268/46852252480/1319947212 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

