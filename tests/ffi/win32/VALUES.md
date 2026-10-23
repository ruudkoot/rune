# Windows integer helper evidence

`ffi/win32/helpers.json` maps each of the eight helpers to its original
pinned SDK header and line. The original files are not edited. The SML
`Win32Values` implementation uses bounded word projections, explicit byte
components for RGB and signed sixteen-bit coordinate extension.

The seventeen SML unit cases agree with `helpers.c`, an independent C oracle
compiled with Clang's MSVC target against the original SDK/VC headers and
run on native Windows x86 and x86-64. Upper pointer bits, unsigned words,
byte wrapping, palette-bit extraction and signed coordinate boundaries are
included. No native primitive or generated function is needed for these
integer-only projections.

Host jobs `ffi.win32.common` and `ffi.win32.values` compile the pure common
library against each host's own Basis. Hosts missing optional fixed-width
structures remain documented as HOST-ABSENT; these results do not claim
that a host supplies Rune's Word16 or Int64 extensions. Rune runs the entire
suite with its own fixed-width structures.

On 2026-10-23 the native-own-Basis jobs passed on MLton and MLKit. SML/NJ
110.99.9 (both widths) and 2026.2 rejected the absent Word16 structure;
Poly/ML rejected its absent Int64 structure. These eight build failures are
recorded as HOST-ABSENT, not portability passes. The first sandboxed SML/NJ32
attempt exited with SIGSYS; an unrestricted rerun reached the same Word16
diagnostic as the other SML/NJ hosts. No production implementation was
changed to accommodate host omissions.
