# checksum

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/checksum.sml`.

Stephen Weeks; based on Derby, The Performance of FoxNet 2.0 (1999).
Preserves packed little-endian word access and the original zero-filled
buffer. Large preserves 10000000 bytes. All zero words contribute zero,
which supplies the reviewed mathematical result. A nonzero-buffer correctness
test is required separately, since a zero-input benchmark alone is weak.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

ML Kit test/checksum.sml and checksum_smlnj.sml at
6dab5582db22a5f5672ca1fc5244171687d83ce5 share the same packed-fold kernel,
all-zero ten-million-byte input and fifty scans. Only the legacy Pack32Little
name/conversion, email spelling and invocation adapter differ. Both pristine
forms are retained here. The input distribution is all-zero in both
collections; it is not patterned byte data.
