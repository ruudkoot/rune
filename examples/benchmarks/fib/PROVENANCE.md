# fib provenance

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/fib.sml`.

Naive binary-recursive Fibonacci. Upstream checks fib 41 = 165580141.
Smoke/normal are smaller; large retains 41. An iterative recurrence supplies
the independent expected values. Calls, branching and recursion are the
diagnostic targets; there is no memoization in the benchmark.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.
