# Contributing to Rune

Rune changes are designed to be refactored frequently. Keep changes small,
reviewable, and explicit about the invariant or language behavior they change.

## Source boundaries

Production code may depend on documented production interfaces only. Reference
implementations and prototypes may inform production code, but production code
must not import either. Every new language behavior should have:

1. a documentation update describing the intended behavior;
2. positive and negative examples where applicable;
3. a correctness or regression test;
4. a reference comparison when an oracle exists.

Performance-sensitive changes also require a benchmark or a measured reason why
the existing benchmark suite is not applicable.

## Keeping documentation synchronized

Update the closest document in the same change as the code. Bytecode changes
must update the bytecode contract and conformance fixtures. Compiler or runtime
invariants belong in `docs/architecture.md`. Tests are executable
specification: do not weaken or delete a test to make an implementation pass
without documenting the behavior change.

## Checks

Run `make check` before submitting a change. If a local toolchain is missing,
run every available targeted check and report the skipped command. New checks
must be deterministic and runnable without network access.

## Environment setup

On Debian or Ubuntu, run `make setup` to install missing prerequisites. The
setup delegates to `scripts/setup-environment.sh`, which maps `make` and `cc`
to `make` and `build-essential`, and maps `sml`, `poly`, and `mlton` to
`smlnj`, `polyml`, and `mlton`. It uses `sudo` for non-root installations,
does nothing when all commands are already available, and reports installation
or verification failures rather than continuing silently. Other distributions
must provide the tools independently.
