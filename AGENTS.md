# Working on Rune

Rules for contributors and coding agents. Read `docs/architecture.md` first.

## Keep the documentation in sync (enforced)

`docs/language.md` is the contract for what Rune accepts. `make check-docs`
fails the build when it drifts from the code or tests, so every change must
keep these invariants:

* **Any change to what the language accepts or how programs behave**
  (`src/frontend/`, `src/elab/`, `src/core/translate.sml`, `lib/basis/`)
  must update `docs/language.md` (add a row, change a status, or extend the
  *Notes*/*Deviations*) **and** add or adjust a test in `tests/lang/`.
* Feature rows have an id (`exp.case`, `basis.list`, ...). A row marked
  *Supported* or *Partial* needs a test file `tests/lang/<id>_<name>.sml` with
  a hand-verified `.expected` file; a test needs a row. New ids use the
  prefixes `lex. dec. exp. pat. ty. mod. rt. basis.`. Ids contain no `_`.
* When adding a basis structure, add a `basis.<name>` row listing its members
  and add the file to `lib/basis/MANIFEST`.
* **Instruction set / primitives** change only through `vm/opcodes.def` and
  `vm/prims.def` (then `make gen`), with the corresponding implementation in
  `vm/` and a description in `docs/bytecode.md`. Bump the `.rbc` version in
  `src/backend/emit.sml` and `vm/loader.c` if the file layout changes.
* Compile-error behaviour is covered by `tests/errors/` (first error line must
  contain the `.expected` text).

## Build and verification

* Compiler sources are listed in `sources.txt` (ordered); the MLton, SML/NJ and
  Poly/ML build files are generated from it — never edit `build/`.
* The compiler must build with all three SML systems and with itself
  (`make boot`), and all four builds must produce identical bytecode. Follow
  the portability rules in `docs/building.md` (Basis-only code, no dependence
  on `Int` width, structures only at top level, deterministic iteration, and
  sources that stay inside the language described in `docs/language.md`: no
  signatures or functors, explicit `IntInf` operations).
* Before finishing any change run `make check` (= `test`, `test-all`,
  `check-cross`, `check-docs`, `test-boot`, `bootstrap`; about 20 minutes,
  use `make test` while iterating). For VM changes also run the suite with the
  sanitizer build: `make vm-asan && sh tests/run-tests.sh --vm bin/runevm-asan`.
* `.expected` files are written by hand or reviewed line by line after
  `tests/run-tests.sh --update <filter>`; never accept generated output
  blindly.

## Conventions

* SML: one `structure` per file, no top-level `open`, 2-space indentation,
  `Error.error (span, msg)` for user errors and `Error.bug` for invariant
  violations. Error messages start lowercase and name the construct.
* C: C99, no platform-specific code, every primitive validates argument tags
  (`vm_fatal` on bytecode type errors), heap pointers never live in C locals
  across an allocation (see the GC discipline in `docs/architecture.md`).
* Commit messages: imperative, one line summary.
