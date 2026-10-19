# output1 provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/output1.sml`. Original and adaptation patch retained.

The output1 loop still writes one a character per iteration through TextIO.
The Unix /dev/null sink is replaced by a fixed regular file so the SML97
program can consume and validate its actual output. This materially adds
filesystem writes and validation reads; comparisons measure this documented
file-output variant, not the original discard-device timings. Every byte
must be 97 and the observed file length must equal the requested count.
Large preserves one billion writes; it is explicitly selected and creates
a one-GB artifact within the isolated run directory.
