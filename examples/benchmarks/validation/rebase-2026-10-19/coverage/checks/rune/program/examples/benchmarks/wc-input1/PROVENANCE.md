# wc-input1

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/wc-input1.sml`.

Stephen Weeks. Retains file generation, TextIO.input1 reading and
newline counting. Source newlines occur at positions divisible by ten,
including zero: ceil(n/10) is the independent oracle. Files are closed and
removed on success and failure. The scanner variant returns its observed
count rather than discarding the result after its internal assertion.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.
