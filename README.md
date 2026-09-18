# Rune

Rune is a Standard ML '97 compiler that targets a compact stack bytecode, plus
`runevm`, a portable C99 interpreter with a copying garbage collector. The
compiler is written in portable Standard ML and builds unchanged with
**MLton**, **SML/NJ** and **Poly/ML** — all three produce byte-identical
bytecode. It also compiles itself, and that is the compiler Rune ships:
`bin/rune` is `bin/rune.rbc`, the compiler as bytecode, running on `runevm`.
The host builds bootstrap it and keep it honest; `make bootstrap` checks that
it reproduces itself byte for byte.

```
$ make                                   # bin/rune (self-hosted) + bin/runevm
$ bin/rune examples/hello.sml -o hello.rbc
$ bin/runevm hello.rbc
Hello, world!
```

## What it supports

The full Core language of SML '97 (datatypes, pattern matching, exceptions,
records, let-polymorphism, refs, proper tail calls), the Modules language
(structures, signatures, transparent and opaque ascription, `where type`,
`sharing`, functors) and a substantial subset of the Basis Library (`Int`,
`IntInf`, `Word`, `Real`, `Math`, `Char`, `String`, `List`, `ListPair`,
`Option`, `Array`, `Vector`, `TextIO` and `BinIO` on standard streams and
files, `CommandLine`, `OS.Process`).

**[docs/language.md](docs/language.md)** is the authoritative, test-backed
description of the supported language. Every feature row there has an id
(`exp.case`, `basis.list`, ...) that names a test in `tests/lang/`, and
`make check-docs` fails when the two drift apart.

## Layout

| Path | Contents |
|---|---|
| `src/` | the compiler (frontend, elaboration, core translation, backend, driver) |
| `vm/` | the virtual machine; `opcodes.def` and `prims.def` define the instruction set |
| `lib/basis/` | the basis library, compiled before every program |
| `tests/` | `run-tests.sh`, `lang/` (run tests), `errors/` (compile-error tests), `basis/` (the Basis Library suite, also run against MLton, SML/NJ and Poly/ML) |
| `docs/` | [language.md](docs/language.md), [bytecode.md](docs/bytecode.md), [building.md](docs/building.md), [architecture.md](docs/architecture.md), [basis-compat.md](docs/basis-compat.md) |
| `examples/` | small programs |
| `scripts/` | build-file and table generators, consistency checks, `doctor.sh`, `install.sh` |
| `man/`, `completions/` | man pages and shell completions, installed by `make install` |

## Building and testing

See [docs/building.md](docs/building.md). In short:

```
make doctor        # check the environment: compilers, tools, how to install what is missing
make               # bin/rune (the self-hosted compiler) + bin/runevm
make all3          # bin/rune-mlton, bin/rune-smlnj, bin/rune-polyml
make test          # run the suite with bin/rune
make test-all      # ... with each of the three host builds
make check-cross   # identical bytecode from all four builds, the self-hosted one included
make check-docs    # docs <-> tests <-> .def files in sync
make test-basis    # the Basis Library suite (tests/basis) with bin/rune
make perf-check    # instruction and allocation budgets (tests/perf); same numbers on every machine
make bootstrap     # the self-hosted compiler reproduces bin/rune.rbc
make check         # everything
make install       # install under PREFIX; sudo make install goes to /usr/local
```

`bin/rune` runs on the VM, so it is about 35× slower than a host build.
`make test RUNE=bin/rune-mlton` runs the same suite with the MLton build and
is the faster loop while iterating; every target that runs the compiler takes
the same `RUNE=` override.

`make install` copies `rune`, `runevm`, the basis library, the man pages and
the shell completions to `~/.local` (or `/usr/local` when run as root, which
installs what is in `bin/` and never builds). `make install HOST=mlton`
installs a host build instead of the bytecode compiler. Each `rune` is a
wrapper that passes `--lib`, so no path is baked into the compiler.

## Using it

```
rune [options] file.sml ...     -o FILE, --lib DIR, --typecheck-only, --no-warnings, --dump-ast, --dump-lambda, --dump-code, --help
runevm [options] file.rbc [args ...]   --disasm, --trace, --stats, --count, --gc-stress N, --heap-size N, --help
```

Programs read `CommandLine.arguments ()` (the words after the `.rbc` file),
use `TextIO.stdIn`/`stdOut`/`stdErr`, and exit with `OS.Process.exit`. An
uncaught exception is reported on stderr and exits with status 1.

## Status

Version 0.3.0: the compiler implements the full language of *The Definition
of Standard ML (Revised)*, Core and Modules, including equality types, the
exhaustiveness and redundancy reports of Section 4.11, `abstype`, and the
static restrictions on explicit type variables and top-level declarations,
and it is self-hosting: `bin/rune.rbc` (the compiler compiled by the MLton
build) runs on `runevm`, passes the test suite, emits the same bytecode as the
three host builds, and reproduces itself byte for byte. Running the compiler
on the interpreter is about 30× slower than the MLton build (about three
seconds for the compiler itself). The remaining differences from the
Definition are the implementation-defined choices listed in
[docs/language.md](docs/language.md); the Basis Library is still a subset.
[docs/plans/sml97.md](docs/plans/sml97.md) records how the language was
completed and what is left; [docs/plans/basis.md](docs/plans/basis.md) is the
plan for the full Basis Library.
