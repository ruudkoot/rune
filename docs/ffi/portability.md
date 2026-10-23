# Foreign calls on the Linux portability targets

The generic dynamic runtime and SML generator have explicit Linux x86 ILP32,
AArch64 LP64 and big-endian PowerPC64 ELFv1 profiles. These targets use the
same pinned libffi 3.4.6 source archive as the primary platforms. GUI providers
have a separate target inventory and are not part of these tests.

Provision the target libraries before building the dedicated acceptance VMs:

```
make ffi-libffi-linux32 ffi-libffi-aarch64 ffi-libffi-ppc64 JOBS=2
make ffi-portability JOBS=2
make test-ffi-portability JOBS=2
```

`bin/rune-build build-ffi libffi --target TARGET --offline --jobs 2` can use an
already verified archive in `build/deps/downloads`. `--verify-only` checks the
recipe, effective environment, output inventory and hashes. `--prefix`, `--cc`,
`--cflags`, `--ldflags`, `--ar`, `--ranlib` and `--runner` support explicit
local toolchains. A fresh prefix is published only after a C admission probe
executes scalar calls, a returned aggregate and a closure through a function
pointer. Expected pointer width and byte order are also checked. The recorded
commands distinguish an explicit QEMU runner from native32 execution.

The default Linux32 profile uses the host C compiler with `-m32 -msse2
-mfpmath=sse` and needs libc development multilib support. The other profiles
use Clang with the distribution's `/usr/aarch64-linux-gnu` or
`/usr/powerpc64-linux-gnu` headers, libc, binutils and target archiver. QEMU user
mode is invoked explicitly with `-L` and the sysroot. Kernel binfmt registration
is unnecessary for these acceptance jobs. Installing those distribution
packages is a prerequisite; the provisioner does not change the host system.

The independent VMs are named `runevm-ffi32`, `runevm-stack-ffi32`,
`runevm-ffi-aarch64.bin`, `runevm-stack-ffi-aarch64.bin`,
`runevm-ffi-ppc64.bin` and `runevm-stack-ffi-ppc64.bin`. They always enable FFI
and deliberately use the portable SML IntInf backend, keeping this acceptance
independent of optional cross GMP. The existing portability targets and
`FFI=no` builds remain available without target libffi provisioning. The
cross-build identity hashes runtime sources, measured include dependencies,
the static libffi archive and its provenance record.

`bin/rune-ffi-cross-check TARGET` checks the committed target profile against
an independently compiled and executed C oracle, then runs the shared scalar,
pointer, memory, ownership, callback and generated-public-interface fixtures.
It also generates and runs aggregate, union, bitfield, packed-field, inline,
macro, fixed-variadic and pointer-member shims. A callback is written into a
native function-pointer member, read back, stored again and invoked by C;
this covers the ELFv1 descriptor ABI on PowerPC64. Raw variadic tests also pass narrow fixed arguments and 84 mixed tail
arguments, including wide integers, object/function pointers and 12 callbacks
that collect while a C `va_list` is suspended. Callback diagnostics observe
and atomically reset the exact count from 256 concurrent rejected foreign-thread
entries. All SML executions enable collection stress and heap verification. Both interpreters run on each target;
AArch64 also runs both JIT tiers. There is no native `runeopt` or GUI acceptance
claim for these targets.

The x86-64-only alternate-calling-convention function in the shared public
fixture has a default-ABI implementation on other architectures. Its
nonstandard convention remains an x86-64-only witness. Target widths,
alignment, byte order and plain-char signedness are checked separately. In
particular, Linux32 double/long-long alignment is four bytes and AArch64 and
PowerPC64 use unsigned plain char in the recorded toolchains.

Every command, stdout, stderr and final receipt is retained under
`tests/out/manual/ffi-cross/PID` (or the configured runner output root). The receipt
names compiler and emulator versions and hashes each VM, target profile,
archive and dependency record. A sandbox that blocks native32 execution with
`SIGSYS` must rerun the exact test outside that sandbox; it is not a successful
or explained target execution. Missing prerequisites remain unsupported or
outstanding acceptance checks.

The [dated acceptance evidence](../../tests/ffi/evidence/m10-linux-portability.md)
links checked JSON receipts for all three final target runs.
