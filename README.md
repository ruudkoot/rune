# Rune

Rune is a Standard ML '97 compiler that targets a compact stack bytecode, plus
`runevm`, a portable C99 interpreter with a copying garbage collector. The
compiler is written in portable Standard ML and builds unchanged with
**MLton**, **SML/NJ** and **Poly/ML** — all three produce byte-identical
bytecode.

```
$ make                                   # bin/rune (MLton) + bin/runevm
$ bin/rune examples/hello.sml -o hello.rbc
$ bin/runevm hello.rbc
Hello, world!
```

## What it supports

The full Core language of SML '97 (datatypes, pattern matching, exceptions,
records, let-polymorphism, refs, proper tail calls), namespace-only structures
(`structure S = struct ... end`, `open`, `S.x`) and a substantial subset of
the Basis Library (`Int`, `IntInf`, `Word`, `Real`, `Math`, `Char`, `String`, `List`,
`ListPair`, `Option`, `Array`, `Vector`, `TextIO` and `BinIO` on standard streams and files,
`CommandLine`, `OS.Process`). Signatures and functors are not implemented yet.

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
| `tests/` | `run-tests.sh`, `lang/` (run tests), `errors/` (compile-error tests) |
| `docs/` | [language.md](docs/language.md), [bytecode.md](docs/bytecode.md), [building.md](docs/building.md), [architecture.md](docs/architecture.md) |
| `examples/` | small programs |
| `scripts/` | build-file and table generators, consistency checks |

## Building and testing

See [docs/building.md](docs/building.md). In short:

```
make all3          # bin/rune-mlton, bin/rune-smlnj, bin/rune-polyml
make test          # run the suite with bin/rune
make test-all      # ... with each compiler build
make check-cross   # identical bytecode from all three builds
make check-docs    # docs <-> tests <-> .def files in sync
make check         # everything
```

## Using it

```
rune [options] file.sml ...     -o FILE, --typecheck-only, --dump-ast, --dump-lambda, --dump-code, --help
runevm [options] file.rbc [args ...]   --disasm, --trace, --stats, --heap-size N, --help
```

Programs read `CommandLine.arguments ()` (the words after the `.rbc` file),
use `TextIO.stdIn`/`stdOut`/`stdErr`, and exit with `OS.Process.exit`. An
uncaught exception is reported on stderr and exits with status 1.

## Status

Version 0.1.0: first working release. The compiler is not self-hosting yet
(it uses `IntInf`, `BinIO`, `TextIO.openIn` and functors, which Rune does not
provide). See the *Planned* rows in [docs/language.md](docs/language.md) for
the roadmap: signatures and functors, equality types, exhaustiveness warnings,
file I/O, `IntInf`.
