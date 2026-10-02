# hamlet provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/hamlet.sml`. Original, adaptation patch and notices retained.

Andreas Rossberg HaMLet Standard ML interpreter, as embedded by MLton.
Retains parsing, static elaboration and dynamic evaluation. Removes the
interactive session printer/loop and exposes Sml.exec only for observing the
result binding in the returned dynamic basis. The unary arithmetic program
is retained; smoke evaluates four squared (16), normal sixteen squared
(256), and large preserves the original nested power (65536). A host SML tail-recursive traversal consumes the returned unary value instead
of the original wildcard binding; the minimal interpreted basis has no
integer addition operator. Fatal interpreter errors and uncaught interpreted
exceptions set an observer flag, so the interactive error-recovery path
cannot silently validate a partial execution. These input changes and added traversal are
explicit workload adaptations, and there is no new Rune language feature.

Array.sub and Array.update are explicitly rebound after each combined
Array/List open. SML/NJ adds List.sub and List.update extensions; these
otherwise shadow the intended array operations. The binding change selects
the original mutable-array operations, without a kernel rewrite.
