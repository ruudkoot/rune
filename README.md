# Rune

Rune is a Standard ML ’97 subset compiler, written in portable Standard ML,
that emits bytecode for a portable C virtual machine.

## Status

The first working milestone compiles typed expressions and `val`/`let` bindings
to bytecode. It supports integers, booleans, strings, conditions, sequencing, and
basic output. User-defined functions, datatypes, and modules are later milestones.

- [Implementation plan](docs/PLAN.md): milestones, architecture, builds with
  SML/NJ, Poly/ML, and MLton, and acceptance checks.
- [Language support](docs/LANGUAGE.md): current status, proposed subsets,
  semantics, and exclusions.
- [Builds and testing](docs/BUILD.md): prerequisites, host adapters, and checks.
- [Bytecode specification](docs/BYTECODE.md): format, instructions, and VM limits.
- [Contributor instructions](AGENTS.md): requirements for keeping implementation,
  language documentation, and tests in sync.

## Build and run

```sh
make HOST=smlnj build
make HOST=polyml build
make HOST=mlton build
make all-hosts

build/mlton/rune -o build/hello.rbc examples/hello.sml
build/vm/rune-vm build/hello.rbc
# 42
```

`make` defaults to MLton. Each host produces a `build/<host>/rune` launcher.
The VM uses only standard C; running `.rbc` files does not require an SML compiler.
Poly/ML uses saved states, so its native development linker library is optional.

## Check changes

```sh
make test-all       # Three-host semantics, bytecode equality, reference SML, docs
make test-builds    # Checkout paths with spaces, rebuilds, failed compilations
make test-sanitize # GCC/Clang address and undefined-behavior sanitizers
make check-docs
```

Ordinary builds require Make, a POSIX shell, standard shell utilities, a host SML
compiler, and a C11 compiler. Tests and documentation generation also use Python 3
with its standard library. No package downloads occur during builds.
