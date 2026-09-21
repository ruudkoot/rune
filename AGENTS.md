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
* `lib/basis/DOCUMENTED` lists the signatures that are documented in full,
  which is all 65 of them. A member added to one needs a doc comment, a
  function among them a usage head (`docs/doc-comments.md`): `make docs` and
  `make check-docs` fail otherwise. A new signature joins the list in the
  commit that finishes documenting it, and none should be added without one.
* A program sees of a basis structure what its signature names and nothing
  else: a structure that is not ascribed its signature where it is declared
  is bound to it again in a seal file at the end of `lib/basis/MANIFEST`
  (`seal_list.sml`: `structure List : LIST = List`), which is loaded for the
  programs that mention the structure and for no file of the library, so the
  library keeps its helpers. `make docs` fails for a structure that shows a
  program more. A type that the specification keeps abstract is made
  abstract where it is declared, not by the seal, which is transparent.
* A basis structure says which signature it implements in the comment above
  it (`Implements: SIG where type ...`, `docs/doc-comments.md`), and
  `tests/basis/<name>_sig.sml` matches it against the transcription;
  `make check-docs` (`tests/basis/check-claims.sh`) wants both.
* When adding a basis structure, add a `basis.<name>` row listing its members
  and add the file to `lib/basis/MANIFEST` with what it provides and requires
  (`rune --basis-check`, part of `make check-docs`, verifies the columns; a
  file loaded on demand declares modules and types only, all in its provides column). A signature of the
  specification is transcribed in `tests/basis/spec-sigs` first;
  `scripts/gen-basis-sigs.sh` then makes `lib/basis/sig_<sig>.sml` and its
  MANIFEST line, and from there on the library's file is edited by hand
  (`make check-docs` wants the same tokens in both). Its test belongs to the Basis
  Library suite: `tests/basis/<name>.sml` and `tests/basis/<name>_sig.sml`,
  written as `tests/basis/README.md` describes, with expected values worked
  out from the text of the specification. `make check-docs` wants a check for
  every member the specification's signature names, and `make test-basis` an
  explanation in `tests/basis/deviations.txt` for every check that fails. A
  reading of the specification, a deviation from it or a choice it leaves
  open is written down once, as a note in the doc comment of the member
  (`docs/doc-comments.md`); a `rune` line of `deviations.txt` needs such a
  note (`tests/basis/check-notes.sh`). After changing a line of
  `deviations.txt` about a host, run `sh tests/basis/gen-annotations.sh` and
  `make docs`: the documentation shows those lines under the members, from
  the committed `tests/basis/annotations.txt`.
  After a library change run `make matrix-quick` as well: it runs the suite
  on Rune's library compiled by each host (MLton, SML/NJ in 64 and 32 bits,
  Poly/ML); `make matrix` adds the suite on each host's own library.
* **Instruction set / primitives** change only through `vm/opcodes.def` and
  `vm/prims.def` (then `make gen`), with the corresponding implementation in
  `vm/` and a description in `docs/bytecode.md`. Bump the `.rbc` version in
  `src/backend/emit.sml` and `vm/loader.c` if the file layout changes.
* Compile-error behaviour is covered by `tests/errors/` (first error line must
  contain the `.expected` text). Warnings are covered by a `.cwarn` file next
  to a `tests/lang/` test (the compiler's stderr, compared exactly); a test
  without one must compile silently.

## Build and verification

* Compiler sources are listed in `sources.txt` (ordered), those of the
  documentation generator `runedoc` in `sources-doc.txt`; the MLton, SML/NJ and
  Poly/ML build files are generated from them — never edit `build/`.
* The SML systems come from `make hosts` (`${RUNE_HOSTS:-~/.local/rune-hosts}`),
  never from the machine's PATH.
* The compiler has no built-in library path: `--lib DIR` is required, and each
  `bin/rune*` is a generated wrapper that passes it and execs the payload next
  to it. Nothing absolute is baked into the bytecode. `make install` writes the
  same kind of wrapper for the installed tree (`scripts/install.sh`).
* The compiler must build with every host SML system and with itself
  (`make boot`), and all five builds must produce identical bytecode. Follow
  the portability rules in `docs/building.md` (Basis-only code, no dependence
  on `Int` width, only `structure`/`signature`/`functor` at top level,
  deterministic iteration, and sources that stay inside the language
  described in `docs/language.md`: explicit `IntInf` operations, Rune's
  Basis subset).
* Before finishing any change run `make check` (= `test`, `test-all`,
  `test-basis`, `perf-check`, `check-cross`, `check-docs`, `bootstrap`; runs on all CPUs,
  about 3 minutes on 16). `bin/rune` is the self-hosted compiler, so it is what
  every test target uses by default; `make test RUNE=bin/rune-mlton` runs the
  same suite with the MLton build and is the faster loop while iterating. For
  VM changes also run the suite with the
  sanitizer build, `make vm-asan && sh tests/run-tests.sh --vm bin/runevm-asan`,
  and with a collection at (nearly) every allocation, `make test-stress`.
* `tests/external/run-mlton.sh DIR` runs MLton's regression programs
  (`regression/` of github.com/MLton/mlton, not part of this repository) as
  an external conformance corpus; `tests/external/mlton-skip.txt` lists the
  programs that need Basis Library parts Rune lacks or MLton-specific
  behaviour, each with its reason. A program that fails and is not on that
  list is a bug.
* Comments are written in the language of `docs/doc-comments.md`, and in a
  signature every comment documents something, is a `----` heading or is
  prose; `make check-docs` lints `lib/basis` and `src`. The documentation in
  `docs/generated/basis` is made from the library's comments: after changing
  a signature or a comment of `lib/basis`, run `make docs` and commit what it
  writes (`make check-docs` fails on a stale tree). Never edit it by hand.
  An `Example:` that is an equation, `e = v`, is compiled by `make docs` and
  run by `make test-basis`; give a description an example where it shows
  what prose cannot, and find its value by running it.
* A change to the documentation generator (`src/doc`) needs a test in
  `tests/doc` (`make test-doc`): an input and the expected `.ir`, `.md` and `.diag` next to it,
  reviewed line by line like any `.expected` file.
* `.expected` files are written by hand or reviewed line by line after
  `tests/run-tests.sh --update <filter>`; never accept generated output
  blindly.

## Conventions

* SML: one main `structure` (or `functor`) per file, no top-level `open`, 2-space indentation,
  `Error.error (span, msg)` for user errors and `Error.bug` for invariant
  violations. Error messages start lowercase and name the construct.
* C: C99, no platform-specific code, every primitive validates argument tags
  (`vm_fatal` on bytecode type errors), heap pointers never live in C locals
  across an allocation (see the GC discipline in `docs/architecture.md`).
* Commit messages: imperative, one line summary.
