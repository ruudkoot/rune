# imp-for provenance

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/imp-for.sml`.

Seven nested imperative loops over references, preserving the upstream
loop implementation and nesting. Large retains width 10. Expected counts
are width^7 times repetitions, independently calculated. Mutable refs,
closures, loop lowering and allocation are diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.
