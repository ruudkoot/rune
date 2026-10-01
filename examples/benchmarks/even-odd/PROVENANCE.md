# even-odd provenance

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/even-odd.sml`.

Mutually tail-recursive parity predicates. Large retains the upstream input
of 500000000; smaller profiles permit quick correctness checks. Both
predicates are checked against arithmetic parity as well as each other.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.
