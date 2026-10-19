# tak provenance

Source collection: mlton

Revision: `b15e2d289c3d701131733665a74e2dd8438410b6`

Path: `benchmark/tests/tak.sml`

Individual author not stated; MLton project notice retained in LICENSE.

Inputs, validation, literature and all changes are recorded in [the suite README](../README.md#tak).

The strict recurrence is shared in `../shared/tak.sml`. Classic and nofib
drivers retain their distinct parameters and result formatting; the kernel
is identical and both upstream provenances are retained.

Sandmark's `rec_seq_tak` also uses this strict recurrence. Its curried OCaml
arguments become the shared SML tuple call. The original default (40,20,11)
and single repetition differ from MLton's (33,22,11) launcher; the named
Sandmark driver retains its own profiles, source and aggregate notice.
Pure operand evaluation follows SML order, as documented in that port.
