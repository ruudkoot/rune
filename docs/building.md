# Building Rune

Rune consists of the compiler `rune` (written in portable Standard ML) and the
virtual machine `runevm` (C17, and C99 with a switch). The compiler builds unchanged with **MLton**,
**SML/NJ** (for 64 and for 32 bits) and **Poly/ML**; all these builds produce
byte-identical bytecode (`make check-cross` verifies this).

The compiler Rune ships is the one it compiled itself: **`bin/rune`** is
`bin/rune.rbc` running on `runevm`. The host builds `bin/rune-mlton`,
`bin/rune-smlnj`, `bin/rune-smlnj32` and `bin/rune-polyml` have two jobs — to
bootstrap that one, and to check it (`make check-cross`, `make test-all`). Everything that runs,
tests or measures the compiler goes through `bin/rune`.

The compiler knows no library location of its own: it takes the basis library
from `--lib DIR` (which it reads from `DIR/basis`) and refuses to compile
without it. Each of the four `bin/rune*` is therefore a small wrapper script
that passes `--lib` for the tree it sits in, and the payload of a host build
lives next to it as `bin/rune-mlton.bin`, `bin/rune-polyml.bin`,
`bin/rune-smlnj.heap.amd64-linux` or `bin/rune-smlnj32.heap.x86-linux`. Because the wrapper puts `--lib` first, a
`--lib` of yours comes later on the command line and wins. Nothing absolute is
baked into `bin/rune.rbc`, so it does not depend on where the checkout is.


## Prerequisites

* A C compiler (`cc`; gcc 13 and clang 18 are tested), GNU make 4.3 or later, POSIX `sh`, `awk`. The VMs are built as C17 (`-std=c17`), and what they take from it beyond C99 is behind a test of `__STDC_VERSION__` (the header word of a `Value`, `vm/vm.h`), so `make CFLAGS='-std=c99 -O2'` builds them too, a little slower. Where the compiler is gcc or clang the VM's loop goes from instruction to instruction by computed goto, a GNU extension; `make CFLAGS='-std=c99 -O2 -DRUNE_SWITCH'` builds the switch every C compiler has.
* The SML systems that build the compiler, which `make hosts`
  (`scripts/fetch-hosts.sh`) installs under `${RUNE_HOSTS:-~/.local/rune-hosts}`:
  MLton 20241230 (the binary release), SML/NJ 110.99.9 built for 64 bits and
  for 32 bits, and Poly/ML 5.9.2 (built from source). An SML system the
  machine has on its `PATH` is never used, and none of these builds starts
  from one: MLton is a binary, SML/NJ builds its C runtime and loads its
  compiler from the boot files of the same release, and Poly/ML bootstraps
  from its own portable image and rebuilds its compiler with the result.
  `make hosts` runs the builds with `mlton`, `sml`, `poly` and `polyc`
  replaced by commands that fail, so an accidental dependency on the
  machine's SML shows. It needs `curl` or `wget`, `tar`, `xz`, a C and a
  C++ compiler, GMP (`libgmp-dev`) and a C compiler that builds 32-bit
  programs (`gcc-multilib`); about 400 MB and a few minutes, no root
  access. `make` needs MLton (`BOOTHOST` names the host build that
  bootstraps `bin/rune`, default `mlton`); `make test-all`,
  `make check-cross`, the matrix targets and `make check` need all four.

`make doctor` checks all of this (and the tools of the test, sanitizer, host
matrix and profiling targets), by running the tools rather than just looking
for them: it compiles a C program, and a program with MLton and with
`polyc`. For everything that is missing it prints the install command of the
system's package manager (`apt`, `dnf`, `pacman` or `brew`) and exits with
status 1; optional tools only produce warnings.

The build and test targets run the same check for the tools they need, once,
before they first run (`scripts/doctor.sh --quiet --scope <scope>`; a stamp
`build/.doctor-<scope>` records success, so the check is repeated after
`make clean` or when the script changes). `make DOCTOR=no ...` skips it, and
`CC`, `MLTON`, `SMLNJ`, `SMLNJ32`, `POLY` and `POLYC` name the tools to check.

## Targets

| Command | Result |
|---|---|
| `make hosts` | install MLton 20241230, SML/NJ 110.99.9 (64- and 32-bit) and Poly/ML 5.9.2 under `${RUNE_HOSTS:-~/.local/rune-hosts}`; needed once, before anything else |
| `make` | `bin/rune` (the self-hosted compiler), `bin/runevm`, `bin/runedoc` and `bin/runeopt` |
| `make mlton` / `make smlnj` / `make smlnj32` / `make polyml` | `bin/rune-mlton`, `bin/rune-smlnj`, `bin/rune-smlnj32`, `bin/rune-polyml`; none of them is `bin/rune` |
| `make host-builds` | all four host builds, of the compiler, of `runedoc` and of `runeopt` |
| `make runedoc` | `bin/runedoc`, the documentation generator ([docs/plans/docgen.md](plans/docgen.md)) compiled by `bin/rune`: `bin/runedoc.rbc` and the wrapper `bin/runedoc-boot`. `make runedoc-host-builds` makes `bin/runedoc-mlton`, `-smlnj`, `-smlnj32` and `-polyml` |
| `make runeopt` | `bin/runeopt`, the native code generator ([docs/native.md](native.md)) compiled by `bin/rune`: `bin/runeopt.rbc` and the wrapper `bin/runeopt-boot`. `make runeopt-host-builds` makes `bin/runeopt-mlton`, `-smlnj`, `-smlnj32` and `-polyml`. `runeopt prog.rbc -o prog` makes an executable of a program; `scripts/opt.sh prog.sml` does both steps |
| `make vm` | `bin/runevm`, and `bin/runevm-new`, `vm/new`'s loop for the register bytecode |
| `make vm-asan` | `bin/runevm-asan` and `bin/runevm-new-asan` with AddressSanitizer/UBSan; `make test-new-asan` runs `tests/lang` on the latter |
| `make test-new-jit` | `vm/new` with every function the JIT compiles compiled (`--jit=all`): `tests/lang` and the Basis Library suite (`rune:jit`), every program of `tests/lang` and `tests/perf` and `tests/opt/prims.sml` printing and counting the same interpreted and compiled and every instruction occurring in them (`scripts/check-jit.sh`), `runevm-new --jit-check`, and a recursion 200,000 deep under a machine stack of 1 MB, which holds the driver to never nesting ([plans/jit.md](plans/jit.md), M3, M4); part of `make check`. `make RUNE_JIT=0` builds `vm/new` without the JIT. `RUNEVM_JIT=MODE` in the environment is the mode where no `--jit=` is given |
| `make boot` | `bin/rune.rbc` (the compiler compiled by `bin/rune-$(BOOTHOST)`), the `bin/rune-boot` wrapper that runs it on `runevm`, and `bin/rune` → `rune-boot` |
| `make test` | run `tests/run-tests.sh` with `bin/rune`, and `tests/vm/run-vm-tests.sh`: bytecode files and options the VM must refuse with a message |
| `make test-all` | run the suite with each of the four host builds |
| `make isa` | write the tables of the instruction set and the primitives again from their descriptions in `src/isa`, with `runeisa` built by MLton: `vm/opcodes.def`, `vm/prims.def`, `vm/opcodes.h`, `vm/prims_table.h`, `src/backend/opcodes.sml`, `src/backend/prims.sml`; they are committed |
| `make check-isa` | fail when one of those files is not what `src/isa` gives, with `runeisa` built by MLton and by the self-hosted compiler; part of `make check` |
| `make test-ir` | the tests of the intermediate representations (`tests/ir`, [ir.md](ir.md)): the dumps of small programs compiled with the lint of every pass on |
| `make check-levels` | every program of `tests/lang` and `tests/perf` compiled at `-O0` and `-O2` with the lint on; where the bytecode differs, both runs must print and exit the same |
| `make docs` | write the generated documentation of the basis library, `docs/generated/basis`, with `bin/runedoc`; it is committed, and `make check-docs` fails when it is not what the sources give (`runedoc --check`) |
| `make test-doc` | run the tests of the documentation generator (`tests/doc/run-doc-tests.sh`) with `bin/runedoc`; `RUNEDOC=bin/runedoc-mlton` is the faster loop |
| `make test-native` | the suites with every program translated to native code by `runeopt` ([docs/native.md](native.md)): `tests/lang` through `bin/runevm-opt` (a VM for the runners that translates and runs; `tests/opt-skip.txt` lists what native code does not do yet), the check that every program of `tests/lang` counts what `runevm` counts (`tests/opt/run-counts.sh`), the Basis Library suite in the `rune:opt` configuration, and the compiler as native code compiling itself (`tests/opt/run-bootstrap.sh`). Linux on x86-64 only; elsewhere it does nothing. `make test-native-stress` runs it with a collection before every `GC_STRESS`-th allocation and `make test-native-asan` with a runtime built with the sanitizers; neither is part of `make check` |
| `make test-new` | the suites through `vm/new`'s first loop ([bytecode.md](bytecode.md), The register bytecode; [plans/middle-end.md](plans/middle-end.md), M5): `tests/lang` compiled by `bin/rune-new` (`bin/rune --target=registers`) and run by `bin/runevm-new`, the check that every program of `tests/lang` and `tests/perf` allocates on `vm/new` what it allocates on `runevm` and that the compiler on `vm/new` makes the bytecode it makes on `runevm` (`scripts/check-new.sh`), and the Basis Library suite in the `rune:new` configuration; part of `make check`. `make perf-check` also holds `vm/new` to its own budgets (`tests/perf/new`, `tests/perf/run-perf.sh --new`) |
| `make test-opt` | run the tests of the native code generator (`tests/opt/run-opt-tests.sh`) with `bin/runeopt`: the files it refuses, `--check` and `--disasm` over the programs the other suites compiled (so it runs after them), and a few programs translated, among them `tests/opt/every-opcode.rasm`, which runs every instruction; `RUNEOPT=bin/runeopt-mlton` is the faster loop |
| `make check-cross` | compile every test, example and Basis Library suite program, the compiler, `runedoc` and `runeopt` with all five builds and compare the bytecode; run the five builds of `runedoc` on the same input and compare what they write (`scripts/check-doc-cross.sh`), and the same for `runeopt` (`scripts/check-opt-cross.sh`) |
| `make check-docs` | verify docs, tests and `.def` files are in sync, that the library's signatures have the tokens of their transcriptions, that the comments of `lib/basis` and `src` are in the language of doc comments (`runedoc --lint`, [doc-comments.md](doc-comments.md)), that `docs/generated/basis` is up to date (which includes that the Basis Library suite has a check for every specified member of every structure: `runedoc` reads the suite's labels), and that the structures the library says implement a signature are the ones the suite matches against it (`tests/basis/check-claims.sh`), and that the notes of the documentation and `tests/basis/deviations.txt` agree (`tests/basis/check-notes.sh`) |
| `make test-basis` | run the Basis Library suite (`tests/basis`) with `bin/rune` |
| `make perf-check` | verify the performance budgets of `tests/perf`: instructions executed and bytes and objects allocated (`runevm --count`) by benchmark programs, by the compiler compiling `examples/hello.sml`, by the bootstrap and by `runedoc`, each at most 10 % above the recorded value, and the growth of the instruction count from n to 4n. The numbers are the same on every machine. `sh tests/perf/run-perf.sh --update` records new values after a deliberate change |
| `make bootstrap` | compile the compiler with `bin/rune` and check the result equals `bin/rune.rbc` |
| `make check` | all of the above (about 3 minutes on 16 CPUs, most of it spent running the compiler on the interpreter) |
| `make doctor` | check that the tools of all targets are installed and work; print how to install missing ones |
| `make matrix-quick` | the Basis Library suite on Rune and on Rune's library compiled by each host (the `xc1` configurations); not part of `make check` |
| `make matrix` | `matrix-quick` and the suite on each host's own library |
| `make perf` | the wall-clock times of the programs of `tests/perf` in the configurations of the matrix (`PERF_CONFIGS` selects others), one at a time, in `tests/out/perf/wall.md`; not part of `make check` |
| `make install` | install `rune`, `runevm`, `runedoc`, the basis library, the man pages and the shell completions under `PREFIX` |
| `make uninstall` | remove them again |
| `make clean` | remove `bin/`, `build/`, generated files and test output |

`bin/rune` runs on the VM and is about 35× slower than a host build, which
shows in the test targets (the suite takes about 15 s at `-j16` instead of
3 s). Every target that runs the compiler takes it from `$(RUNE)`, so
`make test RUNE=bin/rune-mlton` runs the same suite with the MLton build; that
is the loop to use while iterating. `RUNEVM=` selects the VM the same way.

Make runs recipes, and the test scripts run test programs, in parallel on
all available CPUs; `make JOBS=4 check` limits that to 4 (`tests/run-tests.sh`
and `scripts/check-cross.sh` take `-j N`).

The matrix targets are described in [basis-compat.md](basis-compat.md) and
`tests/basis/README.md`. `RUNE_HOSTS` (or `make HOSTS=...`) is where the hosts
are; `MLTON`, `MLBUILD`, `SMLNJ`, `MLBUILD32`, `SMLNJ32`, `POLY` and `POLYC`
name their commands one by one.

`CC=clang make vm` selects another C compiler. `BOOTHOST=smlnj make` picks the
host build that compiles stage 1 of the bootstrap.

## Windows

`make windows` builds the VMs for Windows with mingw-w64, for 64 bits,
`bin/runevm.exe` and `bin/runevm-new.exe`, and for 32 bits,
`bin/runevm32.exe` and `bin/runevm-new32.exe`. `make test-windows` runs the
language suite and `tests/vm` on all four (`tests/run-windows.sh`, once with
the stack bytecode of `bin/rune` and once with the register bytecode of
`bin/rune-new`), then the Basis Library suite on each.
Neither is part of any other target: `make check` never compiles
`vm/sys_win.c`, and nothing else in the tree depends on it. The toolchains
have to be installed (`x86_64-w64-mingw32-gcc` and `i686-w64-mingw32-gcc`,
which `WINCC` and `WINCC32` override; `make doctor` says whether they are),
and running the result needs Windows -- or WSL, which starts an `.exe` for
you, which is how it was developed and tested.

Only the VM differs: the compiler, the library and the bytecode are the ones
everything else uses, so the suite is compiled once, with the ordinary
`bin/rune`, and run on each VM. A value is 64 bits wide on both VMs, so
`Int`, `Word` and the positions of files are the same as on any other; the
32-bit VM computes with SSE2, as the 64-bit one does, and is linked
large-address-aware, which gives it 4 GiB of address space under 64-bit
Windows. The link is refused if an `.exe` imports a DLL of the toolchain
rather than of Windows.

The runner starts the VMs in a directory on the Windows side
(`$RUNE_WINDOWS_DIR`, or `rune-test-windows` in the `TEMP` directory of
Windows), not in the tree, which WSL would hand them as a network path, and
passes `TZ` to them through `WSLENV`. It also runs a few programs with
`--count` on each VM and on `bin/runevm`: the counts must agree.

`vm/sys_win.c` gives what Windows has -- the clock, the calendar, files,
directories, descriptors, the environment and running a command -- and
answers `ENOSYS` for what it does not do. A path of a drive comes back as
`/C:/Users/...`, because Rune's `OS.Path` is the one of POSIX, to which
that is absolute (no name of Windows has a colon in it), and a path that
goes in as `/C:/...` is given to Windows as `C:/...`; `/dev/null` is `NUL`
and `/dev/tty` the console. The standard streams are put in binary mode before
`main` runs, since a Rune string is bytes and a `\n` must stay one.

Windows has no `fork`. `Posix.Process.fork` starts a second VM instead and
hands it everything of this one: the heap, the stacks, the program, and the
descriptors, sockets and directory streams (`vm/image.c`); the child carries
on from the `fork` as a copied process would. `runevm --emulate-fork` takes
the same path on Linux, so that `make check` tests the image
(`tests/lang/rt.fork_image`), which the Windows suites cannot do under ASan.

**What a fork of this kind costs**, measured with `--emulate-fork` on a
64-bit Linux VM, best of five runs of twenty forks: about 30 ms, and about
3 to 4 ms for each MB of live heap -- so 30 ms with nothing live, 93 ms with
16 MB and 267 ms with 64 MB, against 0 to 2 ms for a real `fork`. Most of the
fixed part is starting a process; the rest is the image through a pipe.

The child checks the program in the image as it would a `.rbc`, since
`Runtime.restore` means an image can now come from a file rather than only
from a parent (`vm/loader.c`, `validate_program`). That check costs about
3 µs for each KB of code: 14 µs for a program of the size of
`examples/hello.sml`, and 1.5 ms for `bin/rune.rbc`, which at 479 KB of code
in 2,343 functions is the largest program in the tree. Against the 30 ms a
fork costs anyway that is under a tenth of a percent for an ordinary program
and about 5% for the largest, so there is no way to turn it off: an image that
is not checked is a way to run code that was never loaded.

Both VMs run every program of `tests/lang`; `tests/windows-skip.txt` names
those to leave out, with a reason for each, and is empty. The checks of the
Basis Library suite that do not pass are the `WINDOWS` lines of
`tests/basis/deviations.txt`, each saying what Windows does instead.

A healthy `make test-windows` takes about 8 minutes and reports, for each
VM, all 141 programs of `tests/lang` passing with none skipped, `tests/vm`
11 of 11, and 194 of the 137,240 checks of the Basis Library suite failing,
every one of them explained by a `WINDOWS` line.

What Windows does not get: `OS.Path` keeps the rules of POSIX rather than
the drive letters and backslashes of Windows, which is why a path of a drive
reaches a program as `/C:/...`; `bin/rune` itself is not run on the Windows
VMs, only the VM is built and tested there; and nothing of this runs in
continuous integration.

## Another machine's VM

`make check` builds the VMs for this machine alone, so it says nothing about a
machine of another width or another order of bytes. `make portability` builds
them for two more, both Linux, so that only the VM differs:

| | |
|---|---|
| `bin/runevm32`, `bin/runevm-new32` | a 32-bit x86, where a pointer is four bytes and the System V ABI aligns an `int64_t` to four |
| `bin/runevm-ppc64`, `bin/runevm-new-ppc64` | a 64-bit PowerPC, big-endian; a wrapper that runs `bin/runevm-ppc64.bin` (`bin/runevm-new-ppc64.bin`) under `qemu-ppc64`, as `bin/rune-mlton` wraps its payload |

The PowerPC one is built with clang, which cross-compiles without a gcc for
the target, using the linker and the headers of a sysroot (`PPCROOT`, by
default `/usr/powerpc64-linux-gnu`). `make doctor --scope portability` says
what is missing and what to install.

`make test-portability` runs `tests/lang` and `tests/vm` on each, once with
the stack bytecode on `bin/runevm32` and `bin/runevm-ppc64` and once with
the register bytecode on `bin/runevm-new32` and `bin/runevm-new-ppc64`, and
the Basis Library suite as the configurations `rune:linux32`, `rune:ppc64`,
`rune:linux32-new` and `rune:ppc64-new`. Then two things no single VM can
show:

* the counts of `runevm --count` must agree **to the byte** on every VM and on
  this one. They are the instructions executed and the bytes and objects
  allocated, and they depend on the program and its input alone, so a VM that
  lays out a value differently says so here.
* an image of `Runtime.save` must cross **in every direction**: each VM writes
  one and each of the others reads it. The program prints its answer before
  saving and again once restored, so the two are compared with each other.

The PowerPC VM is linked with an rpath as well as `-L`, so that it loads both
when the wrapper starts it and when the kernel does. That second way is what a
fork by a second VM needs: it starts the child by exec of the VM's own binary,
and qemu-user does not emulate a program it is handed by exec -- the kernel has
to know what a PowerPC binary is, which means qemu registered under
`/proc/sys/fs/binfmt_misc`. On WSL systemd will not do that for itself, since
it ships `ConditionVirtualization=!wsl` for `systemd-binfmt.service` to keep
its own `WSLInterop` registration, which `make test-windows` needs; register
qemu beside that one rather than by starting the service, which flushes every
registration first (`tests/portability-skip.txt` has the command). Without it,
`rt.fork_image` is the one program to leave out.

It found two bugs when it was written. A `Value` was 12 bytes on a 32-bit
Linux, where the ABI aligns an `int64_t` to four and every other target
Rune builds for aligns it to eight -- so every object of the heap was a
different size there, the counts disagreed, and an image would not have
crossed; the padding is now written out (`vm/vm.h`, and
[plans/performance.md](plans/performance.md) for why 16 bytes and not 12). And
`vm/sys_posix.c` asked for `_POSIX_C_SOURCE` alone, under which an older
glibc's headers do not declare `realpath`.

Nothing here is part of `make check`, and nothing here is Windows: the VMs of
Windows are `make test-windows`, which carries an image between Windows and
this system in the same way.

## Installing

`make install` copies a built tree into `PREFIX`, which defaults to
`/usr/local` when the effective user is root and to `~/.local` otherwise:

```
$PREFIX/bin/rune                     wrapper: runevm + rune.rbc + --lib
$PREFIX/bin/runedoc                  wrapper: runevm + runedoc.rbc + --lib
$PREFIX/bin/runeopt                  wrapper: runevm + runeopt.rbc + --runtime
$PREFIX/bin/runevm                   the VM
$PREFIX/lib/rune/rune.rbc            the compiler
$PREFIX/lib/rune/runedoc.rbc         the documentation generator
$PREFIX/lib/rune/runeopt.rbc         the native code generator
$PREFIX/lib/rune/runtime/            librune.a and rune-offsets.s, what
                                     runeopt links a program with
$PREFIX/lib/rune/basis/              MANIFEST and the basis library sources,
                                     overview.doc and DOCUMENTED for runedoc
$PREFIX/share/man/man1/              rune.1, runevm.1, runedoc.1, runeopt.1
$PREFIX/share/bash-completion/completions/rune, runedoc, runeopt
$PREFIX/share/zsh/site-functions/    _rune, _runevm, _runedoc, _runeopt
```

The installed `rune` and `runedoc` derive the library path from their own
location (`$(dirname $0)/../lib/rune`), so the tree can be moved or staged.
`runedoc` is installed when it is built, which `make install` sees to:
`runedoc --library ./mylib --out docs/mylib` documents a library of your own
on top of the installed Basis Library (`man runedoc`), and `runedoc --library
basis --out DIR` writes the pages of the Basis Library, without the test
inventory, which needs the suite of the sources. `runeopt` is installed the
same way, with the runtime it links a program with; it needs a C compiler
where it runs (`man runeopt`).

* As a normal user `make install` builds whatever is missing first.
* As root it builds **nothing** — it installs `bin/` as it stands and fails if
  it is empty. So the sequence is `make && sudo make install`, and a root
  install never leaves root-owned files in the checkout.
* `make install PREFIX=/opt/rune` installs elsewhere; `DESTDIR=/tmp/stage`
  stages the whole tree under another root for packaging.
* `make install HOST=mlton` installs the MLton host build instead of the
  bytecode compiler: `$PREFIX/bin/rune-mlton` with its payload in
  `$PREFIX/lib/rune`, and `rune` as a symlink to it. `HOST=polyml` and
  `HOST=smlnj` work the same way (`smlnj` installs the heap image, which runs
  with the SML/NJ that `make hosts` installed). `runevm` is installed either way, since it runs
  what the compiler produces.
* `make uninstall` (with the same `PREFIX`, `DESTDIR` and `HOST`) removes it.

`scripts/install.sh` does the work and takes the same settings as
`--prefix`, `--destdir`, `--host` and `--uninstall`.

## How the build works

* `sources.txt` is the single ordered list of compiler source files.
  `scripts/gen-build-files.sh` generates `build/rune.mlb` (MLton),
  `build/rune.cm` (SML/NJ), `build/polyml-build.sml` (Poly/ML `use` script)
  and `build/config.sml` (the version) from it.
  **Add new source files to `sources.txt` only.**
* `sources-doc.txt` is the same for `runedoc`: the compiler's utilities,
  frontend and elaborator in the order of `sources.txt`, then `src/doc`. The
  script makes `build/runedoc.mlb`, `build/runedoc.cm` and
  `build/runedoc-polyml-build.sml` from it; the entry points are
  `src/main/runedoc-*-main.sml`. A file that both lists name is compiled into
  both programs, so the rules below hold for `src/doc` as well. The SML/NJ
  builds run one after another, because CM keeps its results for all of them
  in the same `.cm` directories.
* `sources-opt.txt` is the same for `runeopt`, with `src/opt`; the entry
  points are `src/main/runeopt-*-main.sml`, and the rules below hold for
  `src/opt` too.
* The instruction set and the primitives are described once, in Standard
  ML: `src/isa/stack.sml` and `src/isa/prims.sml`, in the language of
  `src/isa/isa.sml`. `runeisa` (`sources-isa.txt`, `src/isa`) writes from
  them `vm/opcodes.h`, `vm/prims_table.h`, `src/backend/opcodes.sml`,
  `src/backend/prims.sml`, and `vm/opcodes.def` and `vm/prims.def`, which the
  scripts read. All of them are committed, so that the VM builds with a C
  compiler alone: `make isa` writes them again, and `make check-isa`, part of
  `make check`, fails when one is not what the descriptions give. The C
  dispatch table in `vm/prims.c` is built from the generated
  `RUNE_PRIM_LIST` X-macro, so adding a primitive means: add it at the end of
  `src/isa/prims.sml`, run `make isa`, implement `p_<name>` in `vm/prims.c`,
  document it in `docs/bytecode.md`.
* Entry points: `src/main/mlton-main.sml`, `src/main/polyml-main.sml` and
  `src/main/rune-main.sml` (the self-hosted build) call `Main.main`; SML/NJ's
  `ml-build` exports `Main.main` directly. Each of the four `bin/rune*` files
  is a generated shell wrapper that passes `--lib` and execs the payload next
  to it (`rune.rbc` on `runevm`, `rune-mlton.bin`, `rune-polyml.bin`, or the
  heap image with the `sml` of `make hosts`).

## Bootstrapping

The compiler is written in the language it compiles, so it builds itself, and
the result is the compiler you get:

1. `make boot` compiles `build/config.sml`, the files of `sources.txt` and
   `src/main/rune-main.sml` with `bin/rune-$(BOOTHOST)` into `bin/rune.rbc`
   (stage 1), writes `bin/rune-boot`, a wrapper that runs
   `runevm --heap-size $(RUNE_HEAP) bin/rune.rbc`, and points `bin/rune` at
   it. `make` does this too. `BOOTHOST` is `mlton`, `smlnj`, `smlnj32` or
   `polyml`; they all emit the same bytecode, so it only decides which host
   build compiles stage 1.
2. `bin/rune` takes the same options as the host builds, so `make test` runs
   the whole suite with it and `make check-cross` compares its bytecode with
   the four host builds on every test program, the examples, and the
   compiler sources themselves. `check-cross` knows it as the build `boot`,
   hence the name `bin/rune-boot`.
3. `make bootstrap` compiles the compiler with `bin/rune` into
   `bin/rune.stage2.rbc` and checks with `cmp` that it is identical to
   `bin/rune.rbc`: the compiler reproduces itself byte for byte.

`RUNE_HEAP` (64 MiB) is only the semispace mapped up front; the heap grows on
demand. Between 32 MiB and 256 MiB the bootstrap varies by under 3%, so the
default is chosen to keep the resident set down when `-j16` compilers run at
once.

All of this relies on the compiler being deterministic (ordered maps and
counter-generated stamps, rule 5 below) and on its sources staying inside the
language Rune accepts (rule 6). If stage 2 ever differs from stage 1, diff the
`runevm --disasm` output of the two files, then the `--dump-lambda` /
`--dump-code` output of `bin/rune-mlton` and `bin/rune` on the first
differing input. `src/util/ordmap.sml` (a functor applied twice) is the
module-system acceptance test of the bootstrap.

## Portability rules for compiler sources

The SML systems differ in ways that matter; the code base follows these
rules so that one source tree builds everywhere and emits identical output:

1. Only the part of the SML Basis Library (2004 revision) that Rune's own
   basis provides is used—no SML/NJ library, no compiler-specific structures
   outside `src/main/`.
2. Every file contains only top-level `structure`, `signature` and `functor`
   declarations (required by SML/NJ's CM).
3. Never depend on the width of `Int`: it is 31-bit on the 32-bit SML/NJ and
   63-bit on the 64-bit one, 32-bit on MLton and arbitrary on Poly/ML. Source literals are kept as
   `IntInf.int`; bytecode immediates are limited to ±2^30; 64-bit values are
   serialized from `IntInf` with `quot`/`rem` (with explicit `IntInf`
   operations, see rule 6).
4. Reals are never converted to binary by the compiler; they travel to the VM
   as their literal text.
5. All iteration over maps uses the ordered `StringMap`/`IntMap` from
   `src/util/ordmap.sml`, and every generated name/stamp comes from a counter,
   so output is deterministic across hosts. A hash table (`IntTable`,
   `src/util/inttable.sml`) is only set and asked by key, never listed.
6. The compiler must be compilable by Rune itself, so its sources stay inside
   the language described in `docs/language.md`: in particular no literal or
   operator overloading at `IntInf.int` (write `IntInf.fromInt n` and
   `IntInf.+ (a, b)`), and only the Basis subset Rune provides.

## Using the compiler

```
bin/rune [options] file.sml ...      # produces first-file.rbc (or -o FILE)
bin/runevm [options] file.rbc [args] # runs it
bin/rune-mlton [options] file.sml ... # the same compiler, built by MLton
bin/runeopt file.rbc -o prog          # an executable of it (Linux, x86-64)
RUNEVM_OPTIONS=--count ./prog [args]  # runs it, with the options of runevm
```

Run `bin/rune --help` and `bin/runevm --help` for the option lists, or
`man rune` and `man runevm` after `make install`. Exit
status of `rune`: 0 success, 1 compile error or usage error. Exit status of
`runevm`: the program's `OS.Process.exit` status, 1 for an uncaught exception,
2 for VM errors (bad bytecode file, out of memory).
