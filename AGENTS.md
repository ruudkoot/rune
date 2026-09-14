# Agent instructions for Rune

## Project overview

Rune is a programming-language project whose first milestone is a
Standard ML implementation compiled to portable Rune bytecode and executed by
a small C interpreter.

Keep these source boundaries clear:

- `src/sml/` contains production compiler and language implementation code.
- `src/runtime/` contains the portable C11 bytecode interpreter.
- `tests/` contains layered language, bytecode, runtime, regression, and
  performance tests.
- `docs/` contains architecture, language, interface, invariant, and workflow
  documentation.
- `reference/` contains executable behavioral oracles; `prototypes/` contains
  disposable experiments. Neither is a production dependency.
- `benchmarks/` contains stable compiler and runtime workloads.

## Before changing code

1. Read the closest relevant documentation and the applicable tests before
   changing behavior.
2. Inspect the current development environment. Confirm that `cc` (or another
   C11 compiler), `make`, and the available Standard ML tools are discoverable.
   SML/NJ is the primary toolchain; Poly/ML and MLton are compatibility
   checkers.
3. If a missing tool, broken configuration, slow setup, or other environment
   issue would prevent reliable or efficient work, tell the user explicitly.
   Separate required fixes from optional improvements and suggest concrete
   commands or configuration changes. Do not silently work around a missing
   dependency.
4. Check the working tree before editing and preserve unrelated user changes.

## Implementation and documentation rules

- Keep changes small, reviewable, and explicit about the invariant or language
  behavior they change.
- Production code may depend only on documented production interfaces. Do not
  import reference implementations or prototypes into production code.
- A new language behavior normally needs documentation, applicable positive and
  negative examples, a correctness or regression test, and a reference
  comparison when an oracle exists.
- Performance-sensitive changes need a benchmark or a documented reason why an
  existing benchmark does not apply.
- Update the closest documentation in the same change as the implementation.
  Bytecode changes must also update the bytecode contract and conformance
  fixtures; compiler and runtime invariants belong in `docs/architecture.md`.
- Do not weaken or delete a test just to make an implementation pass. Document
  intentional behavior changes instead.
- Reuse existing helpers, conventions, and test infrastructure. Keep checks
  deterministic and runnable without network access.

## Validation

Use the existing Makefile targets rather than introducing ad hoc runners:

```sh
make check
```

The complete check includes:

- `make check-sml`
- `make check-polyml`
- `make check-mlton`
- `make check-runtime`
- `make test`

Use the narrowest relevant target while iterating, then run `make check` when
the change is complete. Optional Standard ML toolchains may be reported as
skipped locally, but every skipped check must be mentioned to the user.
CI is expected to install and exercise all supported toolchains.

Before finishing:

- Review the diff for unintended changes.
- Confirm documentation and tests are synchronized with behavior changes.
- Report validation commands run, skipped checks, and any remaining
  environment issue or recommended environment improvement.
