# Linux generic FFI portability acceptance — 2026-10-23

The delivered generic runtime is exercised on native Linux x86 ILP32,
AArch64 LP64 and big-endian PowerPC64 ELFv1. These receipts cover explicit
pinned-libffi acceptance VMs. Existing distribution/ordinary portability VM
configuration and GUI coverage are separate claims.

## Provisioning and target facts

The source is libffi 3.4.6, SHA256
`b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e`.
`BuildFFIDeps` verifies the archive before extraction, preserves the existing
prefix ownership/transaction guards, and records effective flags and commands.
Unset CFLAGS/CXXFLAGS retain `-g -O2`; explicitly empty values remain empty.
`--disable-multi-os-directory` keeps the owned static archive under `lib`,
including the Linux32 build where upstream otherwise chooses `lib32`.

```
bin/rune-build build-ffi libffi --target linux32 --offline --jobs 2
bin/rune-build build-ffi libffi --target aarch64 --offline --jobs 2
bin/rune-build build-ffi libffi --target ppc64 --offline --jobs 2
make ffi-portability JOBS=2
```

All three optimized prefixes pass the independent C admission probe before
publication: expected pointer width/endianness, scalar invocation, aggregate
return/layout and a closure called through a function pointer. QEMU is invoked
explicitly for AArch64 and PowerPC64. The dependency model passes 33 checks.
Changing CFLAGS to an explicitly empty string makes `--verify-only` reject the
optimized Linux32 prefix; ordinary verification then succeeds without changing
that prefix.

The committed target JSON is checked against `tests/ffi/target-oracle.c` on
every acceptance run. It verifies widths/alignment for ten scalar types and
plain-char signedness/endianness. Linux32 double/long-long alignment is four
bytes; plain char is unsigned on AArch64 and PowerPC64 with these toolchains.
The independent C oracle also covers aggregate passing, ownership/allocation
failure, callbacks, native errors and variadic promotions.

## Execution and evidence

The coordinator compiles the shared C provider and SML fixtures and retains
every command, stdout and stderr in `tests/out/manual/ffi-cross/PID` (or
`RUNE_TEST_RUN`). The final `receipt.json` records source/static archive,
dependency record, ABI-profile and VM hashes plus compiler and emulator
versions. Linux32 uses GCC 13.3.0; AArch64/PowerPC64 use Ubuntu Clang 18.1.3,
distribution cross sysroots/binutils and QEMU 8.2.2.

```
RUNE_TEST_ROOT="$PWD" RUNE="$PWD/bin/rune-mlton" \
  RUNEFFI=/path/to/frozen-runeffi \
  bin/runevm /path/to/frozen-cross-check.rbc TARGET
```

Each target runs both stack and register interpretation. AArch64 additionally
runs baseline and optimized JIT with `--jit-calls=1`. Each mode enables
`--gc-stress 7 --gc-verify` and exercises:

- Fixed-width signed/unsigned scalars, float/double, pointers, native errors,
  missing symbols, bounds, ownership, cleanup and allocation failures.
- Shared memory marshalling (23 checks) and explicit owners (26 checks).
- Callback nesting, collection, stack growth, saved exceptions, suppressed
  subsequent callbacks and cleanup of an owned result after an exception.
- Generated typed C adapters (18 checks): aggregate/union round trips,
  bitfields, packed-field neighbours, macros/inline calls, fixed variadic
  promotions and pointer-valued members. A closure is stored in a native
  function-pointer member, read back, stored again and invoked by C; this
  specifically exercises PowerPC64 ELFv1 descriptors.
- The same generated public client (49 contracts) for target-specific
  ownership, encodings, buffers, outputs, errors, aggregates and registered
  callbacks, plus deterministic generation/check. The alternate-convention
  function uses the default ABI outside x86-64, as documented.
- Raw promoted variadic calls, narrow fixed arguments, mixed scalar register
  classes, wide integers, object/function pointers, stack spills and callbacks
  that collect while a C `va_list` is suspended; libc `sprintf` supplies another
  independent mixed integer/double subject.

Before the final runtime additions, the complete suite passed with receipts
`272703` (Linux32), `272ED7` (AArch64, four modes) and `27326C` (PowerPC64).
The final source-frozen snapshot includes raw variadics (`17c471463`), callback
fault snapshots (`3b0cb62fb`), the 32-bit pointer repair (`706c66cd2`) and the
optimized provisioning recipe (`2f3e946a9`, `d6d147bed`). All final runs pass:

| Target | Modes | Final evidence directory | Checked receipt |
| --- | --- | --- | --- |
| Linux32 | Stack, register-off | `tests/out/runeffi-final-cross/ffi-cross/2DB4D3` | [JSON](cross-linux32.json) |
| AArch64 | Stack, register-off, baseline JIT, optimized JIT | `tests/out/runeffi-final-cross/ffi-cross/2DB4A0` | [JSON](cross-aarch64.json) |
| PowerPC64 big-endian | Stack, register-off | `tests/out/runeffi-final-cross/ffi-cross/2DC02B` | [JSON](cross-ppc64.json) |

Each final C oracle passes 46 checks. Every SML mode passes all listed shared
suites and both independent language probes. Callback coverage additionally
verifies the exact status/reset count from 256 concurrent rejected foreign-thread
entries and observes the bounded-entry failure reason. There are no failed
final target runs. The retained command/output artifacts bind these results to
the exact VMs, profiles, pinned archives and toolchains in the JSON receipts.

## Template and portability repair

The first Linux32 build exposed an eight-byte `memcpy` from a four-byte helper
function pointer in `ms_call`, even though that target has no JIT backend.
Commit `706c66cd2` zero-initializes the 64-bit address, guards representation
size, and copies only `sizeof helper`. C99 `-O2 -Wall -Wextra
-Werror=array-bounds` compilation passes for native32 and x86-64 without the
old warning.

`make templates` regenerates byte-identical `src/opt/x64_layout.sml` with
SHA256 `15c04fac49fdfda4158eecf390f9db6aa777635fea5cf2f2626fbe65060169c1`.
`make check-templates` passes 6/6 (the actual native template check and five
runner canaries); events are in
`tests/out/r/20261023-120425-575/events.jsonl`.

The restricted sandbox aborts native32 execution with SIGSYS. The exact C and
SML tests ran outside it; the sandbox abort is not counted as target success.
These receipts do not establish GUI, native `runeopt`, or physical AArch64/
PowerPC64 machine acceptance. QEMU execution is named explicitly.
