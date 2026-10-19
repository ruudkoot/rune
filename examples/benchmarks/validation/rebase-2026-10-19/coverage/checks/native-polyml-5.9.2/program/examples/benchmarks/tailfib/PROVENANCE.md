# tailfib provenance

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailfib.sml`.

Tail-recursive Fibonacci. The original 44-step recurrence and accumulator
order are unchanged. Large preserves the original million repetitions. The
IntInf result sum is additional validation and avoids narrow-host overflow.
Tail calls and accumulator arithmetic are the diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.
