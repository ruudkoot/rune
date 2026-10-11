# Build cache issues

The cache of compiled units (M6 of
[incremental-compilation.md](incremental-compilation.md); `docs/units.md`,
*The cache*) asked of: is it as subtle as it feels, how well is it tested,
and how sure can anyone be that it is correct? The concerns are
well-founded. This lists each, with what showed it and where it stands. As
of 2026-10-10.

A hit is correct only if everything the unit's compile read is the same as
when the entry was written. The cache counts as "everything" the names the
compile looked up and the unit that bound each one (usages), together with
the identity of every unit the basis names. Most issues below are an input
that this count missed; the others are gaps in how such a miss would be
found, or what looking for them turned up. They are numbered in the order
they were found.

## Wrong results

* **1. A functor's body: what it resolved where the functor was declared.**
  Rune elaborates a functor's body again at each application, so the units
  that apply a functor depend on its body. The body's text is in the
  identity of the unit that declares it, but what the text meant there is
  not: the fixity it was parsed with, and the bindings its names found. The
  applying unit records the names the body looks up only where they are
  still the session's binding at its own place, and records the body's
  fixity never (the body is parsed once, in the declaring unit). Three
  probes, each built through the cache, edited, built again and compared
  with `--no-cache`:
  * fixity, wrong output and no error:

    ```sml
    (* y.sml *) fun op++ (a, b) = a - b
    (* a.sml *) infix 6 ++                       (* edited to: infix 8 ++ *)
    (* c.sml *) functor F () = struct val v = 10 ++ 3 * 2 end
    (* main.sml *) structure D = F ()  val () = print (Int.toString D.v ^ "\n")
    ```

    After the edit, `c.sml` is compiled again and `main.sml` is taken from
    the cache. The program prints 4; it should print 14.
  * a type the body uses, wrong output and no error: `a.sml` declares
    `structure A = struct type t = int end`, edited to `IntInf.int`;
    `c.sml`'s functor computes `1000000000 * 1000000000 * 1000000000 *
    1000000000 : A.t` and handles `Overflow`; a unit between `c.sml` and
    `main.sml` declares another `A`. `main.sml` is taken from the cache and
    prints `false`; it should print `true`. Without the unit that declares
    another `A`, it is correct.
  * the same with a call into the changed unit (`A.mk`): `main.sml` is taken
    from the cache and the link fails (issue 4).

  Status: fixed. A unit that declares a functor writes into its basis,
  beside its functors, the identity of the unit that bound each name its
  compile used, fixity included, so a change in any of them is a new
  identity, and every unit that applies one of its functors misses
  (`docs/units.md`, *The cache*). The probes are scenarios S49 to S51. It
  costs precision, not correctness: a unit that declares a functor and
  other things changes identity where anything it used changed, not only
  what its functors' bodies used.

* **2. Overloading registered away from its type.** Resolving an
  overloaded operator or literal at a type reads the registration that some
  unit's `_overload` made, which is not a name lookup.
  `lib/basis/widestring.sml` registers string literals for a type
  `widechar.sml` declares, so a unit writing `"ab"` at
  `WideCharVector.vector` depended on `widestring.sml` without naming it.
  Status: fixed. A resolution is a usage `o NAME`, bound to the registering
  unit (scenario S28o). Only the Basis can use `_overload`, so this could
  only bite when the Basis Library's sources changed under a kept cache.

* **3. The REPL's echo of a used file.** The code that prints what a `use`d
  declaration binds is compiled with the declaration and cached with it. It
  is shaped by two things that are in no key and no usage:
  * the printers installed: a session that installs a printer for `t` with
    `Compiler.addPrettyPrinter` and then uses a file that binds `val v = T 3`
    shows `val v = T 3 : t` when the file's entry was written by an earlier
    session without the printer, and `val v = <t 3> : t` without the cache;
  * the print depth: after a session that used the file with
    `RuneCompiler.printDepth := 0`, a session at the default depth shows
    nothing for it.

  What the program computes is right; what the REPL shows is not. Status:
  fixed. Both decisions are usages now, `echo on` and `p KEY`, which hold
  where the REPL decides the same when the entry is looked up (scenarios
  S53 and S54).

* **9. Paths in the code of a unit from the cache.** Found by the tester
  of issue 5 on the compiler's own sources: a unit's code names the source
  files its positions are in, which for a functor's body applied in it is
  the functor's file. A unit taken from the cache had its own file named
  where it is now, and the functors' files where they were when it was
  compiled. The frozen Basis is compiled where its sources are
  `bin/../lib/basis`, so a program built by a compiler run by any other
  path -- an installed one, or one called by its full path -- had traces
  through `mono_vector_fn.sml`, `streamio_fn.sml` and the other functor
  files of the library name `bin/../lib/basis/...` wherever it ran, and was
  not the bytes a build without the cache gives. The computation was right;
  the positions were not. Status: fixed. An entry keeps, for each file its
  code names, the unit it is the source of, and a unit taken from the cache
  names each where that unit's source is now (scenario S56).

## A hit that cannot link

* **4. An entry whose code names a unit no longer there.** An entry is
  checked by its usages and its basis, not by the units its code names.
  Where the usages miss something (issue 1), the code can name a unit
  identity that the session no longer has, and the build stops at link with
  `internal compiler error: link: a function is exported by no unit before`.
  The failed build writes nothing, so every later build fails the same way
  until the cache is removed. Status: fixed. An entry whose code names an
  identity the session does not have is a miss (S51 was this case before
  issue 1's fix).

## How little is tested

* **5. Edits are tested by hand-written scenarios on one small project.**
  What is tested well is the case with no edit: `check-units` builds every
  program cold, through a cache and from it, and wants the same bytes, and
  `check-cross` does the same for the compiler's five builds (S41, S43). The
  case that matters, an edit followed by a warm build, is tested by about
  twenty scenarios on one project of five files (`tests/incremental`), and
  three of the REPL. They were written with the code, and share its blind
  spots: issues 1 to 3 were in none of them. Of
  [the scenario list](../../tests/incremental/SCENARIOS.md), S4, S7, S9 to
  S12, S14 to S16, S20 to S23, S25 to S27, S30, S32, S35 and S37 are run by
  no runner, nor S44 to S48 on MLton. S32 (warnings given again) is built
  and untested.

  Status: done, but for S27 and S37, which no runner can make (below). The
  probes are scenarios (S49 to S56). Beside them,
  `tests/incremental/mutate.py` edits projects mechanically -- fixity
  directives, constructors swapped, numerals, values added at top level and
  inside structures, a file declared again later, files swapped, comments,
  files put back -- and replays the compiler's own history commit by commit
  through one cache; after every step the program must be the same bytes
  as with `--no-cache`, which is exact and needs no expectation written by
  hand. Its first runs (2026-10-10): 1,000 edits of `tests/incremental/
  project` and `tests/incremental/functors` (600 at the default level, 400
  at `-O2`), 30 of the compiler's sources, and the 25 of the compiler's last
  60 commits that hold their generated files. The history found issue 9 at
  its first commit; after its fix, none of them disagrees. `make
  test-incremental` runs it for 30 edits of each small project.

  Since then (2026-10-10, later):

  * **The scenarios a runner can make are run**: S1 to S26, S28 to S36,
    S40 and S49 to S61 (`tests/incremental/run.sh`, `make
    test-incremental`); S27 and S37 are not, and SCENARIOS.md says why.
  * **The tester edits more**: type abbreviations and exceptions'
    arguments, in other words or in meaning, files removed and renamed;
    with `--basis` it edits files of the Basis Library under a kept cache,
    and with `--flags` builds at another level. A round with the
    compiler of issue 15's fix: 600 edits of the two small projects (692
    builds), 200 at `-O2` (250), 100 with `List` and `Option` edited too
    (120), and the compiler's last 10 commits replayed through one cache:
    1,072 builds, none disagreeing with `--no-cache`, and 645 units taken
    from the cache across a unit that changed.
  * **MLton** (S44 to S48, `tests/incremental/mlton.sh`): its 606 files
    built in units cold, warm, after a leaf, a root, an interface and a
    functor's body changed, and from the warm cache as one program; the
    last warm build is the bytes of a build without the cache. It took
    issue 14 to build at all, and found issue 15.
  * **HOL4** built through `src/boss` on Rune from a warm cache with
    `RUNE_VERIFY_CACHE=1`, which compiles every unit the cache has and
    compares: after issue 13, no entry differs. With the bases of issue 14
    too: the build from an empty cache took 1,075 s of processor (13,776
    entries, 200 MB), the verified one 1,445 s, on a machine other work
    shared.

* **6. No way to check a warm build.** A user who doubts a build had only
  `--no-cache` and `cmp`. Status: done. `--verify-cache` compiles each unit
  the cache has too, and fails where the cache's entry is not the same bytes
  as what compiling it gives. S55 plants an entry whose usages hold and
  whose content is another compile's (`tests/incremental/plant.py`): a
  build takes it and prints the old result, and `--verify-cache` finds it.
  The REPL's `use`, which takes no flags, verifies where `RUNE_VERIFY_CACHE`
  is set (S57).

* **10. `make check` never used the frozen Basis.** `make check` built the
  compiler and not `lib/cache`, so in a clean tree -- every snapshot the
  checks ran on -- each compile compiled the Basis Library's units itself,
  and nothing the frozen Basis does was tested there; issue 9 was out of
  their reach. Where it was built, the checks run the compiler as
  `bin/rune`, whose paths are those the frozen Basis was made with. Status:
  fixed: `make test-incremental` builds `lib/cache` first, and its runner
  calls the compiler by its full path.

## Smaller

* **7. The content hash is weak.** `Pickle.hash` is four polynomial hashes
  of 24 bits each, chosen for speed (hashing was a third of a warm build).
  Accidental collisions are not a practical concern; one made on purpose
  would be easy, which matters only for a cache shared between people who
  do not trust each other.

* **8. The next step adds more of the same.** M6's third part, step 3,
  loads an entry across a unit that changed, by mapping each name of the
  old unit to the same path in the new one. That is the same kind of
  reasoning about what a compile read, with more ways to be wrong. It
  waited for the tester of issue 5, and was built on 2026-10-10
  (`incremental-compilation.md`, *M6, the third part as built*). Building
  it found one more hole before it could open: a value's fingerprint did
  not say which value, so a later unit's `A.x` of the same type would have
  held a usage of the first's. The tester's runs since -- small projects,
  Basis edits, `-O2` -- remap about one unit in three builds and none
  disagrees with `--no-cache`.

* **11. An entry's code read and written again is other bytes.** Reading
  a unit's code and writing it again lists the units it names in another
  order. Linking does not care, and `--verify-cache` compares the bytes as
  read (it first reported two units of the Basis wrongly because it did
  not), but a unit's code is not one representation. Issue 13 is the same
  list's order across two sessions.

* **12. Fingerprints grew with what a type is made of.** Step 3's
  fingerprint of a type name held the text of its definition, which named
  the types it is made of by their text in turn: a unit of the compiler
  that names `Ast` had megabytes of usages, and working them out was three
  quarters of compiling the compiler in units (24 s; 4.5 s now). Not a
  wrong result, but the cost of a cache is part of whether it is used. A
  type name's fingerprint is now its anchor and the hash of its
  definition; found measuring M11.

* **13. A unit compiled in two sessions was two sets of bytes.** Its
  code listed the names it uses of other units in the order of the
  stamps the session gave those names, and a session gives them as it
  loads the units, so two sessions that loaded the same units in two
  orders wrote the same unit two ways. Linking took either alike, so no
  program was wrong, but `--verify-cache` failed on a correct entry, and
  an entry was not one representation. Found verifying HOL4's build
  (`RUNE_VERIFY_CACHE=1`, the scripts' sessions loading HOL's files in
  their own orders); the code now lists them by their places in it, and
  S59 builds a unit after `a b` and after `b a` through one cache and
  verifies it. `RUNE_VERIFY_DUMP` writes both sides of a failure, which is
  how this one was read.

* **14. A unit's basis grew with the square of a datatype's
  constructors.** MLton's compiler could not be built in units: past its
  500th unit the heap passed the 5 GB that its whole-program compile fits
  in, cold and warm, so S44 to S48 never finished. Measured after each
  unit (`--pass-stats` with `RUNE_MEM`), units of signatures took four
  times in the session what they took elaborated, read back from their
  basis, and some took far more (`dot.sig`: 34 MB from a 4.7 MB basis).
  Each constructor's information names every constructor of its datatype
  (`siblings`), and the basis wrote that list again for each of them, and
  for each place a constructor appears -- an environment, its datatype's
  constructors, the elaborator's table of them -- so a datatype of n
  constructors took about n * n, and was read back as that many separate
  lists; MLton's `DotColor` has hundreds. Types were written whole at each
  use too. A basis now writes a constructor's information, its list of
  siblings, and a type once each, and refers to them after by number,
  which the reader takes for the same object. After 400 of MLton's units
  the bases are 13.9 MB, not 152 MB, and the heap holds 166 MB, not 1.1 GB,
  less than the whole-program compile's 413 MB. The driver no longer keeps
  every unit's basis until the end either; only `--emit-units` needs them.
  S60 builds a datatype of 300 constructors and wants its basis under 100
  KB (16 KB now; 1.5 MB before). With the fix, MLton's 606 files build in
  units and S44 to S48 run (issue 5).

* **15. An entry taken across a unit that changed keeps the old unit's
  identity.** When a unit's usages hold by fingerprint alone -- the unit
  that bound a name changed, and the name means what it did -- its entry
  is taken, and the units its code names are remapped to the new one
  (M6's third part). Its basis still names the old unit: in the binders a
  functor's unit keeps (issue 1), and in the units its types come from. So
  the unit's own identity, the hash of its basis, is not the one compiling
  it gives, and depends on what the cache saw before. Linking does not use
  identities, and a program without a units section is the same bytes; but
  `--verify-cache` reported such an entry as wrong, and a program that
  keeps its units' identities (one that links `runtime.sml` or
  `dynamic.sml`, docs/units.md, *Dynamic modules*) was other bytes than a
  build without the cache. Such a program was meant never to take an entry
  across a unit that changed; that was enforced only where something was
  remapped, and a functor's unit, whose code names nothing, slipped
  through: MLton's `word-size.fun` under S47, whose `Control` had changed.
  Status: partly fixed. Such a program takes exact entries only (S61), and
  `--verify-cache` compiles an entry that holds by fingerprint again rather
  than compare it. Left: giving such an entry the identity a fresh compile
  would -- its basis written again against the new units when it is
  loaded -- so that `--verify-cache` can compare it too.
