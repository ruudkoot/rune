# Rune

Rune is a Standard ML ’97 subset compiler, written in portable Standard ML,
that emits bytecode for a portable C virtual machine.

## Status

Rune 0.2.0 adds user datatypes, constructor patterns, `case`, and uncaught
`Match`/`Bind` failures to the functional subset: typed expressions, `val`/`let`,
functions, closures, recursion, tuples, and polymorphic type inference. The C VM
uses bytecode v3 and collects unused heap objects. M5a passes the three-host
compiler, native/emulated VM, and sanitizer gates; [the checkpoint](docs/PLAN.md)
records verification. Lists, multi-clause functions, exception handlers, and
the other M5 features remain deferred.

- [Implementation plan](docs/PLAN.md): milestones, architecture, builds with
  SML/NJ, Poly/ML, and MLton, and acceptance checks.
- [Language support](docs/LANGUAGE.md): current status, proposed subsets,
  semantics, and exclusions.
- [Builds and testing](docs/BUILD.md): prerequisites, host adapters, and checks.
- [Bytecode specification](docs/BYTECODE.md): format, instructions, and VM limits.
- [Release notes](docs/RELEASES.md): v0.2.0 scope, validation, compatibility,
  and earlier history.
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

build/mlton/rune -o build/closures.rbc examples/closures.sml
build/vm/rune-vm build/closures.rbc
# 42

build/mlton/rune -o build/datatypes.rbc examples/datatypes.sml
build/vm/rune-vm build/datatypes.rbc
# 42

build/mlton/rune -o build/collection.rbc examples/collection.sml
build/vm/rune-vm --heap-limit 16384 build/collection.rbc
# 1
```

`make` defaults to MLton. Each host produces a `build/<host>/rune` launcher.
The VM uses only standard C; running `.rbc` files does not require an SML compiler.
Poly/ML uses saved states, so its native development linker library is optional.
Bytecode v1/v2 files must be recompiled for the v3 VM.

## Editor setup

Open the repository root in your editor. Millet discovers the checked-in
`rune.mlb` there and analyzes the compiler sources in `src/`. The project works
before the first build and after `make clean`.

After changing `sources.list`, run `make generate` to update the editor project;
`make check-docs` checks that it stays in sync. See the
[editor setup guide](docs/BUILD.md#editor-setup) for details.

## Check changes

```sh
make test-all       # Three-host semantics, bytecode equality, reference SML, docs
make test-builds    # Checkout paths with spaces, rebuilds, failed compilations
make test-sanitize # GCC/Clang address and undefined-behavior sanitizers
make test-gc        # Collector roots, cycles, deep graphs, and heap accounting
make test-portability # Native, 32-bit i386, and big-endian PowerPC64 VMs
make check-docs
```

Ordinary builds require Make, a POSIX shell, standard shell utilities, a host SML
compiler, and a C11 compiler. Tests and documentation generation also use Python 3
with its standard library. No package downloads occur during builds.

`test-portability` uses additional development tools on x86-64 Linux: GCC
multilib, Clang, QEMU user emulation, and PowerPC64 binutils/libraries. See the
[portability setup and target matrix](docs/BUILD.md#portability-checks). Ordinary
compiler and VM builds do not require these tools.
