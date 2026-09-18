# Building Rune

Rune consists of the compiler `rune` (written in portable Standard ML) and the
virtual machine `runevm` (C99). The compiler builds unchanged with **MLton**,
**SML/NJ** and **Poly/ML**; all three builds produce byte-identical bytecode
(`make check-cross` verifies this).

## Prerequisites

* A C99 compiler (`cc`; gcc 13 and clang 18 are tested), GNU make 4.3 or later, POSIX `sh`, `awk`.
* At least one of: MLton (tested: 20210117), SML/NJ (tested: 110.79, 32-bit
  build), Poly/ML (tested: 5.7.1). On Debian/Ubuntu:
  `apt install mlton smlnj polyml build-essential`.

## Targets

| Command | Result |
|---|---|
| `make` | `bin/rune` (MLton build, symlink to `bin/rune-mlton`) and `bin/runevm` |
| `make mlton` / `make smlnj` / `make polyml` | `bin/rune-mlton`, `bin/rune-smlnj`, `bin/rune-polyml` |
| `make all3` | all three compiler builds |
| `make vm` | `bin/runevm` |
| `make vm-asan` | `bin/runevm-asan` with AddressSanitizer/UBSan |
| `make test` | run `tests/run-tests.sh` with `bin/rune` |
| `make test-all` | run the suite with each of the three compiler builds |
| `make check-cross` | compile every test with all three builds and compare the bytecode |
| `make check-docs` | verify docs, tests and `.def` files are in sync |
| `make boot` | `bin/rune.rbc` (the compiler compiled by `bin/rune-mlton`) and the `bin/rune-boot` wrapper that runs it on `runevm` |
| `make test-boot` | run `tests/run-tests.sh` with `bin/rune-boot` |
| `make bootstrap` | compile the compiler with `bin/rune-boot` and check the result equals `bin/rune.rbc` |
| `make check` | all of the above (about 3 minutes on 16 CPUs, most of it spent running the compiler on the interpreter) |
| `make clean` | remove `bin/`, `build/`, generated files and test output |

Make runs recipes, and the test scripts run test programs, in parallel on
all available CPUs; `make JOBS=4 check` limits that to 4 (`tests/run-tests.sh`
and `scripts/check-cross.sh` take `-j N`).

`CC=clang make vm` selects another C compiler. `RUNE_LIB=/path make` bakes a
different default basis-library location into the compiler (default:
`<repo>/lib`); `rune --lib DIR` overrides it at run time.

## How the build works

* `sources.txt` is the single ordered list of compiler source files.
  `scripts/gen-build-files.sh` generates `build/rune.mlb` (MLton),
  `build/rune.cm` (SML/NJ), `build/polyml-build.sml` (Poly/ML `use` script)
  and `build/config.sml` (version and default library path) from it.
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
  `ml-build` exports `Main.main` directly and `bin/rune-smlnj` is a shell
  wrapper around `sml @SMLload`.

## Bootstrapping

The compiler is written in the language it compiles, so it can build itself:

1. `make boot` compiles `build/config.sml`, the files of `sources.txt` and
   `src/main/rune-main.sml` with `bin/rune-mlton` into `bin/rune.rbc`
   (stage 1) and writes `bin/rune-boot`, a wrapper that runs
   `runevm --heap-size $(BOOT_HEAP) bin/rune.rbc` (the large initial semispace,
   256 MiB by default, keeps the bootstrap nearly collection-free).
2. `bin/rune-boot` accepts the same options as `bin/rune`, so
   `make test-boot` runs the whole test suite with it and `make check-cross`
   compares its bytecode with the three host builds on every test program,
   the examples, and the compiler sources themselves.
3. `make bootstrap` compiles the compiler with `bin/rune-boot` into
   `bin/rune.stage2.rbc` and checks with `cmp` that it is identical to
   `bin/rune.rbc`: the compiler reproduces itself byte for byte.

All of this relies on the compiler being deterministic (ordered maps and
counter-generated stamps, rule 5 below) and on its sources staying inside the
language Rune accepts (rule 6). If stage 2 ever differs from stage 1, diff the
`runevm --disasm` output of the two files, then the `--dump-lambda` /
`--dump-code` output of `bin/rune` and `bin/rune-boot` on the first
differing input.

## Portability rules for compiler sources

The three SML systems differ in ways that matter; the code base follows these
rules so that one source tree builds everywhere and emits identical output:

1. Only the part of the SML Basis Library (2004 revision) that Rune's own
   basis provides is used—no SML/NJ library, no compiler-specific structures
   outside `src/main/`.
2. Every file contains only `structure` declarations (required by SML/NJ's
   CM). Signatures and functors are not used: Rune cannot compile them yet
   (see rule 6).
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
   the language described in `docs/language.md`: no signatures, ascription or
   functors, and no literal or operator overloading at `IntInf.int` (write
   `IntInf.fromInt n` and `IntInf.+ (a, b)`).

## Using the compiler

```
bin/rune [options] file.sml ...      # produces first-file.rbc (or -o FILE)
bin/runevm [options] file.rbc [args] # runs it
bin/rune-boot [options] file.sml ... # the same compiler, running on runevm
```

Run `bin/rune --help` and `bin/runevm --help` for the option lists. Exit
status of `rune`: 0 success, 1 compile error or usage error. Exit status of
`runevm`: the program's `OS.Process.exit` status, 1 for an uncaught exception,
2 for VM errors (bad bytecode file, out of memory).
