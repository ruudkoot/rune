# Building Rune

Rune consists of the compiler `rune` (written in portable Standard ML) and the
virtual machine `runevm` (C17, and C99 with a switch). The compiler builds unchanged with **MLton**,
**SML/NJ** 110.99.9 (for 64 and for 32 bits), **SML/NJ** 2026.2, **Poly/ML** and **MLKit**; all these
builds produce byte-identical bytecode (`make check-cross` verifies this).

The compiler Rune ships is the one it compiled itself: **`bin/rune`** is
`bin/rune.rbc` running on `runevm`. The host builds `bin/rune-mlton`,
`bin/rune-smlnj-legacy`, `bin/rune-smlnj32`, `bin/rune-smlnj-dev`, `bin/rune-polyml` and `bin/rune-mlkit` have two jobs — to
bootstrap that one, and to check it (`make check-cross`, `make test-all`). Everything that runs,
tests or measures the compiler goes through `bin/rune`.

The compiler knows no library location of its own: it takes the basis library
from `--lib DIR` (which it reads from `DIR/basis`) and refuses to compile
without it. Each of the `bin/rune*` is therefore a small wrapper script
that passes `--lib` for the tree it sits in, and the payload of a host build
lives next to it as `bin/rune-mlton.bin`, `bin/rune-polyml.bin`,
`bin/rune-mlkit.bin`, `bin/rune-smlnj-legacy.heap.amd64-linux`,
`bin/rune-smlnj-dev.heap.amd64-linux` or
`bin/rune-smlnj32.heap.x86-linux`. Because the wrapper puts `--lib` first, a
`--lib` of yours comes later on the command line and wins. Nothing absolute is
baked into `bin/rune.rbc`, so it does not depend on where the checkout is.

The compiler makes the register bytecode of `bin/runevm` unless told
`--target=stack`, the stack bytecode of `bin/runevm-stack`. `bin/rune.rbc`,
`runedoc.rbc` and `runeopt.rbc` are register bytecode, which their wrappers
(`bin/rune-boot`, `runedoc-boot`, `runeopt-boot`) run on `runevm`. The
same programs in stack bytecode, `bin/rune.stack.rbc`, `runedoc.stack.rbc`
and `runeopt.stack.rbc`, are for what needs it: the budgets of `runevm-stack`,
and what `runeopt` translates. The suites that run `runevm-stack` compile with
`bin/rune-stack`, the compiler under test (`RUNE=`, `bin/rune` by default)
with `--target=stack`; that wrapper is written whenever make reads its
Makefile, and is where the scripts of `tests/` look when they are run by
hand.


## GMP dependency

`make GMP=auto|yes|no` controls the register VM's optional arithmetic backend.
`auto` checks a system installation through pkg-config; `yes` requires a
successful compile/link/run check, and `no` builds without GMP. Rune requires
GMP 6.3.0 or newer, matching header/library major versions and limb widths,
and no nails. Explicit unsupported requests fail clearly. Switching the mode
relinks the VM; it does not change bytecode primitive identities. The stack
VM and `build/librune.a` remain GMP-free. `bin/runevm-sml` is a GMP-free
register VM useful for checking the same bytecode on both builds.

CI and release builds use the pinned recipe rather than the system package:

```
python3 scripts/build-gmp.py --jobs 4
make GMP=yes GMP_PREFIX=build/deps/gmp/native
```

The recipe verifies GMP 6.3.0's source archive SHA-256
`a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898`,
builds a static library, runs upstream tests, and records the source URL,
checksum, compiler, requested and configured options, target, commands and
installed library/header hashes. Reusing its cache verifies those installed
hashes. `GMP_PREFIX` can also select a checked local prefix; absent pinned
metadata, provenance is explicitly local/unknown. System builds report
unknown source/build options instead of attributing them to the pinned recipe.
The recipe retains license notices beside the dependency. `--cc`, `--host`,
`--runner` and `--prefix` support separate cross-build trees; platform release
validation is recorded in the GMP roadmap.

Configuration evidence is in `build/gmp/KEY/config.json`; `runevm --version`
reports the header and linked-library versions and embedded provenance. The
runtime rechecks compatibility too. The pin is dependency provenance, not a
correctness proof: independent SML arithmetic and bounded oracle tests remain
required.

## Prerequisites

The acceptance tests also need Python 3. The compiler-driver tests use its
POSIX resource controls to interrupt a bytecode write and check that the previous
artifact survives, and the VM tests check saved limits and stricter restore
policies (`compiler/*` and `limits/*` of `tests/runner/tools.sml`).

* A C compiler (`cc`; gcc 13 and clang 18 are tested), GNU make 4.3 or later, POSIX `sh`, `awk`. The VMs are built as C17 (`-std=c17`), and what they take from it beyond C99 is behind a test of `__STDC_VERSION__` (the header word of a `Value`, `runtime/vm.h`), so `make CFLAGS='-std=c99 -O2'` builds them too, a little slower. Where the compiler is gcc or clang the VM's loop goes from instruction to instruction by computed goto, a GNU extension; `make CFLAGS='-std=c99 -O2 -DRUNE_SWITCH'` builds the switch every C compiler has.
* The SML systems that build the compiler, which `make hosts`
  (`scripts/fetch-hosts.sh`) installs under `${RUNE_HOSTS:-~/.local/rune-hosts}`:
  MLton 20241230 (the binary release), SML/NJ 110.99.9 built for 64 bits and
  for 32 bits, SML/NJ 2026.2 (the development line, 64-bit only; `build.sh`
  compiles its bundled LLVM and needs CMake 3.23, a C++17 compiler and
  python3), Poly/ML 5.9.2 (built from source) and MLKit 4.7.25 (the
  binary release, whose SHA-256 is checked, on Linux x86-64; elsewhere built
  from the release's tag with the MLton just installed, which needs more
  memory than a machine of 16 GB has, so that this way is untested). An SML system the machine has on its `PATH` is never used,
  and none of these builds starts from one: MLton and MLKit are binaries,
  SML/NJ builds its C runtime and loads its compiler from the boot files of
  the same release, and Poly/ML bootstraps from its own portable image and
  rebuilds its compiler with the result. `make hosts` runs the builds with
  `mlton`, `sml`, `poly`, `polyc` and `mlkit` replaced by commands that
  fail, so an accidental dependency on the machine's SML shows. MLKit finds
  its Basis Library only through `SML_LIB`, which every command that runs
  it sets (`MLKIT_LIB`, default `lib/mlkit` of the installed MLKit), and it
  keeps what it compiles in `MLB/` directories beside the sources, which
  `make clean` removes. It needs `curl` or `wget`, `tar`, `xz`, a C and a
  C++ compiler, GMP (`libgmp-dev`) and a C compiler that builds 32-bit
  programs (`gcc-multilib`), and, for SML/NJ 2026.2, CMake 3.23 or later
  and python3. The 2026.2 build is the slow one: it compiles LLVM. No root
  access. `make` needs MLton (`BOOTHOST` names the host build that
  bootstraps `bin/rune`, default `mlton`); `make test-all`,
  `make check-cross`, the matrix targets and `make check` need all six.

`make doctor` checks all of this (and the tools of the test, sanitizer, host
matrix and profiling targets), by running the tools rather than just looking
for them: it compiles a C program, and a program with MLton, with
`polyc` and with MLKit. For everything that is missing it prints the install command of the
system's package manager (`apt`, `dnf`, `pacman` or `brew`) and exits with
status 1; optional tools only produce warnings.

The build and test targets run the same check for the tools they need, once,
before they first run (`scripts/doctor.sh --quiet --scope <scope>`; a stamp
`build/.doctor-<scope>` records success, so the check is repeated after
`make clean` or when the script changes). `make DOCTOR=no ...` skips it, and
`CC`, `MLTON`, `SMLNJ`, `SMLNJ32`, `POLY`, `POLYC`, `MLKIT` and `MLKIT_LIB`
name the tools to check.

## Targets

| Command | Result |
|---|---|
| `make hosts` | install MLton 20241230, SML/NJ 110.99.9 (64- and 32-bit), SML/NJ 2026.2, Poly/ML 5.9.2 and MLKit 4.7.25 under `${RUNE_HOSTS:-~/.local/rune-hosts}`; needed once, before anything else |
| `make` | `bin/rune` (the self-hosted compiler), `bin/runevm`, `bin/runevm-stack`, `bin/runedoc` and `bin/runeopt` |
| `make mlton` / `make smlnj-legacy` / `make smlnj32` / `make smlnj-dev` / `make polyml` / `make mlkit` | `bin/rune-mlton`, `bin/rune-smlnj-legacy`, `bin/rune-smlnj32`, `bin/rune-smlnj-dev`, `bin/rune-polyml`, `bin/rune-mlkit`; none of them is `bin/rune` |
| `make host-builds` | all six host builds, of the compiler, of `runedoc` and of `runeopt` |
| `make runedoc` | `bin/runedoc`, the documentation generator ([docs/plans/docgen.md](plans/docgen.md)) compiled by `bin/rune`: `bin/runedoc.rbc` and the wrapper `bin/runedoc-boot`. `make runedoc-host-builds` makes `bin/runedoc-mlton`, `-smlnj-legacy`, `-smlnj32`, `-smlnj-dev`, `-polyml` and `-mlkit` |
| `make runeopt` | `bin/runeopt`, the native code generator ([docs/native.md](native.md)) compiled by `bin/rune`: `bin/runeopt.rbc` and the wrapper `bin/runeopt-boot`. `make runeopt-host-builds` makes `bin/runeopt-mlton`, `-smlnj-legacy`, `-smlnj32`, `-smlnj-dev`, `-polyml` and `-mlkit`. `runeopt prog.rbc -o prog` makes an executable of a program compiled with `--target=stack`; `scripts/opt.sh prog.sml` does both steps |
| `make vm` | `bin/runevm-stack`, and `bin/runevm`, `runtime/register`'s loop for the register bytecode |
| `make vm-asan` | `bin/runevm-stack-asan` and `bin/runevm-asan` with AddressSanitizer/UBSan; `make test-register-asan` runs `tests/lang` on the latter |
| `make test-register-jit` | `runtime/register` with every function compiled (`--jit=all`): `tests/lang` and the Basis Library suite (`rune:jit`), every program of `tests/lang` and `tests/perf`, `tests/opt/prims.sml` and the compiler compiling itself printing and counting the same interpreted, compiled, with every other function compiled (`--jit-only=odd`, so that calls, returns and raises cross between the tiers both ways) and under `--jit-stress` (tiered up at the lowest thresholds and invalidated every fifth call) and every instruction occurring in them (the oracle `jit` of `tests/runner/oracles.sml`), `runevm --jit-check`, and a recursion 200,000 deep under a machine stack of 1 MB, which holds the driver to never nesting ([plans/jit.md](plans/jit.md), M3-M5); part of `make check`. `make RUNE_JIT=0` builds `runtime/register` without the JIT. `RUNEVM_JIT=MODE` in the environment is the mode where no `--jit=` is given |
| `make boot` | `bin/rune.rbc` (the compiler compiled by `bin/rune-$(BOOTHOST)`), the `bin/rune-boot` wrapper that runs it on `runevm`, and `bin/rune` → `rune-boot`; `bin/rune.stack.rbc` is the same compiler in the stack bytecode |
| `make test` | the programs of `tests/lang` and `tests/errors` compiled by `bin/rune-stack` (`bin/rune --target=stack`, written by every `make`, for `RUNE=` if you give one) and run on `bin/runevm-stack`, on the runner (`bin/rune-test run --tier test`; `tests/runner/lang.sml`), and `make test-steps`: the compiler's own tests, the runtime's limits and collector log, `tests/runtime/run-vm-tests.sh` (bytecode files and options the VM must refuse with a message) and the C test of the heap. `make test-heap`, `test-gc`, `test-all`, `test-native`, `test-register` and `test-register-jit` run `tests/lang` in their ways the same way, each by its tag, and the rest of what they run as `make TARGET-steps` |
| `make test-all` | run the suite with each of the six host builds |
| `make isa` | write the tables of the instruction set and the primitives again from their descriptions in `src/isa`, with `runeisa` built by MLton: `runtime/stack/opcodes.def`, `runtime/prims.def`, `runtime/isa.h`, `runtime/stack/opcodes.h`, `runtime/prims_table.h`, `src/backend/opcodes.sml`, `src/backend/prims.sml`; they are committed |
| `make check-isa` | fail when one of those files is not what `src/isa` gives, with `runeisa` built by MLton and by the self-hosted compiler; part of `make check` |
| `make test-ir` | the tests of the intermediate representations (`tests/ir`, [ir.md](ir.md)): the dumps of small programs compiled with the lint of every pass on |
| `make check-levels` | every program of `tests/lang` and `tests/perf` compiled at `-O0` and `-O2` with the lint on; where the bytecode differs, both runs must print and exit the same |
| `make check-units` | every program of `tests/lang` and `tests/perf` compiled whole and a unit per file, at `-O0`, `-O1` and `-O2`, without the cache of units, through it and from it; all must print and exit the same, the builds through and from the cache be the bytes of the one without it, and the unit files linked or loaded do the same; and the compiler compiled in units compiling itself ([units.md](units.md)) |
| `make test-deps` | the dependency graph: files ordered by the modules they declare and use, a cycle, a name declared twice and a file that breaks the discipline refused, the graph as DOT, and an entry point with `-I` compiling the files it needs and only those (`tests/deps/run.sh`; [units.md](units.md), *The graph*) |
| `make test-dynamic` | dynamic modules: a module through `_dynamic`, with an abstract type, a datatype declared in another order, a polymorphic value and an exception across the boundary, under the interpreter and `--jit=all`; a module of another signature refused; a plugin through `Dynamic.load`; two modules sharing a library's types; a whole program refused (`tests/dynamic/run.sh`; [units.md](units.md), *Dynamic modules*) |
| `make test-serve` | the compiler as a service, a prototype: `rune --serve` driven over its standard streams -- the diagnostics of a buffer with errors and without, the type of a function and of a variable at an offset, an unknown method, shutdown -- and what a request takes (`serve/*` of `tests/runner/protocols.sml`; the incremental roadmap's M12) |
| `make check-reproducible` | the compiler built from `rune.build` the same bytes in units and whole, without the cache, through a cold cache and warm, by one process and with `-j`, and from a copy of its sources elsewhere; the whole builds `bin/rune.rbc` (the oracle `reproducible` of `tests/runner/oracles.sml`; [units.md](units.md), *Parallel builds*) |
| `make test-build` | build files: a list, `local`, a library's exports, a group put in order, a build file used twice and elaborated once, an annotation, a path variable, a virtual module with either implementation and the other's units from the cache, and the errors (`tests/buildfile/run.sh`; [build.md](build.md)) |
| `make test-install` | `make install` staged with `DESTDIR` under another prefix, for the bytecode compiler and for the MLton and SML/NJ host builds: every file each library's `MANIFEST` names is installed, the man pages carry the version, the installed `rune`, `runevm`, `runevm-stack`, `runeopt`, `runedoc`, `rune-repl` (with `--dap`) and `rune-kernel --install` work from where they landed without naming the tree, and `make uninstall` with the same options leaves no file (`tests/install/run.sh`) |
| `make test-incremental` | the cache's scenarios: a project edited, reverted, broken, built at two levels, its cache damaged or shared by two compiles, each build holding to what it must compile again (`tests/incremental/SCENARIOS.md`), and a project edited mechanically, each warm build the bytes of compiling everything (`tests/incremental/mutate.py`) |
| `make test-repl` | the REPL's transcripts on every mode of the JIT ([repl.md](repl.md)) |
| `make test-terminal` | programs on a terminal: the scripts of `tests/terminal` in a tmux pane, skipped without tmux ([testing.md](testing.md), *Programs on a terminal*) |
| `make test-diagnostics` | diagnostics rendered with colour and excerpts (`tests/diagnostics`), and the contrast of the palette (`tests/color`) ([diagnostics.md](diagnostics.md)) |
| `make docs` | write the generated documentation of the basis library, `docs/generated/basis`, with `bin/runedoc`; it is committed, and `make check-docs` fails when it is not what the sources give (`runedoc --check`) |
| `make test-doc` | run the tests of the documentation generator with `bin/runedoc`, a test each on the runner (`doc/*`, `tests/runner/tools.sml`); `bin/rune-test run --accept 'doc/NAME'` rewrites what one expects |
| `make test-native` | the suites with every program translated to native code by `runeopt` ([docs/native.md](native.md)): `tests/lang` through `bin/runevm-native` (a VM for the runners that translates and runs; `tests/opt-skip.txt` lists what native code does not do yet), the check that every program of `tests/lang` counts what `runevm-stack` counts (`tests/opt/run-counts.sh`), the Basis Library suite in the `rune:opt` configuration, and the compiler as native code compiling itself (`tests/opt/run-bootstrap.sh`); and `tests/lang` again under the low-pause collector with a cycle of incremental marking always under way (`--gc-stress-cycles`), for the barrier's flag in native code. Linux on x86-64 only; elsewhere it does nothing. `make test-native-stress` runs it with a collection before every `GC_STRESS`-th allocation and `make test-native-asan` with a runtime built with the sanitizers; neither is part of `make check` |
| `make test-heap` | the collector and its hooks ([runtime.md](runtime.md), What is in place for the collector; [plans/heap-layout.md](plans/heap-layout.md), M7; [plans/garbage-collector-v2.md](plans/garbage-collector-v2.md), M2 and M3): the C test of them (`tests/runtime/heap_test.c`) on the runtime as built, with `-DRUNE_GC_BITS` and with `-DRUNE_BARRIER_CARDS`; `tests/lang` on `bin/runevm-gcbits`, whose collector sets the header's four bits on every object it copies, as it comes and with every function compiled and a collection at every 101st allocation; `tests/lang` on `bin/runevm-cards`, whose barrier also marks a card of the process's table; and `tests/lang` with the heap checked before and after every collection (`--gc-verify`), in a heap of 64 KiB with a nursery of 8 KiB. Part of `make check`; the C test on the runtime as built is part of `make test` too |
| `make test-gc` | the two collectors ([runtime.md](runtime.md), *The garbage collector*): `tests/lang` under `--gc throughput` and `--gc low-pause` on both VMs with the heap checked before and after every collection of a heap of 64 KiB and a nursery of 8 KiB (`--gc-verify`), under the low-pause collector with every function compiled and a collection at every 101st allocation, under each with the old space compacted at every full collection (`--gc-compact`), and on both VMs under the low-pause collector with a cycle of incremental marking always under way and the heap checked at every minor collection (`--gc-stress-cycles`). Part of `make check` |
| `make test-register` | the suites through `runtime/register`'s first loop ([bytecode.md](bytecode.md), The register bytecode; [plans/middle-end.md](plans/middle-end.md), M5): `tests/lang` compiled by `bin/rune` (`bin/rune --target=registers`) and run by `bin/runevm`, the check that every program of `tests/lang` and `tests/perf` allocates on `runtime/register` what it allocates on `runevm-stack` and that the compiler on `runtime/register` makes the bytecode it makes on `runevm-stack`, with the check that the collector drops a waiting frame's dead registers and keeps its live ones at every tier (the oracle `register` of `tests/runner/oracles.sml`; `tests/register/dead-roots.sml`), and the Basis Library suite in the `rune:new` configuration; part of `make check`. `make perf-check` also holds `runtime/register` to its own budgets (`tests/perf/new`, `tests/perf/run-perf.sh --new`) |
| `make vm-census` / `make test-census` | `bin/runevm-census`, the census VM ([census.md](census.md)): `runtime/register`'s loop with the hooks of `runtime/census/census.h`, which writes a trace of every allocation, field, store into an object and death, and at every sample the stack and the instruction count; `test-census` runs it beside `bin/runevm --jit=off` on a program of `tests/perf` and checks the same `--count` line and output, that the trace accounts for every byte and object the count reports, the trace's consistency (`tools/heapsim/checktrace.py`, where python3 has numpy), the summary mode and the static census (`scripts/check-census.sh`, under a second); part of `make check` |
| `make heapsim` / `make check-heapsim` / `make check-gcsim` | `bin/heapsim`, `bin/heapsim-gen` and `bin/gcsim`, the simulators that replay a census trace under models of collectors ([tools/heapsim/README.md](../tools/heapsim/README.md)); `check-heapsim` holds heapsim's copier to an exact one on synthetic traces and to `bin/runevm --stats` at five heap settings on compile-sigs and intinf_fact, whose traces it makes (`tools/heapsim/test.sh`, `validate.sh`; about 25 seconds, half of it the census of compile-sigs), and `check-gcsim` holds gcsim's models to traces whose answers are known in closed form and to heapsim's models (`tools/heapsim/test2.sh`, 2 seconds); both part of `make check` |
| `make test-opt` | run the tests of the native code generator (`tests/opt/run-opt-tests.sh`) with `bin/runeopt`: the files it refuses, `--check` and `--disasm` over the programs the other suites compiled (so it runs after them), and a few programs translated, among them `tests/opt/every-opcode.rasm`, which runs every instruction; `RUNEOPT=bin/runeopt-mlton` is the faster loop |
| `make check-cross` | compile every test, example and Basis Library suite program, the compiler, `runedoc` and `runeopt` with all six builds and compare the bytecode; run the six builds of `runedoc` on the same input and compare what they write (the oracle `cross` of `tests/runner/oracles.sml`), and the same for `runeopt` (the oracle `cross` of `tests/runner/oracles.sml`) |
| `make check-docs` | verify docs, tests and `.def` files are in sync, that the library's signatures have the tokens of their transcriptions, that the comments of `lib/basis` and `src` are in the language of doc comments (`runedoc --lint`, [doc-comments.md](doc-comments.md)), that `docs/generated/basis` is up to date (which includes that the Basis Library suite has a check for every specified member of every structure: `runedoc` reads the suite's labels), and that the structures the library says implement a signature are the ones the suite matches against it (`tests/basis/check-claims.sh`), and that the notes of the documentation and `tests/basis/deviations.txt` agree (`tests/basis/check-notes.sh`) |
| `make test-basis` | run the Basis Library suite (`tests/basis`) with `bin/rune` |
| `make perf-check` | verify the performance budgets of `tests/perf`: instructions executed and bytes and objects allocated (`runevm-stack --count`) by benchmark programs, by the compiler compiling `examples/hello.sml`, by the bootstrap and by `runedoc`, each at most 10 % above the recorded value, and the growth of the instruction count from n to 4n. The numbers are the same on every machine. `sh tests/perf/run-perf.sh --update` records new values after a deliberate change |
| `make bootstrap` | compile the compiler with `bin/rune` and check the result equals `bin/rune.rbc`, and again with `--target=stack` against `bin/rune.stack.rbc` |
| `make check` | all of the above: `make check-tools` builds what they need, and `bin/rune-test run --tier check` runs each of them as a test of the runner, at once where they share no files ([testing.md](testing.md), *Running the tests*) |
| `make doctor` | check that the tools of all targets are installed and work; print how to install missing ones |
| `make matrix-quick` | the Basis Library suite on Rune and on Rune's library compiled by each host (the `xc1` configurations); not part of `make check` |
| `make matrix` | `matrix-quick` and the suite on each host's own library |
| `make perf` | the wall-clock times of the programs of `tests/perf` in the configurations of the matrix (`PERF_CONFIGS` selects others), one at a time, in `tests/out/perf/wall.md`; not part of `make check` |
| `make install` | install `rune`, `runevm`, `runevm-stack`, `runedoc`, `runeopt`, `rune-repl` with `rune-dap` and `rune-kernel` where they are built, the basis library, the man pages and the shell completions under `PREFIX` |
| `make uninstall` | remove them again |
| `make clean` | remove `bin/`, `build/`, generated files and test output |

`bin/rune` runs on the VM and is about 35× slower than a host build, which
shows in the test targets (the suite takes about 15 s at `-j16` instead of
3 s). Every target that runs the compiler takes it from `$(RUNE)`, so
`make test RUNE=bin/rune-mlton` runs the same suite with the MLton build; that
is the loop to use while iterating. `RUNEVM=` selects the VM the same way.

Make runs recipes, and the test scripts run test programs, in parallel on
all available CPUs; `make JOBS=4 check` limits that to 4 (`bin/rune-test`,
`tests/run-tests.sh` and the oracle `cross` of `tests/runner/oracles.sml` take `-j N`).

The matrix targets are described in [basis-compat.md](basis-compat.md) and
`tests/basis/README.md`. `RUNE_HOSTS` (or `make HOSTS=...`) is where the hosts
are; `MLTON`, `MLBUILD`, `SMLNJ`, `MLBUILD32`, `SMLNJ32`, `MLBUILD_DEV`,
`SMLNJ_DEV`, `POLY` and `POLYC` name their commands one by one.

`CC=clang make vm` selects another C compiler. `BOOTHOST=smlnj-legacy make` picks the
host build that compiles stage 1 of the bootstrap.

## Windows

`make windows` builds the VMs for Windows with mingw-w64, for 64 bits,
`bin/runevm-stack.exe` and `bin/runevm.exe`, and for 32 bits,
`bin/runevm-stack32.exe` and `bin/runevm32.exe`. `make test-windows` runs the
language suite and `tests/runtime` on all four (`tests/run-windows.sh`, once with
the stack bytecode of `bin/rune-stack` and once with the register bytecode of
`bin/rune`), then the Basis Library suite on each.
Neither is part of any other target: `make check` never compiles
`runtime/sys/sys_win.c`, and nothing else in the tree depends on it. The toolchains
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
(`$RUNE_WINDOWS_DIR`, or one for each tree under `rune-test-windows` in the
`TEMP` directory of Windows, so that two worktrees can run the tests at
once; `tests/windows-dir.sh`), not in the tree, which WSL would hand them as
a network path, and passes `TZ` to them through `WSLENV`. It also runs a few programs with
`--count` on each VM and on `bin/runevm-stack`: the counts must agree.

`runtime/sys/sys_win.c` gives what Windows has -- the clock, the calendar, files,
directories, descriptors, the environment and running a command -- and
answers `ENOSYS` for what it does not do. A path of a drive comes back as
`/C:/Users/...`, because Rune's `OS.Path` is the one of POSIX, to which
that is absolute (no name of Windows has a colon in it), and a path that
goes in as `/C:/...` is given to Windows as `C:/...`; `/dev/null` is `NUL`
and `/dev/tty` the console. The standard streams are put in binary mode before
`main` runs, since a Rune string is bytes and a `\n` must stay one.

Windows has no `fork`. `Posix.Process.fork` starts a second VM instead and
hands it everything of this one: the heap, the stacks, the program, and the
descriptors, sockets and directory streams (`runtime/image.c`); the child carries
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
from a parent (`runtime/loader.c`, `validate_program`). That check costs about
3 µs for each KB of code: 14 µs for a program of the size of
`examples/hello.sml`, and 1.5 ms for `bin/rune.stack.rbc`, which at 479 KB of code
in 2,343 functions is the largest program in the tree. Against the 30 ms a
fork costs anyway that is under a tenth of a percent for an ordinary program
and about 5% for the largest, so there is no way to turn it off: an image that
is not checked is a way to run code that was never loaded.

Both VMs run every program of `tests/lang`; `tests/windows-skip.txt` names
those to leave out, with a reason for each, and is empty. The checks of the
Basis Library suite that do not pass are the `WINDOWS` lines of
`tests/basis/deviations.txt`, each saying what Windows does instead.

A healthy `make test-windows` takes about 11 minutes with 16 jobs
(2026-10-13). For each of the four VMs it reports all 281 programs of
`tests/lang` passing with none skipped, and `tests/runtime` 30 of 30; the
64-bit register VM runs both twice, at tier 1 and at tier 2. Of the
139,287 checks of the Basis Library suite, 194 fail on the stack bytecode
and 195 on the register bytecode, every one of them explained by a
`WINDOWS` line, and 6 are skipped as POSIX's alone. The tests of the
terminal, the debug adapter and the Jupyter kernel pass too.

What Windows does not get: `OS.Path` keeps the rules of POSIX rather than
the drive letters and backslashes of Windows, which is why a path of a drive
reaches a program as `/C:/...`; `bin/rune` itself is not run on the Windows
VMs, only the VM is built and tested there; and nothing of this runs in
continuous integration.

## MSYS2

The tree also builds on Windows itself, in a UCRT64 shell of
[MSYS2](https://www.msys2.org) (`MSYSTEM=UCRT64`; MINGW64 and CLANG64 work the
same way), with the packages

```
pacman -S --needed make git diffutils patch unzip \
  mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gmp mingw-w64-ucrt-x86_64-python
```

`make hosts` fetches MLton's release for the shell's environment, which is
the only host there: SML/NJ, Poly/ML and MLKit are not fetched under MSYS2.
Their links in the hosts directory are links of Windows, which need the
Developer Mode of Windows or an administrator. Then `make` builds
`bin/rune-mlton`, the VMs, the self-hosted compiler, `runedoc` and `runeopt`.
The runner does not run there (below), so the self-hosted compiler is held to
reproducing itself by hand, as the oracle `bootstrap` of
`tests/runner/oracles.sml` holds it:

```
make bin/rune.rbc bin/rune.stack.rbc
srcs="build/config.sml $(sh scripts/build-files.sh rune.build) src/main/rune-main.sml"
bin/rune-boot -o build/rune.stage2.rbc $srcs && cmp bin/rune.rbc build/rune.stage2.rbc
bin/rune-boot --target=stack -o build/rune.stage2.stack.rbc $srcs && cmp bin/rune.stack.rbc build/rune.stage2.stack.rbc
```

What is different there:

* The compiler of a MinGW environment makes programs of Windows, so the VMs
  are built with `SYS=win`, with mingw-w64's `printf` and the libraries of
  Windows that `runtime/sys/sys_win.c` calls, as `make windows` builds them; they
  are `bin/runevm.exe` and `bin/runevm-stack.exe`. `build/librune.a` goes
  without `runtime/native/native.c`, which is written for POSIX, so `runeopt`
  compiles but a program it makes does not link.
* Git for Windows sets `core.autocrlf`, which would check every file out with
  a CR before each LF; `.gitattributes` keeps them as they are stored. A file
  Git wrote before `.gitattributes` said so, in a checkout or a rebase from a
  commit without it, keeps its CRs: `git ls-files --eol` names it `w/crlf`,
  and `git checkout-index --force` of it writes it again.
* The runner, `bin/rune-test`, on which `make test`, `make quick`, `make
  bootstrap` and `make check` run their tests, starts each test with
  `/bin/sh`, and a test starts the wrappers of `bin/`, which are scripts of
  `sh`. A VM of Windows starts neither: `runtime/sys/sys_win.c` starts a
  program of Windows, or a batch file through `cmd`, and `/bin/sh` is a path
  of MSYS2 alone. Every test of the runner ends `not started`; what `make
  test` runs before it, `make test-steps` (`tests/runtime` and
  `build/heap_test`), passes.
* MLton's basis under MinGW opens a `TextIO` stream in text mode and gives
  every file of a drive the same `OS.FileSys.fileId`, so the compiler writes
  its bytecode, its manifests and its lists of units with `BinIO`, and trusts
  a file's id only where it tells the output from its directory.
* The MSYS2 runtime rewrites what a native program is given:
  `tests/run-tests.sh` passes 350 of the 352 programs of `tests/lang`, and
  the two others fail for that alone. `rt.args_name` passes the VM
  `--name /usr/local/bin/tool`, which arrives as
  `C:/msys64/usr/local/bin/tool`; and `basis.date_local_before_1970` runs in
  the zone `TZ` names, which MSYS2 drops for a native program when it has
  the rules of summer time after a comma, so the VM keeps the zone of Windows.

Nothing of this runs in continuous integration, and `make check` needs the
hosts that MSYS2 does not get.

## Another machine's VM

`make check` builds the VMs for this machine alone, so it says nothing about a
machine of another width or another order of bytes. `make portability` builds
them for two more, both Linux, so that only the VM differs:

| | |
|---|---|
| `bin/runevm-stack32`, `bin/runevm32` | a 32-bit x86, where a pointer is four bytes and the System V ABI aligns an `int64_t` to four |
| `bin/runevm-stack-ppc64`, `bin/runevm-ppc64` | a 64-bit PowerPC, big-endian; a wrapper that runs `bin/runevm-stack-ppc64.bin` (`bin/runevm-ppc64.bin`) under `qemu-ppc64`, as `bin/rune-mlton` wraps its payload |
| `bin/runevm-aarch64` | a 64-bit ARM, the register VM with its JIT (plans/jit.md M12, the second target of the code it makes); a wrapper that runs `bin/runevm-aarch64.bin` under `qemu-aarch64` |

The PowerPC and the ARM ones are built with clang, which cross-compiles
without a gcc for the target, using the linker and the headers of a sysroot
(`PPCROOT`, by default `/usr/powerpc64-linux-gnu`; `A64ROOT`,
`/usr/aarch64-linux-gnu`: the packages `libc6-dev-arm64-cross`,
`libgcc-13-dev-arm64-cross` and `binutils-aarch64-linux-gnu`). `make doctor
--scope portability` says what is missing and what to install.

`make test-portability` runs `tests/lang` and `tests/runtime` on each, once with
the stack bytecode on `bin/runevm-stack32` and `bin/runevm-stack-ppc64` and once with
the register bytecode on `bin/runevm32`, `bin/runevm-ppc64` and
`bin/runevm-aarch64`, and the Basis Library suite as the configurations
`rune:linux32`, `rune:ppc64`, `rune:linux32-new`, `rune:ppc64-new` and
`rune:aarch64-new`; and the JIT's oracle (the oracle `jit` of `tests/runner/oracles.sml`) on the
ARM VM, every mode of its JIT against its interpreter. Then two things no
single VM can show:

* the counts of `runevm-stack --count` must agree **to the byte** on every VM and on
  this one. They are the instructions executed and the bytes and objects
  allocated, and they depend on the program and its input alone, so a VM that
  lays out a value differently says so here.
* an image of `Runtime.save` must cross **in every direction**: each VM writes
  one and each of the others reads it. The program prints its answer before
  saving and again once restored, so the two are compared with each other.

The PowerPC and ARM VMs are linked with an rpath as well as `-L`, so that they load both
when the wrapper starts it and when the kernel does. That second way is what a
fork by a second VM needs: it starts the child by exec of the VM's own binary,
and qemu-user does not emulate a program it is handed by exec -- the kernel has
to know what a PowerPC or ARM binary is, which means qemu registered under
`/proc/sys/fs/binfmt_misc`. On WSL systemd will not do that for itself, since
it ships `ConditionVirtualization=!wsl` for `systemd-binfmt.service` to keep
its own `WSLInterop` registration, which `make test-windows` needs; register
qemu beside that one rather than by starting the service, which flushes every
registration first (`tests/portability-skip.txt` has the command). Without it
the runner's capability `qemu` is missing, and the tests under qemu are not
run (`bin/rune-test doctor --tier test-portability` names the command),
since the child would never start and the parent would wait for it for
ever; `make doctor` checks the registration too. It does not survive a restart of WSL
unless the boot command in `/etc/wsl.conf` redoes it.

It found two bugs when it was written. A `Value` was 12 bytes on a 32-bit
Linux, where the ABI aligns an `int64_t` to four and every other target
Rune builds for aligns it to eight -- so every object of the heap was a
different size there, the counts disagreed, and an image would not have
crossed; the padding was written out then, and a `Value` has since become
one 64-bit word on every target ([runtime.md](runtime.md)). And
`runtime/sys/sys_posix.c` asked for `_POSIX_C_SOURCE` alone, under which an older
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
$PREFIX/bin/rune-repl                wrapper: runevm --restore rune-repl.img; `rune -i` too
$PREFIX/bin/runevm                   the VM: the register bytecode, with its JIT
$PREFIX/bin/runevm-stack             the VM of the stack bytecode
$PREFIX/lib/rune/rune.rbc            the compiler
$PREFIX/lib/rune/runedoc.rbc         the documentation generator
$PREFIX/lib/rune/runeopt.rbc         the native code generator
$PREFIX/lib/rune/rune-repl.img        the REPL, saved once started (docs/repl.md)
$PREFIX/lib/rune/runtime/            librune.a and rune-offsets.s, what
                                     runeopt links a program with
$PREFIX/lib/rune/basis/              MANIFEST and the basis library sources,
                                     overview.doc for runedoc
$PREFIX/share/man/man1/              rune.1, runevm.1, runevm-stack.1, runedoc.1, runeopt.1
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
where it runs (`man runeopt`). So is the REPL, `rune-repl`, which `rune -i`
starts ([repl.md](repl.md)).

* As a normal user `make install` builds whatever is missing first.
* As root it builds **nothing** — it installs `bin/` as it stands and fails if
  it is empty. So the sequence is `make && sudo make install`, and a root
  install never leaves root-owned files in the checkout.
* `make install PREFIX=/opt/rune` installs elsewhere; `DESTDIR=/tmp/stage`
  stages the whole tree under another root for packaging.
* `make install HOST=mlton` installs the MLton host build instead of the
  bytecode compiler: `$PREFIX/bin/rune-mlton` with its payload in
  `$PREFIX/lib/rune`, and `rune` as a symlink to it. `HOST=polyml`,
  `HOST=mlkit`, `HOST=smlnj-legacy` and `HOST=smlnj-dev` work the same way (an SML/NJ host installs the heap image, which runs
  with the SML/NJ that `make hosts` installed). `runevm` is installed either way, since it runs
  what the compiler produces.
* `make uninstall` (with the same `PREFIX`, `DESTDIR` and `HOST`) removes it.

`scripts/install.sh` does the work and takes the same settings as
`--prefix`, `--destdir`, `--host` and `--uninstall`.

## How the build works

* `rune.build` is the compiler's build file ([build.md](build.md)): its
  `files ... end` block is the single ordered list of compiler source files,
  between `build/config.sml` and the self-hosted entry point, and `rune --build
  rune.build` compiles it. `scripts/gen-build-files.sh` generates
  `build/rune.mlb` (MLton), `build/rune.cm` (SML/NJ), `build/polyml-build.sml`
  (Poly/ML `use` script), `build/rune-mlkit.mlb` (MLKit: MLton's, without its
  annotations and with its own entry point) from the block, which
  `scripts/build-files.sh` reads, since the hosts build before there is a
  `rune` to read a build file with. **Add new source files to `rune.build`
  only.**
* `runedoc.build` is the same for `runedoc`: the compiler's utilities,
  frontend and elaborator in the order of `rune.build`, then `src/doc`. The
  script makes `build/runedoc.mlb`, `build/runedoc.cm`,
  `build/runedoc-polyml-build.sml` and `build/runedoc-mlkit.mlb` from it;
  the entry points are
  `src/main/runedoc-*-main.sml`. A file that both lists name is compiled into
  both programs, so the rules below hold for `src/doc` as well. The SML/NJ
  builds run one after another, because CM keeps its results for all of them
  in the same `.cm` directories, and so do the MLKit builds, for their `MLB`
  directories.
* `runeopt.build` is the same for `runeopt`, with `src/opt`; the entry
  points are `src/main/runeopt-*-main.sml`, and the rules below hold for
  `src/opt` too.
* The version is git's: the name of the tag that points at the commit
  checked out, or else the commit's abbreviated hash, with `-dirty` after
  it when a tracked file has changed. `scripts/gen-version.sh` writes it
  into `build/config.sml`, which every build of the four programs loads
  first, with the compiler's identity, the hash of its sources that the
  cache of compiled units keys its entries by ([units.md](units.md), *The
  cache*), and into `runtime/version.h` for the VMs (`Runtime.version`). make
  asks git on every run but writes the files only when they change, so
  a new commit, a checkout or the first edit of a clean tree rebuilds the
  programs and the VMs once. Without git or a repository the files keep the
  version they have, or say `unknown`. The manual pages are committed with
  none; `scripts/install.sh` gives each the version of what it installs.
* The instruction set and the primitives are described once, in Standard
  ML: `src/isa/stack.sml` and `src/isa/prims.sml`, in the language of
  `src/isa/isa.sml`. `runeisa` (`runeisa.build`, `src/isa`) writes from
  them `runtime/isa.h` (what the two instruction sets share: the `.rbc` version and
  each set's fingerprint), `runtime/stack/opcodes.h`, `runtime/prims_table.h`, `src/backend/opcodes.sml`,
  `src/backend/prims.sml`, and `runtime/stack/opcodes.def` and `runtime/prims.def`, which the
  scripts read. All of them are committed, so that the VM builds with a C
  compiler alone: `make isa` writes them again, and `make check-isa`, part of
  `make check`, fails when one is not what the descriptions give. The C
  dispatch table in `runtime/prims.c` is built from the generated
  `RUNE_PRIM_LIST` X-macro, so adding a primitive means: add it at the end of
  `src/isa/prims.sml`, run `make isa`, implement `p_<name>` in `runtime/prims.c`,
  document it in `docs/bytecode.md`.
* Entry points: `src/main/mlton-main.sml`, `src/main/polyml-main.sml`,
  `src/main/mlkit-main.sml` and `src/main/rune-main.sml` (the self-hosted
  build) call `Main.main`; SML/NJ's `ml-build` exports `Main.main` directly.
  MLKit's `OS.Process.failure` is `~1`, an exit status of 255, so its entry
  points end a failure with `Posix.Process.exit 0w1`, the status of the
  other builds. Each of the `bin/rune*` files is a generated shell wrapper
  that passes `--lib` and execs the payload next to it (`rune.rbc` on
  `runevm`, `rune-mlton.bin`, `rune-polyml.bin`, `rune-mlkit.bin`, or the
  heap image with the `sml` of `make hosts`).

## Bootstrapping

The compiler is written in the language it compiles, so it builds itself, and
the result is the compiler you get:

1. `make boot` compiles `build/config.sml`, the files of `rune.build` and
   `src/main/rune-main.sml` with `bin/rune-$(BOOTHOST)` into `bin/rune.rbc`
   (stage 1), writes `bin/rune-boot`, a wrapper that runs
   `runevm --heap-size $(RUNE_HEAP) bin/rune.rbc`, and points `bin/rune` at
   it. `make` does this too. `BOOTHOST` is `mlton`, `smlnj-legacy`, `smlnj32`,
   `smlnj-dev`, `polyml` or `mlkit`; they all emit the same bytecode, so it only decides which host
   build compiles stage 1.
2. `bin/rune` takes the same options as the host builds, so `make test` runs
   the whole suite with it and `make check-cross` compares its bytecode with
   the six host builds on every test program, the examples, and the
   compiler sources themselves. `check-cross` knows it as the build `boot`,
   hence the name `bin/rune-boot`.
3. `make bootstrap` compiles the compiler with `bin/rune` into
   `bin/rune.stage2.rbc` and checks with `cmp` that it is identical to
   `bin/rune.rbc`: the compiler reproduces itself byte for byte. It does the
   same with `--target=stack` against `bin/rune.stack.rbc`.

`RUNE_HEAP` (64 MiB) is only the semispace mapped up front; the heap grows on
demand. Between 32 MiB and 256 MiB the bootstrap varies by under 3%, so the
default is chosen to keep the resident set down when `-j16` compilers run at
once.

All of this relies on the compiler being deterministic (ordered maps and
counter-generated stamps, rule 5 below) and on its sources staying inside the
language Rune accepts (rule 6). If stage 2 ever differs from stage 1, diff the
`runevm-stack --disasm` output of the two files, then the `--dump-lambda` /
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
3. Never depend on the width of `Int`: it is 31-bit on the 32-bit SML/NJ,
   63-bit on the 64-bit one and on MLKit, 32-bit on MLton and arbitrary on
   Poly/ML. Source literals are kept as
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
bin/rune [options] file.sml ...      # produces first-file.rbc (or -o FILE): register bytecode
bin/runevm [options] file.rbc [args] # runs it, compiling the code that gets hot (--jit=MODE: off, baseline, opt (the default), all)
bin/rune --target=stack file.sml -o file.rbc  # stack bytecode instead
bin/runevm-stack [options] file.rbc [args] # runs that
bin/rune-mlton [options] file.sml ... # the same compiler, built by MLton
bin/runeopt file.rbc -o prog          # an executable of a stack .rbc (Linux, x86-64)
RUNEVM_OPTIONS=--count ./prog [args]  # runs it, with the options of runevm-stack
```

The two targets make files of different instruction sets, which only their own VM
loads. What a program is given is the same on both: the words after the `.rbc`
file are `CommandLine.arguments ()`, and `TextIO.stdIn`, `stdOut` and `stdErr`
are the VM's standard streams.

A library other than the basis library is compiled with `--library NAME`:
the directory `NAME` of the `--lib` directory (`lib/test/property`, say),
or a path when `NAME` begins with `/` or `.`. It has a `library.build` in
the basis library's form, whose `libraries NAME ... end` names the
libraries it is written on, and the `MANIFEST` that `make manifests` makes
of it (`rune --basis-index DIR`); those are compiled first, and the files of all of them are
chosen as the basis library's are, by what the program names
(`lib/*` of `tests/runner/tools.sml`, `make test-lib`). A library other than the
basis library may not use `_prim`.

```
bin/rune --library test/property prog.sml   # prog.sml with the property-testing library
```

Run `bin/rune --help` and `bin/runevm --help` for the option lists, or
`man rune` and `man runevm` after `make install`. Exit
status of `rune`: 0 success, 1 compile error or usage error. Exit status of
`runevm` and `runevm-stack`: the program's `OS.Process.exit` status, 1 for an uncaught exception,
2 for VM errors (bad bytecode file, out of memory).
