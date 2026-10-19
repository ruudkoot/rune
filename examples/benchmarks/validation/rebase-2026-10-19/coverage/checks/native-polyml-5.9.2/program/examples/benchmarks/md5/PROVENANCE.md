# md5

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/md5.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Retains the original MD5 state, compression rounds, padding and hex encoding.
Input bytes are i mod 256. Large preserves the original 10000-byte block
repeated 100000 times. Python hashlib supplies an independent digest; the
large digest additionally matches the upstream literal reference.

[RFC 1321](https://www.rfc-editor.org/rfc/rfc1321) supplies seven independent
standard test vectors. tests/benchmarks/md5.sml checks those and a split update
at the compression-block boundary on all seven configurations.
