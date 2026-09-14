# rune
Rune
=======
# Rune

Rune is a programming-language project. Its first milestone is an
implementation of Standard ML written in Standard ML, compiling to a portable
Rune bytecode format executed by a small C interpreter.

The repository is intentionally organized for long-term growth:

- `src/sml/` contains production compiler and language implementation code.
- `src/runtime/` contains the portable C bytecode interpreter.
- `benchmarks/` contains stable compiler and runtime workloads.
- `reference/` contains executable implementations used as behavioral oracles.
- `prototypes/` contains disposable design experiments.
- `tests/` contains layered language, bytecode, runtime, regression, and
  performance tests.
- `docs/` describes architecture, language semantics, interfaces, invariants,
  and workflows.

## Development status

The repository currently contains the scaffold and the first executable
boundaries. Language features and the bytecode instruction set will be added
behind documented tests; placeholder behavior is not presented as a complete
implementation.

## Toolchains

SML/NJ is the primary Standard ML toolchain. Poly/ML and MLton are additional
compatibility checkers. A C11 compiler is required for the portable runtime.

Run the complete local check with:

```sh
make check
```

Individual checks are available as `make check-sml`, `make check-polyml`,
`make check-mlton`, `make check-runtime`, and `make test`.
Unavailable optional toolchains are reported as skipped; CI environments should
install all supported toolchains.

On Debian or Ubuntu, `make setup` installs any missing build prerequisites:
`make`, a C compiler (`cc`), SML/NJ (`sml`), Poly/ML (`poly`), and MLton
(`mlton`). The setup is idempotent, uses `sudo` when needed, and fails
explicitly if package installation or post-installation verification fails.
Regular check targets never install packages automatically.

Read [the architecture](docs/architecture.md), [the testing policy](docs/testing.md),
and [the contribution guide](CONTRIBUTING.md) before changing implementation
behavior.
