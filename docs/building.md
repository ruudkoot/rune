# Building Rune

Rune consists of the compiler `rune` (written in portable Standard ML) and the
virtual machine `runevm` (C99). The compiler builds unchanged with **MLton**,
**SML/NJ** and **Poly/ML**; all three builds produce byte-identical bytecode
(`make check-cross` verifies this).

The compiler Rune ships is the one it compiled itself: **`bin/rune`** is
`bin/rune.rbc` running on `runevm`. The host builds `bin/rune-mlton`,
`bin/rune-smlnj` and `bin/rune-polyml` have two jobs — to bootstrap that one,
and to check it (`make check-cross`, `make test-all`). Everything that runs,
tests or measures the compiler goes through `bin/rune`.

The compiler knows no library location of its own: it takes the basis library
from `--lib DIR` (which it reads from `DIR/basis`) and refuses to compile
without it. Each of the four `bin/rune*` is therefore a small wrapper script
that passes `--lib` for the tree it sits in, and the payload of a host build
lives next to it as `bin/rune-mlton.bin`, `bin/rune-polyml.bin` or
`bin/rune-smlnj.heap.<arch>`. Because the wrapper puts `--lib` first, a
`--lib` of yours comes later on the command line and wins. Nothing absolute is
baked into `bin/rune.rbc`, so it does not depend on where the checkout is.

## Prerequisites

* A C99 compiler (`cc`; gcc 13 and clang 18 are tested), GNU make 4.3 or later, POSIX `sh`, `awk`.
* At least one of: MLton (tested: 20210117), SML/NJ (tested: 110.79, 32-bit
  build), Poly/ML (tested: 5.7.1). On Debian/Ubuntu:
  `apt install mlton smlnj polyml libpolyml-dev libgmp-dev build-essential`.
  One is enough for `make` and `make test`; `BOOTHOST` says which one
  bootstraps `bin/rune` (default `mlton`, so with only Poly/ML installed use
  `make BOOTHOST=polyml`). `make test-all`, `make check-cross`, the matrix
  targets and `make check` need all three.

`make doctor` checks all of this (and the tools of the test, sanitizer, host
matrix and profiling targets), by running the tools rather than just looking
for them: it compiles a C99 program, and a program with MLton and with
`polyc`. For everything that is missing it prints the install command of the
system's package manager (`apt`, `dnf`, `pacman` or `brew`) and exits with
status 1; optional tools only produce warnings.

The build and test targets run the same check for the tools they need, once,
before they first run (`scripts/doctor.sh --quiet --scope <scope>`; a stamp
`build/.doctor-<scope>` records success, so the check is repeated after
`make clean` or when the script changes). `make DOCTOR=no ...` skips it, and
`CC`, `MLTON`, `SMLNJ`, `POLY` and `POLYC` name the tools to check.

## Targets

| Command | Result |
|---|---|
| `make` | `bin/rune` (the self-hosted compiler) and `bin/runevm` |
| `make mlton` / `make smlnj` / `make polyml` | `bin/rune-mlton`, `bin/rune-smlnj`, `bin/rune-polyml`; none of them is `bin/rune` |
| `make all3` | all three host builds |
| `make vm` | `bin/runevm` |
| `make vm-asan` | `bin/runevm-asan` with AddressSanitizer/UBSan |
| `make boot` | `bin/rune.rbc` (the compiler compiled by `bin/rune-$(BOOTHOST)`), the `bin/rune-boot` wrapper that runs it on `runevm`, and `bin/rune` → `rune-boot` |
| `make test` | run `tests/run-tests.sh` with `bin/rune` |
| `make test-all` | run the suite with each of the three host builds |
| `make check-cross` | compile every test, example and Basis Library suite program with all four builds and compare the bytecode |
| `make check-docs` | verify docs, tests and `.def` files are in sync, and that the Basis Library suite has a check for every specified member |
| `make test-basis` | run the Basis Library suite (`tests/basis`) with `bin/rune` |
| `make bootstrap` | compile the compiler with `bin/rune` and check the result equals `bin/rune.rbc` |
| `make check` | all of the above (about 3 minutes on 16 CPUs, most of it spent running the compiler on the interpreter) |
| `make doctor` | check that the tools of all targets are installed and work; print how to install missing ones |
| `make matrix-quick` | the Basis Library suite on Rune, on the libraries of the installed MLton, SML/NJ and Poly/ML, and on Rune's library compiled by them; not part of `make check` |
| `make hosts` | install the current releases of the three (MLton 20241230, SML/NJ 110.99.9, Poly/ML 5.9.2) under `${RUNE_HOSTS:-~/.local/rune-hosts}`; no root access needed, about 200 MB and a few minutes |
| `make matrix` | `matrix-quick` and the same with those releases |
| `make install` | install `rune`, `runevm`, the basis library, the man pages and the shell completions under `PREFIX` |
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
`tests/basis/README.md`; `MLTON`, `SMLNJ` and `POLY` select the installed
hosts they use and `RUNE_HOSTS` the prefix of the current ones.

`CC=clang make vm` selects another C compiler. `BOOTHOST=smlnj make` picks the
host build that compiles stage 1 of the bootstrap.

## Installing

`make install` copies a built tree into `PREFIX`, which defaults to
`/usr/local` when the effective user is root and to `~/.local` otherwise:

```
$PREFIX/bin/rune                     wrapper: runevm + rune.rbc + --lib
$PREFIX/bin/runevm                   the VM
$PREFIX/lib/rune/rune.rbc            the compiler
$PREFIX/lib/rune/basis/              MANIFEST and the basis library sources
$PREFIX/share/man/man1/              rune.1, runevm.1
$PREFIX/share/bash-completion/completions/rune
$PREFIX/share/zsh/site-functions/    _rune, _runevm
```

The installed `rune` derives the library path from its own location
(`$(dirname $0)/../lib/rune`), so the tree can be moved or staged.

* As a normal user `make install` builds whatever is missing first.
* As root it builds **nothing** — it installs `bin/` as it stands and fails if
  it is empty. So the sequence is `make && sudo make install`, and a root
  install never leaves root-owned files in the checkout.
* `make install PREFIX=/opt/rune` installs elsewhere; `DESTDIR=/tmp/stage`
  stages the whole tree under another root for packaging.
* `make install HOST=mlton` installs the MLton host build instead of the
  bytecode compiler: `$PREFIX/bin/rune-mlton` with its payload in
  `$PREFIX/lib/rune`, and `rune` as a symlink to it. `HOST=polyml` and
  `HOST=smlnj` work the same way (`smlnj` installs the heap image and still
  needs `sml` on the `PATH`). `runevm` is installed either way, since it runs
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
* `vm/opcodes.def` and `vm/prims.def` are the single source of truth for the
  instruction set and primitive table. `scripts/gen-opcodes.sh` generates
  `vm/opcodes.h`, `vm/prims_table.h`, `src/backend/opcodes.sml` and
  `src/backend/prims.sml`. The C dispatch table in `vm/prims.c` is built from
  the generated `RUNE_PRIM_LIST` X-macro, so adding a primitive means: add a
  line to `prims.def`, implement `p_<name>` in `vm/prims.c`, document it in
  `docs/bytecode.md`.
* Entry points: `src/main/mlton-main.sml`, `src/main/polyml-main.sml` and
  `src/main/rune-main.sml` (the self-hosted build) call `Main.main`; SML/NJ's
  `ml-build` exports `Main.main` directly. Each of the four `bin/rune*` files
  is a generated shell wrapper that passes `--lib` and execs the payload next
  to it (`rune.rbc` on `runevm`, `rune-mlton.bin`, `rune-polyml.bin`, or
  `sml @SMLload`).

## Bootstrapping

The compiler is written in the language it compiles, so it builds itself, and
the result is the compiler you get:

1. `make boot` compiles `build/config.sml`, the files of `sources.txt` and
   `src/main/rune-main.sml` with `bin/rune-$(BOOTHOST)` into `bin/rune.rbc`
   (stage 1), writes `bin/rune-boot`, a wrapper that runs
   `runevm --heap-size $(RUNE_HEAP) bin/rune.rbc`, and points `bin/rune` at
   it. `make` does this too. `BOOTHOST` is `mlton`, `smlnj` or `polyml`; all
   three emit the same bytecode, so it only decides which host has to be
   installed.
2. `bin/rune` takes the same options as the host builds, so `make test` runs
   the whole suite with it and `make check-cross` compares its bytecode with
   the three host builds on every test program, the examples, and the
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

The three SML systems differ in ways that matter; the code base follows these
rules so that one source tree builds everywhere and emits identical output:

1. Only the part of the SML Basis Library (2004 revision) that Rune's own
   basis provides is used—no SML/NJ library, no compiler-specific structures
   outside `src/main/`.
2. Every file contains only top-level `structure`, `signature` and `functor`
   declarations (required by SML/NJ's CM).
3. Never depend on the width of `Int`: SML/NJ's `Int` here is 31-bit, MLton's
   32-bit, Poly/ML's arbitrary precision. Source literals are kept as
   `IntInf.int`; bytecode immediates are limited to ±2^30; 64-bit values are
   serialized from `IntInf` with `quot`/`rem` (with explicit `IntInf`
   operations, see rule 6).
4. Reals are never converted to binary by the compiler; they travel to the VM
   as their literal text.
5. All iteration over maps uses the ordered `StringMap`/`IntMap` from
   `src/util/ordmap.sml`, and every generated name/stamp comes from a counter,
   so output is deterministic across hosts.
6. The compiler must be compilable by Rune itself, so its sources stay inside
   the language described in `docs/language.md`: in particular no literal or
   operator overloading at `IntInf.int` (write `IntInf.fromInt n` and
   `IntInf.+ (a, b)`), and only the Basis subset Rune provides.

## Using the compiler

```
bin/rune [options] file.sml ...      # produces first-file.rbc (or -o FILE)
bin/runevm [options] file.rbc [args] # runs it
bin/rune-mlton [options] file.sml ... # the same compiler, built by MLton
```

Run `bin/rune --help` and `bin/runevm --help` for the option lists, or
`man rune` and `man runevm` after `make install`. Exit
status of `rune`: 0 success, 1 compile error or usage error. Exit status of
`runevm`: the program's `OS.Process.exit` status, 1 for an uncaught exception,
2 for VM errors (bad bytecode file, out of memory).
