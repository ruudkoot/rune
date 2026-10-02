# tsp provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tsp.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories divide-and-conquer travelling-salesman heuristic.
Retains the generated point distribution, tree, nearest-neighbor conquer
and merging/orientation logic. The generator uses the source-commented
32-bit Park-Miller modulus 2147483647 explicitly, with IntInf intermediate
arithmetic, rather than each host's Int.maxInt. This changes generator
representation but keeps MLton's input distribution. Observe the complete
cycle, reject broken backlinks/cardinality, and compare its sorted point
multiset with the input tree. Check length against the pinned upstream
MLton result with absolute and relative tolerance 1e-8. Large uses the
initial 32767-point setting; the later MLton 2097151 override is not selected.
Additional cycle validation/sorting is included in the workload.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tsp.sml`,
is an additional source for this implementation. Tree/TSP/Rand/BuildTree agree.
ML Kit selects 32767 vertices and four tours; `test/tsp_tp.sml` changes
only the call count to eight. MLton selects 2097151 vertices with a
parameterized repeat count. Selected profiles bound the work; these
original invocations remain documented. Repetitions do not change the
algorithm, representation or deterministic tree distribution.
