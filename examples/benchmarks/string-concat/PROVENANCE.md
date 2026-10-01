# string-concat

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/string-concat.sml`.

Retains the cyclic A-Z input, triple String.concat and complete character
fold. Large preserves length 2017 and 10001 inclusive iterations. Expected
sums come from the independently generated character sequence; the original
per-iteration 468705 is retained as the large result component.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.
