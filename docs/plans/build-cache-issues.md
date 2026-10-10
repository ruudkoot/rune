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

  Status: partly done. The probes are scenarios (S49 to S56). Beside them,
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

  Left: the tester changes no type abbreviation or exception argument, and
  removes and renames no file; the scenarios above that no runner runs are
  still not run; MLton (S44 to S48) is not tried; nothing edits the Basis
  Library under a kept cache but S28.

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
  not), but a unit's code is not one representation.

* **12. Fingerprints grew with what a type is made of.** Step 3's
  fingerprint of a type name held the text of its definition, which named
  the types it is made of by their text in turn: a unit of the compiler
  that names `Ast` had megabytes of usages, and working them out was three
  quarters of compiling the compiler in units (24 s; 4.5 s now). Not a
  wrong result, but the cost of a cache is part of whether it is used. A
  type name's fingerprint is now its anchor and the hash of its
  definition; found measuring M11.
