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
  program more. A seal is opaque (`:>`) where it makes abstract a type that
  the specification keeps so, with a `where type` for every type that another
  signature names, since that signature was read with the structure whole; a
  type that several structures share has to be made abstract where it is
  declared instead. `docs/generated/basis/types.md` lists what still leaks.
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
* **Instruction set / primitives** change only through their descriptions,
  `src/isa/stack.sml` and `src/isa/prims.sml` (then `make isa`, which writes
  the generated files and `vm/opcodes.def` and `vm/prims.def`; `make
  check-isa` fails when they are stale), with the corresponding implementation in
  `vm/` and a description in `docs/bytecode.md`. A primitive that needs the
  operating system goes behind a new call of `vm/sys.h` that every layer
  answers -- `sys_posix.c`, `sys_win.c` and `sys_none.c`, with `ENOSYS` where
  there is nothing to do -- and is written on the hosts in
  `tests/basis/host/rune-prim.sml`, which the `xc1` configurations of the
  Basis Library suite run. Bump `rbcVersion` in
  `src/isa/stack.sml` if the file layout changes; a change to the
  instructions or the primitives changes the fingerprint of the instruction
  set by itself, which the `.rbc` and images carry.
* **Native code** (`runeopt`, `docs/native.md`): an instruction has,
  beside its description and body in `src/isa/stack.sml` (from which the
  interpreter's case and its stack effect are generated), a template in
  `src/opt/x64.sml`, which MLton's build of `runeopt` refuses to go
  without, and where it calls into C a helper in `vm/native.c`, the shared
  `op_<NAME>` of `vm/ops.h` where its body is shared; a change to what an
  instruction does changes all of them, and a new one goes into
  `tests/opt/every-opcode.rasm`, which runs every instruction. The `.rbc` format is read by `src/opt/rbc.sml` as well, with
  the loader's messages. A field of the VM that the code touches is named in
  `vm/native_offsets.c`, never written as a number. `make test-native` runs
  the suites as native code and wants `--count` to agree with `runevm`. The
  primitives whose common case the code does itself (`runeopt --inlined`,
  `fastPrim` in `src/opt/x64.sml`) change with their C code in
  `vm/prims.c`: `tests/opt/prims.sml` runs each on its edge cases, natively
  and on `runevm`, and must use every one of them. The templates also copy
  the push and pop of a frame (`vm_push_frame`, `native_call`, `native_ret`)
  and the fast path of `vm_alloc` (when it collects, `--gc-stress`, the
  header, the counts): a change to either changes the templates too. An
  instruction in the list `reads` of `x64.sml` must never write its top
  operand in place, since a LOCAL may have left it in its local
  (`docs/native.md`).
* **A pass of the compiler** (docs/ir.md) runs through `Pass.stage`, with the
  printer and the size of what it makes and the lint of its representation;
  a pass that rewrites asks `Pass.spend` before each rewrite, and one that
  optimises says from which level it runs. It comes with a test in
  `tests/ir`, and what its representation keeps is written down in
  `docs/ir.md`. Code is made by `Lower` and a target (`Stack`, `Regs`) at
  every level, after the optimisations of Mid from `-O1` (`Shake`, `Lift`,
  `Workers`, `Simplify` with its inlining and specialisation): `make
  check-levels` holds `-O0` (no optional pass) and `-O2` to the same
  output, traces included, and exit status for every program. A pass that
  moves code into another function keeps its frames for traces (`Mid.pos`,
  docs/ir.md, *Positions*). A rewrite must leave every lint satisfied at
  any `--fuel`: what it makes of several parts is one rewrite, or each part
  is valid alone.
* **The stack VM's loop** (`vm/interp.c`, `vm/loop.h`) keeps its state in
  its own variables: a body of `src/isa/stack.sml` that is not shared is
  written in the loop's words (`PUSH`, `POP`, `TOP`, `LOCALV`, `JUMP_TO`,
  and `SYNC()` before anything that reads the VM's stack pointer or pc --
  the collector, a raise, a primitive, a frame pushed -- with `RELOAD()`
  after what may change them); a shared one (vm/ops.h, which runeopt's code
  calls) is written against the VM. A push does not check: the loader works
  out each function's deepest stack (`vm/isa_stack.c`), so an instruction's
  `pops`/`pushes` must say what it does.
* **vm/new** (`vm/new/`, `bin/runevm-new`) runs the register bytecode
  (`src/isa/regs.sml`, `rune --target=registers`) on the runtime of
  `runevm`, whose part that is the stack bytecode's is `vm/isa_stack.c` and
  vm/new's `vm/new/isa_regs.c`. `make test-new`, part of `make check`, holds it
  to what `runevm` prints and allocates; a change to the register
  instruction set is `make isa` and a test, as for the stack one.
* Compile-error behaviour is covered by `tests/errors/` (first error line must
  contain the `.expected` text). Warnings are covered by a `.cwarn` file next
  to a `tests/lang/` test (the compiler's stderr, compared exactly); a test
  without one must compile silently.

## Build and verification

* Compiler sources are listed in `sources.txt` (ordered), those of the
  documentation generator `runedoc` in `sources-doc.txt` and those of the
  native code generator `runeopt` in `sources-opt.txt`; the MLton, SML/NJ and
  Poly/ML build files are generated from them — never edit `build/`.
* The SML systems come from `make hosts` (`${RUNE_HOSTS:-~/.local/rune-hosts}`),
  never from the machine's PATH.
* In a cloud coding environment (e.g. `CLAUDE_CODE_REMOTE=true`), follow
  `cloud/SETUP.md` first. On Claude Code on the web its session-start hook
  (or the environment's setup script, where several repositories keep the
  hook from running) prepares the machine and writes what it did to
  `/tmp/rune-session-start.status`; where that file is missing, run
  `make doctor` and ask the user before installing the packages it reports.
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
  `test-basis`, `test-doc`, `test-opt`, `test-native`, `perf-check`, `check-positions`,
  `check-cross`, `check-docs`, `check-isa`, `test-ir`, `check-levels`,
  `bootstrap`; runs on all CPUs,
  about 3 minutes on 16). `bin/rune` is the self-hosted compiler, so it is what
  every test target uses by default; `make test RUNE=bin/rune-mlton` runs the
  same suite with the MLton build and is the faster loop while iterating. For
  VM changes also run the suite with the
  sanitizer build, `make vm-asan && sh tests/run-tests.sh --vm bin/runevm-asan`,
  and with a collection at (nearly) every allocation, `make test-stress`.
* `make check` never compiles `vm/sys_win.c`, so a green `make check` says
  nothing about Windows. A change to the VM core, to `vm/sys.h` or to the
  system layers is done only once `make windows` builds both VMs and
  `make test-windows` passes on both (`tests/lang`, `tests/vm` and the Basis
  Library suite; about 8 minutes). It needs the mingw-w64 toolchains and a
  Windows to run the `.exe`s, which is what `make doctor` reports.
* `make check` also builds the VM for one machine only, so it says nothing
  about a machine of another width or another byte order. `make portability`
  builds it for a 32-bit x86 and for a big-endian 64-bit PowerPC, and
  `make test-portability` runs `tests/lang`, `tests/vm` and the Basis Library
  suite on both -- the PowerPC one under qemu -- checks that the counts of
  `--count` agree to the byte on every VM, and carries an image of
  `Runtime.save` between them in every direction. A change to the layout of a
  value, to the heap, to the bytecode format or to `vm/image.c` is not done
  until it passes. It needs a 32-bit libc, clang, a powerpc64 sysroot and
  qemu, which `make doctor --scope portability` reports. Two bugs it found
  when it was written: a `Value` of 12 bytes where the 32-bit System V ABI
  aligns an `int64_t` to four, and `realpath` undeclared under an older
  glibc's headers.
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
* Commits are authored by Ruud Koot <inbox@ruudkoot.nl>, also when an agent
  makes them; an agent commits as Claude <noreply@anthropic.com>, whose
  commits a cloud session can sign (git's `author.*` and `committer.*`
  settings, which the session-start hook sets). An agent ends the message
  with its `Co-Authored-By:` line and nothing else: no `Claude-Session:` or
  other link to the session.
