# Working on Rune

Rune is a Standard ML ’97 subset compiler written in Standard
ML, with bytecode executed by a portable C VM. Read [the plan](docs/PLAN.md) and
[the language contract](docs/LANGUAGE.md) before implementing compiler features.

## Language and documentation changes

- Any change to accepted syntax, typing, evaluation, built-ins, numeric limits,
  or unsupported constructs must update `docs/LANGUAGE.md` in the same change.
- Add or update a positive example and a relevant rejection or boundary test for
  each language feature. Once the feature manifest and documentation checks
  described in the plan exist, update them too.
- Distinguish planned, implemented, partial, and deferred support. Mark a feature
  implemented only after its tests pass using all three host-built compilers.
- Changes to bytecode or VM behavior must update `docs/BYTECODE.md` once created,
  including versioning and compatibility consequences.
- Changes to build commands or dependencies must update the README and build
  documentation. Keep the plan's milestone status accurate.

## Portability and verification

- Keep the compiler core in the common SML ’97/Basis subset of SML/NJ, Poly/ML,
  and MLton. Isolate host extensions in build and entry-point adapters.
- Do not derive Rune integer semantics or bytecode encoding from host `int`
  precision, host word size, endianness, or pointer representation.
- Keep the VM within the documented ISO C platform requirements.
- Once available, run `make test-all` for compiler or runtime changes and
  `make check-docs` for language documentation changes. Report unavailable checks
  and failures explicitly; missing hosts do not count as passing.
- Until these targets exist, verify changes appropriately and describe what
  actually ran. Do not present proposed commands as working implementations.
