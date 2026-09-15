# Rune

Rune is a Standard ML ’97 subset compiler, written in portable Standard ML,
that emits bytecode for a portable C virtual machine.

## Status

Rune compiles typed expressions, `val`/`let` bindings, user functions, lexical
closures, recursion, and tuples to bytecode v2. It includes polymorphic type
inference with the SML value restriction and a garbage-collected VM heap. M0–M3
pass their acceptance gates under SML/NJ, Poly/ML, and MLton, including allocation
stress with a 16 KiB heap. The next milestone is the v0.1 release checks (M4).

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

build/mlton/rune -o build/closures.rbc examples/closures.sml
build/vm/rune-vm build/closures.rbc
# 42

build/mlton/rune -o build/collection.rbc examples/collection.sml
build/vm/rune-vm --heap-limit 16384 build/collection.rbc
# 1
```

`make` defaults to MLton. Each host produces a `build/<host>/rune` launcher.
The VM uses only standard C; running `.rbc` files does not require an SML compiler.
Poly/ML uses saved states, so its native development linker library is optional.
Bytecode v1 files must be recompiled for the v2 VM.

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
make check-docs
```

Ordinary builds require Make, a POSIX shell, standard shell utilities, a host SML
compiler, and a C11 compiler. Tests and documentation generation also use Python 3
with its standard library. No package downloads occur during builds.
