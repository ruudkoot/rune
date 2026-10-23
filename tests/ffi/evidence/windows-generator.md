# Windows-hosted generator acceptance

Date: 2026-10-23. Actual Windows x86 and x64 register VMs executed the same
Runeffi generator bytecode used on Linux. The complete generic fixture
(including macros, fixed variadics, structs, ownership and callbacks) produced
identical inspection output. Each host also generated its native Windows
target, repeated generation without changing the immutable pointer, passed
its own strict check, and passed a Linux strict check of the Windows-written
artifacts. The Windows32 host additionally generated the explicit Linux64
inspection target; generator-host width does not determine target layout.

The initial exact Windows executions both failed before inspection with
`Io`. A read-only probe showed `OS.FileSys.fullPath` mapping a native drive
path to `/C:/...`, while `realPath` treated the native input as POSIX-relative
and produced `../../C:/...`. `CFiles.read` and `CFiles.resolver` now establish
absolute canonical identities with `fullPath`. The CLI reports the name,
operation and underlying cause of I/O errors. No Basis path semantics change.

Validation:

```text
runevm rune-ffi-generator-check.rbc windows 64
runevm rune-ffi-generator-check.rbc windows 32
  full inspection agrees with Linux PASS
  native target generation, check and deterministic regeneration PASS
  Linux strict artifact check of Windows-written output PASS
rune --library language/c tests/lib/language/c/frontend.sml
  86 frontend/include-resolution checks PASS
```

Execution used copied, stable image15/ABI17 Windows VM snapshots from the
integration worktree; the delivery worktree's older binaries were not used.
SHA-256 of the actual executables:

- x64: `36c5a6e98093b6e502c8b1198e09ba6a353f6e85d607fa11bc8b9b8978dba9fa`
- x86: `f049328dec8085d6bb11c0c5918885fea6ddda30eecb493ceebefb4dd889a4e9`

The coordinator ran outside the restricted sandbox because WSL interop and
Windows temporary storage require it. Inputs and output lived in the
selected Windows test directory. These receipts establish CLI execution,
not interactive GUI behavior; that has separate SDL/Win32 evidence.
