# Canonical Win32 generated library sources — 2026-10-23

Component `ab566a18e` (delivery integration `ddf5e0032`) moves the canonical Windows32/64 binding sets from
`ffi/win32/generated` to `lib/ffi/win32/generated`. All **32 files / 3,800,012
bytes** retain their original contents, including SML signatures/structures,
virtual build pointers, typed C shim sources and declaration provenance.
There are no compatibility copies under the original-input tree.
The [JSON receipt](win32-canonical.json) records every old/new path, size and
SHA256, checked independently against retained delivery ancestor `0952d1d9d`.

The immutable generations remain:

| Target | Generation |
| --- | --- |
| Windows32 | `26ff0de56852afddda13a8bf304d3cd546aa3b8f474e68f0e90064e105329d5e` |
| Windows64 | `a61bdfff8e4723c29d9fdeaa26af0211d97c324e680bcedda17861886ebe8fe7` |

Both retain public API identity
`dd7375fb3543df8a7b9f445b9c6056e508b7a0a1014aaac14defe755d5e62221`.
Original Microsoft headers remain external, with their existing pinned
provenance/acquisition manifests and `.ffi` policy under `ffi/win32`.
No runtime, Basis, VM, image, generator implementation or binding ABI changes.

## Generation and library ownership

The four fixed native/contract build fragments, public documentation and
regeneration commands use the canonical library paths. The existing SML
coordinator now provides:

```
make win32-generated
make check-win32-generated
```

Per-target `rune-win32-check generate/check 32|64 OUTPUT` remains available.
All use the pinned SDK/MSVC roots and the same layouts, constants and typed
field selections. The actual frozen generator passes **strict check of both
moved targets, regeneration of both, then strict check of both again**.
All 32 output hashes still match the original files after regeneration.

The Make graph derives the two new MANIFESTs using the same rule as the three
SDL sets. Both are generated successfully by the accepted FFI-disabled
compiler/VM with `FFI=no BOOTHOST=nofi-bootstrap`; indexes remain ignored
outputs. Source installation and distribution explicitly retain complete
generated trees for both families, including files outside the SML indexes.
The existing generated-asset fixture now covers three SDL and two Win32 targets
and passes exact Linux archive/installation bytes and Windows archive presence.

## Actual installation and distribution

A fresh source installation moves to an external path with spaces. All **204**
tracked input/generated assets match the current source bytes, including all
32 relocated Win32 files and both derived MANIFESTs. The old
`lib/rune/ffi-assets/win32/generated` copy is absent. Supported uninstall
removes the library and preserves an unrelated `bin` marker.

Both fresh archive formats also match all 204 current tracked assets exactly,
with Win32 sets only under `lib/rune/ffi/win32/generated`. Actual Windows32
and Windows64 installations pass **10/10 commands**, five per width:
installation, installed-compiler build, installed dependency report, real
native GUI execution and supported-location uninstall. Each prefix moves
before compilation/execution; the unchanged shared application, native main
and build entrypoint match their source hashes. Libraries and canonical sets
are read from the installed prefix, without a copied generated set in the
client input tree or a dependency back to the checkout.

The actual Windows interpreters use collection stress 101 and heap verification.
The application draws through GDI, processes three timer events, closes and
prints `PASS shared Win32 application: 0`. Each uninstall removes every owned
asset/library file and preserves the unrelated marker. External client caches
remain outside the installation. TEMP/TMP are isolated per target to avoid the
legacy shared temporary manifest names.

Native and Rune packager builds pass. Native-provider documentation is
regenerated and checks all 15 pages; documentation consistency passes **11/11**.
There are no failed attempts in this component's focused acceptance.

## Scope and repeatable metadata packaging

The runtime/Basis and compiler/VM/image hashes are the same frozen artifacts
as the [final runtime](final-runtime.md) and [installed-example](installed-examples.md)
receipts. The caller restores Windows prefixes to their original manifest
location before uninstall, as documented; no new absolute Windows `.build`
path or relocatable uninstall support is claimed.

These archives use `--fixture`: actual current x86-64 Linux and Windows32/64
payloads, with the x86-64 fixture reused in the other Linux architecture slots.
They validate source packaging, not production six-architecture distribution.
Cumulative repository acceptance remains separately qualified by its own source.

The JSON embeds a tested repack coordinator and asset verifier. For subsequent
status-only JSON metadata promotion, the coordinator rebuilds only the native
packager, indexes all five canonical sets, creates both current-asset archives,
compares every tracked `ffi`, `lib/ffi/sdl` and `lib/ffi/win32/generated` file,
and requires seven frozen runtime/compiler/image artifacts to remain unchanged.
Its recorded successful rerun needs no repeated GUI execution for those
metadata-only bytes.
