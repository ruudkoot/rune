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
they were found. Issues 16 to 24 were found by the functors-units roadmap
(`functors-units.md`, 2026-10-21 to 2026-10-25), which also found the bugs
outside the cache that the last section lists.

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

* **16. Fingerprints without equality.** Found by the functors-units
  roadmap (E9, 2026-10-21). A fingerprint wrote a type variable as `'i`
  whether or not it admits equality, and a name local to a signature as
  its place among them, without its arity or its equality. So `'a -> int`
  and `''a -> int` were one fingerprint, and so were `type t`, `eqtype t`
  and `type 'a t` in a signature where no value names `t`. Fourteen probes
  edited one of these in `a.sml` and built `b.sml` through the cache; in
  seven, the warm build took `b.sml` from the cache where a build without
  it refused the program, or the other way round:
  * `fun f (x : 'a) = 0` edited to `fun f x = if x = x then 0 else 1`,
    and `b.sml` applies `f` to `1.5`: the warm build succeeds; with a
    closure instead of `1.5`, the program runs `=` on a function value
    and prints 0;
  * the same inside a structure; the edit the other way, which refuses a
    program that holds;
  * a signature's `type t` edited to `eqtype t` or to `type 'a t`, and
    `b.sml` matches it with `type t = real` or `type t = int`;
  * a functor's parameter edited so, and `b.sml` applies it in another
    functor's body.

  Status: fixed (functors-units M2). A type variable's fingerprint says
  whether it admits equality, and a signature's or a functor's local names
  are written each with its arity and equality (`UnitBasis.version` 8).
  The probes are scenarios S68 (a value) and S69 (a signature).

* **21. The REPL kept a functor's old body through the cache.** Found by
  the functors-units roadmap (M6b, 2026-10-25), with functors copied (the
  default until its M7). In one session, through the cache:

  ```sml
  (* twice.sml *) functor Twice (X : sig val step : int -> int end) =
                    struct fun go x = X.step (X.step x) end
  (* apply.sml *) structure A = Twice (struct fun step n = n * 3 end)  val a = A.go 5
  ```

  `use` both; edit the body to apply `X.step` three times; `use` both
  again. `a` was 45; it should be 135. `apply.sml`'s entry was taken: its
  usage of `Twice` held by the signature's fingerprint, and its usage of
  the body (`funat`) held because the unit of the old body was still in
  the session -- a REPL keeps every unit it loaded, the old one shadowed
  by the new, where a batch build has only the new. Status: fixed by 23's
  rule (S75).

* **22. The REPL gave a file used again its first load's identity.**
  Found by the functors-units roadmap (M6b, 2026-10-25); with or without
  the cache, in every mode. With `counter.sml` holding `structure Counter
  = struct val n = ref 0 end`, `use "counter.sml"; structure Old =
  Counter; use "counter.sml"; Old.n := 10` set the second load's
  `Counter.n` too: `!Counter.n` was 10, where 0 is right. The same text
  against the same units has the same identity, so the second load's
  globals were registered under the first's, and the runtime's table of
  what units export, keyed by identity, gave them to code that named the
  first's -- `Old.n`, compiled after the second `use`. Not the cache's,
  but of the identities it keys on. Status: fixed. A unit loaded where a
  unit of its identity is loaded already is loaded and linked under its
  identity with `~2` after it (`~3`, ...), its code's own keys renamed for
  linking only; its entry keeps its basis's identity (`docs/units.md`).
  Scenarios S38 (through the cache) and S74 (compiled again, the cache
  verified).

* **23. The REPL linked a unit from the cache to the first of two loads.**
  Found fixing 22 (2026-10-25). `use "counter.sml"; use "user.sml"`, where
  `user.sml` is `fun bump () = Counter.n := !Counter.n + 1`; add a value to
  `counter.sml`; `use` both again; `bump ()`. Through the cache it
  incremented the first load's `Counter`: `!Counter.n` was 0, where 1 is
  right. `user.sml`'s usage of `Counter` held by fingerprint -- the new
  unit has the old one's name, so a structure the same is the same
  fingerprint -- and the entry's code named the first `counter.sml`'s
  globals, which no remapping takes over while that unit is in the
  session. With `counter.sml` unedited, 22 made it right by accident, and
  22's fix alone would have made it wrong. Status: fixed. A usage holds by
  its fingerprint only where the unit that bound the name then is not in
  the session (`docs/units.md`, *Fingerprints*); where it is, the entry is
  a miss and the unit is compiled. A batch build never has two units of
  one name, so this changes nothing there; it fixes 21 too. Scenario S75.

* **24. The REPL named a declaration's printer by the session's count.**
  Found by the functors-units roadmap (M7, 2026-10-25), building HOL4
  through the cache with `RUNE_VERIFY_CACHE=1`, which stopped at
  `regexpMatch.sml#0`. The code that prints what a declaration binds is
  compiled with it (issue 3), from a source named `<echo k>`, k the count
  of declarations the session had compiled, and the code keeps that name:
  an entry written where the session had compiled k declarations was not
  the bytes a compile at another count gives, so `--verify-cache`
  refused a correct entry. What the program computed was right. Status:
  fixed; every printer's source is `<echo>` (S76).

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

* **17. A functor's or a signature's usage was fingerprinted after the
  unit's own declarations.** Found by the functors-units roadmap (E5 and
  E9, 2026-10-21). A value's usage is fingerprinted as the name was at the
  unit's start; a functor's and a signature's were fingerprinted after the
  unit was elaborated, from tables that then hold the unit's own. So a
  unit that applies an earlier unit's `F` and then declares its own `F`
  recorded the earlier unit's identity with its own `F`'s fingerprint, and
  its basis wrote its own `F`'s. Not a wrong hit -- the entry names the
  earlier functor by its place, and a remap refuses it -- but a miss where
  nothing changed, and an entry that depended on what the session had
  worked out before. Status: fixed (functors-units M2, F1): every usage is
  fingerprinted at the unit's start (S72).

* **18. A recursive group's fingerprint depended on which member came
  first.** Found by the functors-units roadmap (E5). Of `datatype t = X of
  u | Y and u = Z of t | W`, `u`'s fingerprint was `u`'s alone where the
  session worked out `u` first, and `u`'s with `t` in progress where it
  worked out `t` first, so whether a unit that names `A.u` was compiled
  again across another change to `A`'s unit depended on the session.
  Misses, never a wrong hit. Status: fixed (functors-units M4): a group's
  fingerprint is one value, of its strongly connected component, its
  members named by their anchors (S73).

* **19. The link was quadratic.** Found by the functors-units roadmap (E3):
  `StringMap.numItems` for each key, and an insertion sort. MLton's link in
  units took 15.7 s, and 1.26 s with the fix, for the same bytes. Status:
  fixed (functors-units M2).

* **20. A warm build hashed every basis twice.** Found by the
  functors-units roadmap (E5): a unit's identity was hashed when its basis
  was written and again when it was loaded, 481.5 MB in a warm build of
  MLton's 606 files with no edit, 220 MB of it the second time. Status:
  fixed (functors-units M2, F2): the identity is kept with the entry and
  given to the load.

## Found on the way, outside the cache

The functors-units roadmap (2026-10-21 to 2026-10-25) found these while it
found 16 to 23. They are not the cache's, and are kept here with them.

**In Rune:**

* **A long vector made through a list as deep.** `CharVector.tabulate` and
  `Word8Vector.tabulate` made a vector by `implode (List.tabulate ...)`,
  which recursed once for each element, and `CharArraySlice.vector` and
  `Word8ArraySlice.vector` go through them: making a string of a 10 MB
  buffer stopped the compiler with "stack overflow" (the VM's stack is
  bounded, `rt.stack`) on MLton's sources in units. Status: fixed; a
  vector of more than 1,024 elements is made in place
  (`tests/lang/basis.charvector_long`). The list functions that recurse
  once for each element -- `@`, `map`, `foldr`, `List.tabulate`,
  `ListPair`'s and what is made of them -- still stop past some ten
  million elements: `performance/basis.md` says what was tried and what
  might do.
* **`IntInf`'s SML arithmetic dropped a limb of a sum.** Adding two
  magnitudes took the first for the longer by its bytes, and walked its
  limbs alone; a limb is 30 bits, not a whole number of bytes, so two
  magnitudes of as many bytes may be of two lengths in limbs, and the
  other's top limb was lost: `(2^210 - 1) + 2^210` gave `2^210 - 1`
  plus nothing above it, while `2^210 + (2^210 - 1)` was right. GMP's
  arithmetic, the register VM's default, was right; the stack VM's and
  `--intinf=sml`'s were not, and every `pidigits` benchmark printed wrong
  digits under them (found running the benchmark catalogue under the
  flag, wrong with it off too). Neither the IntInf suite's 230 vectors,
  mostly small, nor its backends' comparisons had such a pair. Status:
  fixed; the longer in limbs is taken (`tests/lang/basis.intinf_add_limbs`).
* **A unit's provenance read by its width.** Three readers of the hash in
  a unit's provenance -- `Link.sourceOf`, the runtime's
  `unit_source_current` and the Basis's `linkedUnitSources` -- took it to
  be the 24 digits `Pickle.hash` gave, and broke when M4 changed the hash
  (S61 failed). Status: fixed; they read to the first `:`.
* **Errors printed `Int64.int` as `_int64`**, and `Word64.word` as
  `_word64` (E1). Status: fixed (functors-units M3).
* **Applications still typed by their copies** (E1): in four corners Rune
  accepted ten programs the Definition rejects and rejected two it
  accepts. Status: one corner refused (functors-units M3), the other three
  pinned by tests until M7 closes them.
* **Rune's int64 VM has a 64-bit `Word` whatever the bytecode**, so a
  program that relies on `Word`'s 63 bits computes otherwise there, and
  **`lib/random`'s `hashString` differs on `smlnj32`** (E6). Status: open.

**In the prototype of functors compiled once** (`--functors=functions`,
`lib/compiler/core/expand.sml`; on the branch, behind the flag, until the
roadmap's M7 makes it the only way):

* Found by compiling MLton's and ML-Yacc's sources, the benchmarks and the
  examples (M6, M6b), each now a case of
  `tests/lang/mod.functor.functions_expand`:
  * a typed pattern's lambda bound to a polymorphic value (MLton's
    `IntSize.memoize`);
  * a `local` block that applies functors inside one declaration (ML-Yacc);
  * an open constructor bound to a polymorphic variable
    (`ssa2-to-rssa.fun`, `Prim.Word_equal ws`), which only `--lint` saw;
  * a hidden datatype of a mutually recursive group copied once for each
    application while the group's visible type was one instance that two
    expansions shared, so code built values with one copy and took them
    apart with the other (`fxp`; only `--lint` saw it, the two copies'
    layouts being the same).

  Status: fixed.
* Found by an independent review of `expand.sml` (2026-10-25):
  1. a miscompile no lint sees: a program's own `if n = 0` at a type a
     parameter leaves open was taken, by its shape, for a descriptor's test
     and folded (`5 0 200 100` printed where `1 0 200 100` is right);
  2. a miscompile that stops the VM: a descriptor worked out from the
     layout at elaboration, while the expansion laid the instance out
     anew, so a constructor built boxed was taken apart flat ("constructor
     field 1 out of range");
  3. a lint failure of `fxp`'s kind: an instance whose constructors name
     only an inner hidden datatype was taken to be independent of the
     substitution, and copied for each expansion;
  4. traces: a copy had no `functor F` frame at `-O1` and `-O2` where it
     had one at `-O0`, tail calls where the source has none, and was named
     `F.boom` where `A.boom` is right (check-levels' rule);
  5. a crash on a contrived program: the expansion knew its marker by a
     type's shape, and `val weird : (unit * unit) * (unit * unit) =
     RuneDynamic.cast ()` stopped it ("expand: a marker's pair");
  6. MidLint's rule for casts: a valid cast through `unit` refused, and
     gaps: only a variable bound directly to a cast to `unit` was checked,
     nothing between two types neither of which is `unit`, and type
     variables were skipped;
  7. two of no effect today: stamps compared after they were renumbered,
     and a free variable's copy.

  Status: fixed, each with a test, before M7.
* Found by the generator of functor programs (`tests/runner/functorgen.sml`,
  2026-10-25: 6,688 programs, each in up to seven modes), each a failure of
  `--lint` in a program that printed right:
  * a functor applied to an earlier unit's structure, in units, under the
    flag: the lint after the expansion fails ("cast to unit from unit ->
    unit, is cast back to int -> int"), in 37% of the programs generated;
  * a functor whose body seals its parameter (`structure I :> S = X`) and
    declares a datatype over `I.t`, applied in another functor's body that
    two applications make code of, whole and in units: the expansion makes
    one copy of the datatype for both ("the argument of a constructor has
    type int * int where real is wanted").

  Status: fixed before M7.
* Found landing it as the only way (M7): a marked functor's Mid in a
  basis named its positions by the path its source was given by, so a
  Basis unit from the shipped cache differed from one compiled again
  (S61); and the expansion aliased a value to a global a function sets
  again, a dynamic module's slot, so `val kept = L.version` read the new
  module's after `Dynamic.reload`. Status: fixed.
* Found by the same generator, and not the prototype's: with the flag off,
  from `-O1`, a function that returns a datatype's constructors in globals
  (Lower's `results`) shares a global between constructors -- `datatype t =
  C0 of int | C1 of string * int` keeps C0's int and C1's string in one --
  and the variable read from it took the representation of the first
  binding Lower met, C1's pointer, where C0's branch adds it as an int:
  Lower's lint refused it, and the register code told the JIT the register
  holds a pointer. Status: fixed; such a variable holds anything
  (`tests/lang/dec.datatype_int-payload-lint`).

**In other compilers** (E1 and E6; `functors-units.md`, *Found while
writing this roadmap*, has each):

* SML/NJ 110.99.9 on amd64 stops on a word constant of 2^30 or more that a
  register spill moves ("MLRisc bug: AMD64MCEmitter: MOVABSQ
  unimplemented"; `docs/bugreport/smlnj/MLRISC/movabsq-spilled`);
* `smlnj32`'s `Word64` is wrong: `fromInt`, shifts and `+`;
* MLKit 4.7.25 fails with an internal error on a functor whose body has
  `val r = ref []`, applied after a `;`;
* SML/NJ 110.99.9 accepts equality through a functor's opaquely ascribed
  result.
