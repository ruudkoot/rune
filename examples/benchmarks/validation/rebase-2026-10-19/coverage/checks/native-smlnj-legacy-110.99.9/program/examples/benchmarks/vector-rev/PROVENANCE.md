# vector-rev

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector-rev.sml`.

Stephen Weeks. Retains tabulate-based vector reversal. Every element of
the double reversal is checked, strengthening the original head-only test.
Large preserves 200000 elements and the original inclusive 1001 iterations.
The independent sum is n(n-1)/2 per repetition.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.
