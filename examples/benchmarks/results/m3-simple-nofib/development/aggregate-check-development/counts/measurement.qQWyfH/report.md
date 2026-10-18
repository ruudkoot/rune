# Benchmark measurement report

Every raw sample, failed phase and configuration is retained in `samples.tsv`.
Metadata and source/input snapshots accompany this report. Compilation is
separate from execution. Fresh samples include process startup and shutdown;
repeated samples time Benchmark.run in process. First rounds are retained;
no steady-state or causal performance claim is inferred. Times are seconds.
IQR endpoints use linear interpolation at (n-1)*p. Counts are instructions/bytes/objects.

| Benchmark | Profile | Configuration | Level | Phase | Accepted/attempted | Median | Q1 to Q3 | Counts |
|---|---|---|---|---|---|---|---|---|
| simple-nofib-lazy | normal | rune | O2 | compile | 1/1 | 5.440000000 | 5.440000000 to 5.440000000 | - |
| simple-nofib-lazy | normal | rune | O2 | correctness | 1/1 | 56.700000000 | 56.700000000 to 56.700000000 | - |
| simple-nofib-lazy | normal | rune | O2 | count | 1/1 | 52.250000000 | 52.250000000 to 52.250000000 | 6461397236/6498545968/161404262 |
| simple-nofib-lazy | normal | rune:opt | O2 | compile | 1/1 | 3.440000000 | 3.440000000 to 3.440000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | native-compile | 1/1 | 0.800000000 | 0.800000000 to 0.800000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | correctness | 1/1 | 21.540000000 | 21.540000000 to 21.540000000 | - |
| simple-nofib-lazy | normal | rune:opt | O2 | count | 1/1 | 25.680000000 | 25.680000000 to 25.680000000 | 6461397236/6498545968/161404262 |
| simple-nofib-lazy | normal | rune:new | O2 | compile | 1/1 | 3.700000000 | 3.700000000 to 3.700000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | correctness | 1/1 | 43.500000000 | 43.500000000 to 43.500000000 | - |
| simple-nofib-lazy | normal | rune:new | O2 | count | 1/1 | 45.850000000 | 45.850000000 to 45.850000000 | 3364853592/6498545968/161404262 |
| simple-nofib-lazy | normal | rune:jit | O2 | compile | 1/1 | 3.850000000 | 3.850000000 to 3.850000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | correctness | 1/1 | 20.180000000 | 20.180000000 to 20.180000000 | - |
| simple-nofib-lazy | normal | rune:jit | O2 | count | 1/1 | 18.750000000 | 18.750000000 to 18.750000000 | 3364853592/6498545968/161404262 |
|  | normal | rune:jit | O2 | count-check | 1/1 | 0.000000000 | 0.000000000 to 0.000000000 | - |

Failure categories and artifact paths:

