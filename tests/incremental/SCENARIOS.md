# The cache's scenarios

What `tests/incremental` will hold the cache to (incremental roadmap, M1
wrote the list and M6 makes it run; `docs/plans/incremental-compilation.md`,
D14 and *Testing*). Each scenario starts from a scratch project, does
something to it, builds again, and asserts two things: which units were
compiled again (`--explain-rebuild`, with the reason it names) and that the
output equals that of a build with `--no-cache`, byte for byte where the
program is the same and in what it prints, exits with and traces where the
build mode differs. A scenario's id is what the runner and a failure name.

`bin/rune-incremental scenarios` (`make test-incremental`, in `make check`) runs
every scenario a runner can make, on the project of
`tests/incremental/project` or on one of its own: S1 to S26 (S23 not on
a file system without case), S28 to S36, S40, S49 to S69, and S72. `tests/repl/usecache.in` is S38 and `tests/repl/usechanged.in`
S39; the oracle `cross` of `tests/runner/oracles.sml` (`rune-units`) is S43; S41 is `make
check-units`, and S42 is `make check-units` (`--units --whole`) and
`check-cross` (`rune-whole`). Beside them, `bin/rune-incremental mutate` edits projects
mechanically and wants each warm build to be what compiling everything
gives (*Edits nobody wrote*, below), and `bin/rune-incremental mlton` is
S44 to S48.

Where the cache does less than a scenario asks, its runner holds it to
what it does, and says so:

* a usage holds by its binder or by its fingerprint (`docs/units.md`,
  *The cache*, *Fingerprints*), and a type's fingerprint is its definition:
  S11 compiles the unit that only names the type whose representation
  changed, which is the scenario's correct fallback; a functor holds by
  its signature, but a unit that applies one to make code depends on the
  unit that declared it too, so S8 compiles every unit that applies the
  functor; an overloading holds by its binder alone, so S28o compiles every
  unit that resolved the overloading;
* a unit is known by its name, which is in its identity: two files of the
  same text and different names are two units (S7 is run as one project
  in two directories), a file renamed is another unit, and the units that
  used it compile again (S21 compiles `c2.sml` and `d.sml`), and a source
  reached through a link to it is named by the link (S22 is run as a link
  to the project's directory).

Not run: S27 wants a second build of the compiler to other bytes, and S37
a disk that fills, which a user cannot make here (`ulimit -f` would stop
the program's own file too); S36's read-only cache is the store that
fails.

Unless a scenario says otherwise, the project is five files in order: `a.sml`
declares a structure, a signature, a datatype and an exception; `b.sml` uses
`a.sml`; `c.sml` declares a functor; `d.sml` applies it to `b.sml`'s
structure; `main.sml` uses all of them and prints. "Recompiles X" means
exactly the units X and nothing else.

## Hits and misses

* **S1, cold then warm.** Build twice. The second build compiles nothing, and
  the two outputs are the same bytes.
* **S2, a body.** Change the body of a function in `a.sml`, not its type.
  Recompiles `a.sml` only: no export entry that another unit used changed
  (the cut-off).
* **S3, a used type.** Change the type of a value of `a.sml` that `b.sml`
  uses. Recompiles `a.sml` and `b.sml`, then whatever used what `b.sml`
  exports, if that changed.
* **S4, an unused entry.** Add a value to `a.sml`, and change the type of
  one no unit uses. Recompiles `a.sml` only: usages are per entry, not per
  unit.
* **S5, revert.** Make S3's change, build, undo it, build. The second build
  finds the first entries and compiles nothing: entries are kept by
  content, not replaced.
* **S6, touch.** Change a file's time and nothing else. Compiles nothing:
  nothing in the cache is a time.
* **S7, the same text twice.** Two files with the same contents at
  different paths, or one file in two projects with the same units before
  it. One entry serves both, and each program's traces name its own path
  (S29).

## What a unit depends on that is not a value

* **S8, a functor body.** Change the body of `c.sml`'s functor without
  changing its signature. Recompiles `c.sml` and `d.sml`, which applies it:
  under static interpretation a functor's clients depend on its body
  (D1).
* **S9, constructor order.** Reorder `a.sml`'s datatype's constructors.
  Recompiles every unit that builds or matches them, since tags and layouts
  change; their output is unchanged.
* **S10, a constructor's argument.** Change a constructor's argument from a
  tuple to a record of the same fields, or from one field to a tuple.
  Recompiles its users: the layout (`Rep`) is part of what they used.
* **S11, behind opaque ascription.** Change the representation of a type
  that `a.sml` hides with `:>`, keeping the signature. The IRs see through
  the realisation (`Ty.bindRealization`), so the realisation is a usage:
  every unit that compiled code against it recompiles. A unit that only
  names the type and never compiles code on its representation must not
  (to measure: if this cannot be told apart, recompiling them is the
  correct fallback).
* **S12, a signature.** Change a signature in `a.sml` that `b.sml`
  ascribes. Recompiles `b.sml`; one that only mentions the signature's
  name in a comment does not.
* **S13, fixity.** Add `infix 5 ++` to `a.sml` where `b.sml` uses `++` as
  an ordinary identifier. Recompiles `b.sml`, which now parses differently
  (and fails, reported once).
* **S14, overloading and defaults.** Change a value of `a.sml` from `int` to
  `word` where `b.sml` applies `+` to it. Recompiles `b.sml`, whose
  overloading resolved differently.
* **S15, an exception.** Change an exception's argument type. Recompiles
  its raisers and handlers; the exception stays generative: a unit
  linked twice declares two exceptions (D7).
* **S16, `open`.** `b.sml` opens `A`; add to `A` a name `b.sml` also binds
  later. Recompiles `b.sml`, though it names nothing new: what `open`
  brought in is a usage of the whole structure.

## Order, files and names

* **S17, reorder.** Swap two independent files in the build's order.
  Recompiles nothing whose basis did not change, and the output follows
  the new order (top-level effects run in the order given).
* **S18, insert.** Add a file between `b.sml` and `c.sml` that declares
  nothing the later units use. Recompiles only the new file.
* **S19, shadow.** Insert a file that redeclares a structure a later unit
  uses. Recompiles that unit, which now sees the new one.
* **S20, remove.** Remove a file nothing uses, then one something uses: the
  first compiles nothing, the second reports the unbound name.
* **S21, rename.** Rename a file without changing it. Compiles nothing but
  writes no entry under the old name that a later build could confuse: the
  key is content, and the name is only where it is shown.
* **S22, symlinks.** A source reached through a symbolic link, and a
  project directory that is one. Same entries as through the real path.
* **S23, case.** On a case-insensitive file system (Windows, `make
  test-windows`), `A.sml` and `a.sml` are one file; on Linux two. The cache
  key is the content, so neither collides.

## Configuration and identity

* **S24, flags.** Build at `-O1`, then at `-O0`, then at `-O1`. The second
  build misses everything (another configuration hash), the third hits
  everything: both configurations live side by side.
* **S25, target.** `--target=stack` against the default: another
  configuration, as S24.
* **S26, `--int-bits=64`.** Another configuration: the width changes what
  constants and overloading become.
* **S27, the compiler.** Rebuild the compiler to the same bytes: everything
  hits. Change a compiler source so that its bytecode changes: everything
  misses.
* **S28, the Basis Library.** Change a file of `lib/basis`. Units that used
  an entry it changed recompile, others do not; the frozen library is made
  again.
* **S29, relocation.** Move the project to another directory, and give the
  cache with it (`--cache-dir`). Everything hits, and the program's traces
  and error messages name the new paths: no absolute path is in a key, and
  the positions an object carries are patched at link, or relative.
* **S30, debug and release.** Two configurations in one `.rune/`; neither
  evicts the other.

## Failure and concurrency

* **S31, a compile error.** Break `b.sml`. The build fails, writes no entry
  for `b.sml` and keeps `a.sml`'s; fixing it recompiles `b.sml` and its
  dependents only.
* **S32, warnings.** A unit that warns, served from the cache, warns again
  the same way (warnings are stored with the entry and replayed), or the
  roadmap says why not.
* **S33, corruption.** Truncate an entry, flip a byte of one, write an entry
  of an older format version. Each is a miss and is rebuilt; nothing
  crashes and nothing wrong is linked.
* **S34, two compilers.** Two builds of the same project at once on one
  cache. Both finish, both outputs are right, and no entry is torn
  (entries are written by atomic rename).
* **S35, interrupted.** Kill a build while it stores an entry. The next
  build finds no partial entry.
* **S36, a read-only cache.** The installed frozen Basis library, read-only.
  Builds read it and write their own entries elsewhere.
* **S37, a full disk.** A store that fails. The build succeeds and the next
  one compiles the unit again.

## The REPL and `use`

* **S38, `use` an unchanged file.** In the REPL, `use` a file twice: the
  second links the cached object, and its top level runs again with fresh
  globals and fresh exceptions.
* **S39, `use` a changed file.** Edit the file between the two `use`s: the
  second compiles it again.
* **S40, a session's basis.** `use` a file in two sessions whose earlier
  declarations differ: two entries, each found by its own usages.

## The whole program and identity

* **S41, cold equals warm.** In `make check`: a cold and a warm `--units`
  build of every program of `tests/lang` and `tests/perf` are the same
  bytes.
* **S42, Mid from the cache.** The whole-program build from cached Mid
  equals the build from source, byte for byte, the compiler's own
  included (M7).
* **S43, five builds.** `check-cross` with the cache on: the five builds of
  the compiler still write the same bytes.

## Functors, and what the REPL echoes

What a compile reads that is not a name it looks up where it is. Found
when the scenarios above were all green
(`docs/plans/build-cache-issues.md`):

* **S49, a functor's fixity.** `c.sml`'s functor's body is parsed with the
  fixity `a.sml` gives `++`, and `a.sml` changes it. Recompiles `a.sml`,
  `c.sml` and `main.sml`, which applies the functor and names nothing of
  `a.sml`: what a functor's body found where it was declared is in its
  unit's identity. Before, `main.sml` was taken from the cache and the
  program printed the old result.
* **S50, a functor's type, shadowed.** The body uses `a.sml`'s `A.t`, which
  changes from `int` to `IntInf.int`, and a unit between the functor and
  `main.sml` declares another `A`. Recompiles `a.sml`, `c.sml` and
  `main.sml`, though at `main.sml` the name `A` is the other unit's.
* **S51, a functor's call, shadowed.** As S50, the body calling `a.sml`'s
  function and matching constructors `a.sml` reorders. The same units;
  before, `main.sml` was taken from the cache and its link failed.
* **S52, hidden code renumbered.** A body changed with functions, a
  reference and a datatype added in a `local` before what `a.sml` exports.
  Recompiles `a.sml` only (the cut-off of S2).
* **S53, a printer installed.** A file used in a session that installed a
  printer for a type of it since its entry was written echoes through the
  printer.
* **S54, the print depth.** A file whose entry was written at print depth
  0 echoes at the default depth.
* **S64, the warnings of UTS #39.** An entry keeps a unit's warnings, and
  `--no-unicode-lints` leaves out those of UTS #39 (docs/language.md,
  *Identifiers*), so an input file's key says it: a file with a name of
  mixed scripts, built under `--unicode` and then with the flag, is
  compiled again and warns of nothing; built with it again it is found
  and warns of nothing; and built without it, it is found and warns, as
  it did the first time.
* **S63, the mode a unit is read in.** A unit's key says its mode where
  it is not the default (docs/units.md, *Source modes*): a file built under
  `--unicode` and then, through the same cache, without it is compiled
  again, and once more under `--unicode=latin1`, and found under
  `--unicode` again. A build file's annotation (`unicode`, `ascii`) gives
  the mode over the command line's.
* **S62, the input files' own settings.** `--or-patterns` and
  `--default-type` hold for the input files and not the libraries, so a
  unit's key says them, not the configuration: a file built with one and
  then, through the same cache, without it is refused the second time, as
  a compile without the cache refuses it.
* **S61, a program that keeps its units' identities.** `main.sml` names
  `Runtime`, so the program keeps its units' identities; `b.sml` declares
  a functor whose body uses `A.x`, and `a.sml` gains a value while `A.x`
  stays. `b.sml` is compiled again, not taken by `A.x`'s fingerprint, and
  the program is the bytes of a build without the cache
  (docs/plans/build-cache-issues.md, issue 15).
* **S60, a datatype of many constructors.** A unit declares a datatype of
  300 constructors, and its basis (`--emit-units`) is under 100 KB: each
  constructor's information, and the list of its siblings that every one
  of them has, is written once (16 KB; 1.5 MB before, which grew with the
  square of the constructors; docs/plans/build-cache-issues.md, issue 14).
* **S65, a functor's body changed and not its signature.** `b.sml`
  applies `c.sml`'s functor, `d.sml` uses `b.sml`'s structure, and the
  body changes. `c.sml` and `b.sml` are compiled again, `b.sml` for its
  code; its basis, typed by the functor's signature (rule 54), is the same
  bytes (`--emit-units`), and `d.sml` and `main.sml` are taken from the
  cache (performance M3; [functors.md](../../docs/plans/functors.md), *A
  contradiction in M3*).
* **S66, a functor applied in another's body.** `g.sml`'s functor applies
  `c.sml`'s, whose body changes and whose signature does not. `g.sml` is
  taken from the cache: a functor's declaration takes the signatures of
  those its body applies. `main.sml`, whose copy of `g.sml`'s functor
  applies `c.sml`'s to make code, is compiled again. Then a value added to
  the functor's result changes its signature, and `g.sml` is compiled too.
  Before M3, `g.sml` was compiled again at each change.
* **S67, a cache made before the basis's form changed.** M3 put a
  functor's signature in its unit's basis (`UnitBasis.version` 6). An
  entry whose basis says version 5 is missed, not misread: `c.sml` is
  compiled again, to the basis it had, and `main.sml` is taken.
* **S68, an equality type variable.** `a.sml` gains `fun same (x : 'a) =
  0`, which `b.sml` applies to `1.5`; then `same` compares its argument
  with itself, so its type is `''a -> int`. `b.sml` is compiled again and
  the build fails, as a build without the cache does: a fingerprint says
  whether a type variable admits equality
  (docs/plans/build-cache-issues.md, issue 16). Before, `b.sml` was taken
  from the cache and the build succeeded.
* **S69, an equality attribute in a signature.** `a.sml` gains `signature
  HAS = sig type u end`, which a new `e.sml` matches with `type u =
  real`; then `type u` becomes `eqtype u`. `e.sml` is compiled again and
  the build fails: a signature's fingerprint writes each of its local
  names with its arity and equality (issue 16).
* **S72, a functor used and then declared again.** `b.sml` applies
  `a.sml`'s functor `F`, then declares its own `F`, which its functor `G`
  applies. Built once after `m.sml`, which applies `a.sml`'s `F` too, and
  once without it, `b.sml` gives the same entry: its usage of `F` is
  `a.sml`'s `F` at its start, as a usage of a value is, and its basis
  writes the same fingerprint for it (functors-units, F1). Before, the
  usage was the fingerprint of `b.sml`'s own `F` where no unit before had
  worked out `a.sml`'s, and the basis wrote `b.sml`'s own `F` always.
* **S59, one unit in two sessions.** `c.sml` uses `a.sml` and `b.sml`,
  which do not use each other. Built after them in one order and then in
  the other through one cache, `c.sml`'s entry is taken, and compiled
  again by `--verify-cache` it is the same bytes: its code does not list
  the names it uses in the order of the session's stamps
  (docs/plans/build-cache-issues.md, issue 13).
* **S58, a parallel build.** The project built with `-j 4` beside a copy
  built by one process, the same edits made to both: cold, warm, after an
  edit that only `b.sml` sees, after one that every unit after `a.sml`
  sees, after an error in `c.sml` and after mending it. Each build
  compiles the same units, prints the same on standard error -- what
  `--explain-rebuild` says, in order, and the errors -- and is the same
  bytes (docs/units.md, *Parallel builds*).
* **S57, verifying the cache in the REPL.** As S55 for a file used: its
  entry planted under the usages of another text's is taken by a session,
  which shows the old value, and a session with `RUNE_VERIFY_CACHE` set
  compiles the declaration all the same and stops the file with an error.
* **S56, the frozen Basis by another path.** The frozen library was
  compiled where its sources were `bin/../lib/basis`, and a compiler run by
  another path uses it: a unit of it that applied another file's functor --
  `word8vector.sml`, `mono_vector_fn.sml`'s -- names that file where it is
  now, as it names its own. Before, a trace through the functor's body
  named `bin/../lib/basis/mono_vector_fn.sml` wherever the program ran, and
  the program was not the bytes of a build without the cache. Found by
  `mutate.py` on the compiler's sources.
* **S55, verifying the cache.** A warm build with `--verify-cache` succeeds;
  an entry planted with usages that hold and the content of another compile
  (`bin/rune-incremental plant`) is taken by a build and found by
  `--verify-cache`, which fails.

## Edits nobody wrote

`bin/rune-incremental mutate` edits a project as a person might -- a
fixity directive's precedence or side, two constructors of a datatype
swapped, a numeral changed, a value added at top level or inside a
structure, an earlier file declared again later in the order, two files
swapped, a comment added, a file put back -- and builds it through one cache
and without one after each edit. The two must agree: both fail, or both
succeed and are the same bytes. Its projects are `tests/incremental/project`,
`tests/incremental/functors` (functors over a datatype, fixity and a type,
and a unit that declares their names again) and `compiler`, the compiler's
own sources; `--history N` replays the compiler's last N commits through one
cache. `make test-incremental` runs it briefly, with a seed of its own; a
long run is by hand.

## A large project: MLton

MLton at `5fe943391` (MLton PR #660), the first commit that Rune can build
(606 files, about 198,000 lines in the order of its `mlton-rune.txt`), is
the scenarios' large case. It is functorised throughout, so it shows what
static interpretation costs the cut-off (the roadmap's risk 3):

* **S44, cold and warm.** Build MLton's compiler cold, then warm: the time
  of each, and the warm one compiles nothing.
* **S45, a leaf.** Change the body of a function in a file nothing else
  uses (one of `main/`): one unit recompiles.
* **S46, a root.** Change the body of a function in `control/control.sml`,
  which almost every file uses: one unit recompiles (a body, S2).
* **S47, a used interface.** Add a value to the signature and structure of
  `control/control-flags.sml`: only the units that `open` it or use a
  changed entry recompile.
* **S48, a functor body.** Change the body of a functor applied in many
  places (one of `ssa/`): every applying unit recompiles. The count and
  the time are the measurement of risk 3.
