# Building HOL on Rune

Build the `corpus/HOL` checkout on branch `rune-build`. The port lives in
`tools-rune/`; this file is the build to run and what that build contains.
The tree is built in place. Leave it in this directory afterwards.

The changes on top of Trindemossen-2 are listed at the end.

`rune`, `runevm`, and `rune-repl` must be executable in one directory, and
`rune` must be on `PATH`. `make` (or `gmake`) and a C compiler are required.
Graphviz `dot` is optional; configure records it when it is on `PATH`, and
the build then writes the theory graph.

## Configure and build

From the Rune repository:

```sh
cd corpus/HOL
sh tools-rune/configure.sh
bin/build -j"$(nproc)" --selftest=3
```

`configure.sh` is the Rune counterpart of `poly < tools/smart-configure.sml`.
With `RUNE` unset it uses the directory of the `rune` on `PATH`. It writes
`tools-rune/Holmake/Systeml.sml`, compiles Holmake, `build`, mllex, mlyacc,
and the other tools, and creates `bin/buildheap`, `bin/hol`, and
`bin/hol.bare`. Those scripts record the absolute directory of the `rune`
they found and the absolute directory of this tree. Compiler and REPL output
goes to `tools-rune/cache`.

`bin/build -jN --selftest=3` is the full build on the standard kernel
(`src/0`): every theory on the Rune sequence, the help database, and the
regression suite. `-j` is Holmake's process limit (`Posix.Process.fork`).
The level is attached to the option, `--selftest=3` or `-t3`. `--selftest`
alone is level 1.

A finished build prints `Hol built successfully.` Each regression directory
prints `Self-test directory … built successfully.` A failure stops the run
with `Build failed in directory …`. Add `-k` to continue past a failure.
The build log is `tools-rune/build-logs/`. Each self-test also writes a log
beside itself, such as `src/boss/boss-selftest.log`. A later
`bin/build -j"$(nproc)" --selftest=3` rebuilds what changed and runs the
tests again. If stale dependencies survive a failed run, `bin/build cleanAll`
and then the build command again.

MiniSat (`src/HolSat/sat_solvers/minisat`) and zc2hs are compiled with
`make`. If either fails, the build warns and continues. The theory graph is
part of the default build when configure found `dot`. `bin/build --nograph`
skips it.

After a successful build, `bin/hol` is the interactive system and
`bin/hol.bare` is the system through `bool`.

## What the build includes

`bin/build` follows `tools/build-sequence`. Holmake sets `POLY` for Rune, so
a Holmakefile block under `ifdef POLY` is included. A sequence line tagged
`[rune]` or `[poly,rune]` is included. A line tagged only `[poly]` or only
`[mosml]` is skipped. A line marked `!` runs at self-test level 1 and above,
and `!!` at level 2 and above. Level 3 includes levels 1 and 2. Nothing in
this tree asks for a level above 3.

### Theories, without `--selftest`

The kernel, the core theories through `bossLib`, and `bin/hol.bare` and
`bin/hol`:

- `src/portableML/rune`, `src/portableML`, `src/portableML/monads`,
  `src/portableML/rawtheory`, `src/portableML/json`,
  `src/portableML/rune/concurrent`
- `src/prekernel`, `src/0`, `src/thm`, `src/postkernel`, `src/parse`,
  `src/opentheory`, `src/bool`, `src/1`, `src/proofman`
- `src/compute`, `src/HolSat` (including its solver directories and
  `vector_def_CNF`), `src/taut`, `src/marker`, `src/q`, `src/combin`,
  `src/lite`, `src/refute`, `src/simp`, `src/metis`, `src/meson/src`,
  `src/IndDef`, `src/basicProof`, `src/relation`, `src/quotient/src`,
  `src/coretypes`, `src/tfl/src`
- `src/num` (theories, `cv_compute`, `reduce`, `arith`, `termination`,
  `extra_theories`), `src/unwind`, `src/pred_set/src`, `src/datatype`
  (including `record`), `src/monad`, `src/list/src`, `src/quantHeuristics`,
  `src/pattern_matches`, `src/boss/ml_evaluation`, `src/opentheory/reader`,
  `src/boss`

Then `src/parallel_builds/core`, which builds the rest of the library:

`algebra`, `bag`, `Boolify`, `coalgebras`, `datatype/inftree`, `emit`,
`finite_maps`, `float`, `floating-point`, `floating-point/native`, `hol88`,
`HolQbf`, `HolSmt`, `integer`, `monad/more_monads`, `n-bit`,
`pred_set/src/more_theories`, `probability`, `rational`, `real`,
`real/analysis`, `res_quan`, `search`, `sort`, `string`, `TeX`, `transfer`,
`update`, and `num/theories/cv_compute/automation`.

The run ends with the help database.

### Regression suite, `--selftest=3`

These sequence directories, in addition to the theories above.

Level 1:

- `tools/Holmake/tests/holdep`, `depchainloop`, `recursiveclean`,
  `wildcard`, `dashn_works`, `dupcommands`, `varextension`, `badincludes`,
  `incs_vs_sigobj/dir2`, `preexec`, `parallel_tests`, `repl`
- `src/portableML/testsrc`, `src/proofman/tests`, `src/1/theory_tests`,
  `src/basicProof/theory_tests`,
  `src/num/theories/cv_compute/soundness_check`,
  `src/datatype/theory_tests`, `src/pattern_matches/interactive_tests`,
  `src/boss/theory_tests`, `src/tfl/src/test`, `src/emit/theory_tests`,
  `src/emit/theory_tests1`

Level 2 adds `src/emit/ML`.

`src/parallel_builds/core` also builds the following when
`HOLSELFTESTLEVEL` is set. Paths under `examples/` are inside `examples/`.
The `src/` paths are inside `src/`.

Level 1 adds `tools/Holmake/tests/Iflag` and:

- `src/quotient/examples`, `src/quotient/examples/lambda`,
  `src/quotient/examples/sigma`, `src/quotient/choice`, `src/tfl/examples`
- `src/integer/testing`, `src/string/theorytesting`, `src/TeX/theory_tests`,
  `src/TeX/theory_tests/proj1paper`, `src/transfer/examples`,
  `src/finite_maps/theory_tests`, `src/n-bit/interactive_tests`,
  `src/num/theories/cv_compute/automation/theory_tests`
- `examples/algebra/aat`, `examples/arm/arm6-verification`,
  `examples/arm/armv8-memory-model`, `examples/arm/experimental`,
  `examples/axiomatic-developments/set-theory/vbg`,
  `examples/axiomatic-developments/set-theory/zfset`,
  `examples/axiomatic-developments/geometry`, `examples/bnf-datatypes`,
  `examples/CCS`, `examples/Crypto/RSA`, `examples/Crypto/SHA-2`,
  `examples/Crypto/MD5`, `examples/Crypto/pedersenCommitment`,
  `examples/Crypto/sigmaProtocol`, `examples/Hoare-for-divergence`,
  `examples/MLsyntax`, `examples/PSL/1.01/executable-semantics`,
  `examples/PSL/1.1/official-semantics`, `examples/STE`,
  `examples/algorithms`, `examples/computability`, `examples/countchars`,
  `examples/dependability`, `examples/dev`, `examples/developers/ThmSetData`,
  `examples/fermat`, `examples/formal-languages`,
  `examples/formal-languages/context-free`, `examples/formal-languages/contig`,
  `examples/formal-languages/json`, `examples/formal-languages/lambek`,
  `examples/formal-languages/regular/regular-play`,
  `examples/formal-languages/pi-calculus`, `examples/fun-op-sem/coimp`,
  `examples/fun-op-sem/lprefix_lub`, `examples/fun-op-sem/for`,
  `examples/hardware`, `examples/hfs`, `examples/imperative`,
  `examples/ind_def`, `examples/l3-machine-code/common`, `examples/lambda`,
  `examples/logic`, `examples/logic/folcompactness`,
  `examples/logic/modal-models`, `examples/logic/modal-tableaux`,
  `examples/logic/ncfolproofs`, `examples/logic/propositional_logic`,
  `examples/logic/relevant-logic`, `examples/logic/temporal/src`,
  `examples/misc`, `examples/padics`, `examples/parity`, `examples/rings`,
  `examples/zipper`, `examples/RL_Environment`, `examples/cv_compute`

Level 2 adds:

- `examples/AKS`, `examples/algebra`, `examples/algorithms/boyer_moore`,
  `examples/algorithms/unification/triangular/nominal`,
  `examples/algorithms/unification/triangular/first-order/compilation`,
  `examples/arm/arm6-verification/correctness`, `examples/arm/v4`,
  `examples/arm/v7`, `examples/balanced_bst`, `examples/category`,
  `examples/computability/kolmog`, `examples/computability/lambda`,
  `examples/computability/recdegrees`, `examples/computability/register`,
  `examples/computability/turing`, `examples/Crypto`,
  `examples/decidable_separationLogic/src`, `examples/formal-languages/regular`,
  `examples/fun-op-sem`, `examples/generic_graphs`,
  `examples/lambda/other-models`, `examples/lambda/typing`,
  `examples/logic/ltl`, `examples/logic/temporal_deep`,
  `examples/logic/ltl-transformations`, `examples/l3-machine-code/decompilers`,
  `examples/probability/legacy`, `examples/miller`, `examples/probability`,
  `examples/vector`, `examples/separationLogic/src`,
  `examples/separationLogic/src/holfoot`, `examples/simple_complexity`,
  `examples/separationLogic/src/holfoot/poly`,
  `examples/logic/temporal_deep/src/examples`, `examples/bootstrap`

Level 3 adds `examples/arm/ARM_security_properties`,
`examples/diningcryptos`, `examples/l3-machine-code/cheri/step`,
`examples/machine-code`, and `examples/theorem-prover`.

`--selftest=1` and `--selftest=2` are the same build with those smaller
sets.

## What the build leaves out

Sequence lines tagged only `[poly]`:

- `tools/check-builds`
- `src/portableML/poly`, `src/portableML/poly/concurrent`
- `src/meson/test` (self-test level 2)
- `src/AI`, `src/AI/sml_inspection`, `src/AI/proof_search`,
  `src/AI/machine_learning`
- `src/tactictoe/src`, `src/tactictoe/selftest`
- `src/holyhammer`

Sequence lines tagged only `[mosml]`: `src/portableML/mosml`,
`src/portableML/mosml/concurrent`, `examples/muddy`, `examples/muddy/muddyC`,
`examples/HolBdd`, `examples/HolCheck`,
`examples/separationLogic/src/holfoot/mosml`, and
`examples/logic/temporal_deep/src/model_check`.

Developments that sit in the tree and are absent from the sequence and from
the `src/parallel_builds/core` Holmakefile, including `examples/acl2`,
`examples/AI`, `examples/elliptic`, `examples/finite-test-set`, and
`examples/pgcl`.

`bin/build --expk` (the experimental kernel) and `bin/build --otknl` (the
OpenTheory kernel) are separate builds. The command above is the standard
kernel. OpenTheory logging directories (`src/opentheory/logging`,
`src/opentheory/postbool`) and the old arithmetic conversion
(`src/num/reduce/conv-old`) belong to `--otknl`.

`--mt` is the in-image thread count. Rune's `Thread.fork` runs its function
to completion before returning, and this build does not pass `--mt`.
`examples/RL_Environment` is included. Its `smlTimeout.timeout` call runs
the tactic to completion: the threaded structure is in
`src/AI/sml_inspection`, which this build skips, and
`src/portableML/rune/smlTimeout.sml` supplies the name. The language
server (`--lsp`) is unimplemented. `buildheap --exe` saves the world as an
image and writes a script that restores it and runs the named function.
`bin/build` also rejects a request to build a named list of directories.

## Changes on top of Trindemossen-2

`rune-build` starts from Trindemossen-2 (`bdc6917ee`). Everything since
that commit is one of the three groups below.

### 1. Rune bugs, and workarounds for them

Rune stops one polymorphic `=` after one million steps. The budget is
stored in the image, and restore keeps the stricter of that budget and
`--equality-work`, so a later flag cannot raise it. `Term.identical`
compares a whole term with one `=`. The Milawa core term is larger than
a million steps, and `milawa_coreTheory` died with `equality work limit
exceeded`. `tools-rune/configure.sh` writes a budget of one billion into
`tools-rune/bin/buildheap.img` after the image is saved. Heaps saved from
that image keep the larger budget.

Poly/ML extends `loadPath` and then `loadState` replaces the process, so
the extension remains only for `--poly`. Rune has already restored the
image when `buildheap` runs, and `prelude.ML` extends the path again.
Doing it in both places put `tools/cmp` on the REPL load path twice.
`tools-rune/buildheap.ML` extends the path only when the base is `--poly`.

`Thread.fork` runs its function to completion before returning. The help
database's worker threads therefore run one after another
(`7766d229d`). `src/portableML/rune/smlTimeout.sml` defines
`smlTimeout.timeout` as a call of the function. `examples/RL_Environment`
uses that name. The threaded implementation lives in `[poly]`
`src/AI/sml_inspection`, which this build skips. This build does not pass
`--mt`.

A file passed to `use` does not see the REPL's `val` bindings. The REPL
also exits 0 after a static error, so Holmake treated a missing
`holfoot.state` as built. `rune-savestate.ML` writes the name
`holfoot.state` itself, and `build-state.hol` exits with failure when
that file is absent.

Rune has no native code export. `buildheap --exe NAME` saves the world as
`OUT.img` and writes `OUT` as a script that restores it and runs `NAME`.
`bin/mkmunge.exe` and the holfoot programs are built that way.

### 2. Standard ML '97, and Poly/ML extensions

Rune rejects an infix identifier used as a value. Inside a HOL quotation
the parser does not see it. An antiquotation is Standard ML, so it does.

- `examples/algebra/ring/ringLib.sml` uses `op =` and `op ^`.
- `examples/formal-languages/regular/regularScript.sml` binds `val op -`.
  A bare `val -` is an infix pattern. `op` rebinds the value and leaves
  the fixity.
- `src/thm/Overlay.sml` declares `infix IN`. Opening the set theory binds
  the value `IN` to a theorem and leaves the fixity, so a bare `IN` is
  still an infix. `nonfix IN` is added in
  `src/quotient/examples/more_setScript.sml` and in the lambda and sigma
  scripts that use the theorem as a value. `nonfix` is lexical and does
  not escape the script. Each theory script is its own process.

`tools-rune/holrepl.ML` adds `Time.time` values with `Time.+`. Rune's
`Time` has no overloaded `+`.

These Poly/ML names are absent from the shim in `tools-rune/rune-polyml.ML`:

- `PolyML.objSize` was a size in a trace in
  `examples/formal-languages/regular/Regexp_Match.sml`. The trace no
  longer prints it.
- `PolyML.rtsVersion` was the banner in
  `examples/machine-code/graph/file_readerLib.sml`. The banner prints
  `PolyML.Compiler.compilerVersionNumber`, which the shim sets to 0.
- `PolyML.SaveState` is how
  `examples/separationLogic/src/holfoot/poly/build-state.hol` wrote its
  heap. Poly/ML elaborates `poly-savestate.ML`
  (`PolyML.SaveState.saveState`). Rune elaborates `rune-savestate.ML`
  (`Runtime.save`, and on restore `(!rune_main) ()`). The two names are
  not in one declaration: both branches of an `if` are elaborated.
- `PolyML.export` is the native `--exe` path. The image script above
  stands in for it.
- `polyc` takes its file after the Poly/ML-style names, which is the
  order the help tools' Holmakefiles write (`419489d1e`).

`PolyML.Compiler.lineLength` is Rune's ref. Rune starts it at 80. The shim
sets it to 77, which is Poly/ML 5.9.2's initial value and HOL's
`Globals.linewidth`. `src/1`'s large-COND selftest breaks a line of 80
columns at that width. The assignment is inside `tools-rune/bin/buildheap.img`.
An image saved before the assignment keeps the old width until the base
image is built again.

`src/portableML/rune/PrettyImpl.sml` lays documents out as Poly/ML 5.9.2's
pretty printer does. `src/proofman/tests` compares `gh725Theory.html` with
that layout, at width 78.

`PolyML.addPrettyPrinter` is `Compiler.addPrettyPrinter` (`3d15b18a8`).
`PolyML.prettyRepresentation` still shows any value as `?`, because Rune
prints a value only by a type it knows when the printer is compiled.

The zero-terminated REPL prints `val it = 1 : int`. A syntax error is
`Static errors in <stdIn>` on standard output, and the phrase goes to
standard error. `tools/Holmake/tests/repl` compares that transcript with
`testN.expected-rune`. The quote-filter test compares `unquote` with
`expected-poly` when `ML_SYSNAME` is rune, because `Systeml.bindstr` is
Poly/ML's `quietbind` form.

### 3. HOL, its build, and its theories

`tools-rune/` is the Rune configuration, beside `tools-poly/`.
`configure.sh` writes `Systeml.sml` (`ML_SYSNAME = "rune"`), compiles
Holmake, `build`, mllex, mlyacc, and the other tools with `rune`, and
creates the base image and `bin/buildheap`, `bin/hol`, and `bin/hol.bare`
(`c5a2f741f`, `7fd1a8d71`). `src/portableML/rune` is the portable layer:
the plain Standard ML files from `poly` and the thread-free files from
`mosml`, plus `MLSYSPortable`, `Counter`, `PrettyImpl`, and `smlTimeout`.
`tools/sequences/kernel` and `core-theories` tag directories `[rune]` or
`[poly,rune]`. `tools/buildutils.sml` reads a tag that names several
systems. `ML_SYSNAME=rune` sets Holmake's `POLY` and `POLYC`, so an
`ifdef POLY` block is included.

`tools/unicode-grep` opened `tools-poly/Holmake/Systeml.sml`, which this
configuration does not write. `rune-ugrep.ML` starts from
`tools-rune/rune-init.ML`, and the Holmakefile uses it when `ML_SYSNAME`
is rune (`7c812714b`).

`bin/hol.state` is produced in `src/boss`. Until then the kernel-phase
Holmake tests use `bin/hol.state0`. These self-tests special-cased
`ML_SYSNAME = "poly"` and now do the same for `rune`:

- `badincludes` accepts Holmake's `Finished` line. Rune's Holmake is
  Poly/ML's and prints that line.
- `clinevars` and `theorytarget` pass `--holstate bin/hol.state0` into
  the nested Holmake. `clinevars/Holmakefile` sets `HOLHEAP` to that
  file under `ifdef POLY`. Without it the directory depends on the
  absent `bin/hol.state`.
- `empty_script` passes the same `--holstate` for its `-j4` and `-j1`
  checks. The check looks for `Couldn't find required output file:`
  together with `emptyTheory` and `noproductTheory`. Under `-j4` those
  lines arrive in either order, and the check accepts either order.
- `gh604` passes `--noconfig` to `hol.bare`.

`EXTRA_CLEANS` lists the `.img` file beside each program built with
`--exe`: CCS and lambek `munge.exe`, the TeX theory-test mungers, the
integer `munger`, the string `munge.exe`, and proj1paper's `munge.exe`.

A killed `export_theory` can leave `Theory.sml` and `Theory.sig` empty
while `Theory.dat` is already complete. The next Holmake treats the empty
files as up to date. That happened to `ieeeTheory`, `floatTheory`, and
`separationLogicTheory` during this port. The files were deleted and the
theories rebuilt. The scripts were left as they were.
