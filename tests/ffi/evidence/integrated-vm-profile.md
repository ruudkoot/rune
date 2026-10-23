# Integrated VM, Windows and portability acceptance — 2026-10-23

Frozen source `17c188d25` passes **10,197/10,197** outer runner cases,
**zero failures or skips**, in 3,141.5 seconds (6,641.9 seconds CPU):
`tests/out/r/20261023-114139-2587285` in the independent `runeffi-layout`
validation worktree. Its nested portability Basis matrix separately passes
**2,406/2,406** comparisons, run `20261023-122348-3009388`.

The strict combined selection includes the entire VM profile and Windows
tier, plus FFI Windows runtime/SDL fixtures, original-header frontend/layout
comparisons, all six layout/binary32/shim targets and Windows generator
checks. It covers both Windows widths/instruction sets, sanitizer and
collection stress, native/JIT instruction/count oracles, cross-machine
images, explicit QEMU portability and native Windows GUI behavior.

Preparation used `make windows portability vm-asan` and complete test-tool
prerequisites. Native VMs used system libffi; Windows VMs linked the pinned
3.4.6 target archives. Windows SDK 10.0.22621.0/MSVC 14.40.33807 roots and
the pinned SDL3 3.4.18 libraries were supplied explicitly. Doctor confirmed
every selected capability before strict execution.

The exact filter is:

```text
tag:vm | tag:test-windows | tag:test-ffi-runtime-windows |
tag:test-sdl-windows | tag:test-c-frontend-windows |
tag:test-ffi-header-layout | tag:test-c-layout | tag:test-ffi-real32 |
tag:test-ffi-generator-windows | tag:test-ffi-shims
```

Command logs: `/tmp/runeffi-final-vm-preparation.log`,
`/tmp/runeffi-final-profile-tools.log`,
`/tmp/runeffi-final-vm-windows-portability.log`.

Later raw variadic preparation, callback rejection status and the guarded
image-corruption fixture have separate focused native/sanitizer/cross-target
receipts. This run validates their preceding shared runtime foundation;
final cumulative release evidence identifies the subsequent source changes
and checks rather than claiming this snapshot includes them.
