# vector32-concat

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector32-concat.sml`.

Stephen Weeks. Retains Int32 element arithmetic and vector concatenation.
Large preserves 20000 elements and the original inclusive 10001 iterations.
Per-run expected sum n(n-1) stays representable in a 31-bit host int;
the cross-iteration validation sum uses IntInf.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.
