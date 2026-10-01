# tailmerge provenance

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailmerge.sml`.

Stephen Weeks is credited upstream. The tail-recursive reversed-accumulator merge is retained.
Large preserves the original 100000-element input lists. The checker now
consumes every output element and verifies the complete sequence 0..2n-1,
instead of merely testing its head. Sum = n(2n-1) per repetition.
Allocation, list traversal, recursion and tail calls are relevant.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.
