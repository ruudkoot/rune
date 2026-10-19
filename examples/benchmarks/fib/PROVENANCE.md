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

The unchanged strict recurrence is shared in `../shared/fib.sml` with
Sandmark's `rec_seq_fib`. Its retained source has the same 0/1 base cases
and two recursive calls. Both established names retain their input and
repetition profiles: MLton's original uses 41, Sandmark's uses four calls
at 40. The complete Sandmark source and notice are retained under
`../rec_seq_fib/`. This shares the implementation without erasing the
different launchers or implying identical original operand evaluation order.
