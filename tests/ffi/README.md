# Foreign-interface acceptance subjects

`fixture.h`/`fixture.c` are an independent native subject: exact scalar
extrema, aggregate arguments/results, overlapping buffers, owned strings,
allocation failures, error values overwritten during cleanup, retained
callbacks, nested native calls, default variadic promotions and stdcall.
`oracle.c` calls it directly and optionally through libffi. The subject
contains no Rune runtime code. Later SML bindings must match these results.

`win32_oracle.c` checks actual Windows creation-time callbacks, synchronous
nested sends, UTF-16 titles, resource/timer cleanup and destruction on both
Windows widths. It creates a hidden window; it does not replace interactive
GUI acceptance. `contracts.sml` is an independent finite state model for
the common message/paint contract and elaborates all public signatures.

Run `make test-ffi-contracts` for portable M0 checks and
`make test-ffi-windows` for the native Windows reference programs.
Every child has a bounded timeout and a private output directory. Source
validation checks vendored SDL hashes; `sdk` additionally validates an
installed original SDK selected by `RUNEFFI_WINDOWS_SDK`.
The dated `evidence/` records commands, identities and unresolved checks.
Successful native reference programs establish expected behavior, not a
passing Rune bridge or completed GUI milestone.

`make test-ffi-header-layout` checks selected original SDL/SDK type layouts,
nested field offsets, constants and Win32 macro expressions against native
C. Configure the pinned SDK/MSVC include roots as documented in
`ffi/win32/README.md` to enable its Windows cases. `make test-ffi-real32`
compares binary32 conversion against six independent native C targets.
