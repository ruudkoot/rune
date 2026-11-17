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
outside the cache that the last section lists. Issues 25 on were found
under rhc, the Haskell 98 compiler that keeps its units in the same store
(`docs/units.md`, *rhc's units*; the haskell98 roadmap, 2026-11-16): by
mapping each issue above onto rhc's units and probing where one could have
an analogue, and by a tester of mechanical edits held to a build without
the store, as issue 5's is.

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
  what its functors' bodies used. Since functors-units' M7 (2026-10-25)
  the cause is gone: a functor is compiled once, in the unit that declares
  it, and a unit that applies it calls its function, so what the body's
  names meant and the fixity it was parsed with are the declaring unit's
  alone. The binders a functor's unit wrote into its basis went with the
  cause, and so did the usage `funat`, by which an applying unit used the
  unit a copy's code came from. S49 to S51 now compile `a.sml` and `c.sml`,
  and `main.sml` calls the function `c.sml` made again; a functor marked to
  be inlined, whose body an applying unit copies, makes that unit use its
  function's Mid (`inl F`, docs/units.md, *The cache*).

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
  names each where that unit's source is now (scenario S56). Since
  functors-units' M7 (2026-10-25) a unit holds a copy of another unit's
  functor only where the functor is marked to be inlined, as the Basis
  Library's `mono_vector_fn.sml` and `streamio_fn.sml` are; the paths stay
  for those copies, and a marked functor's Mid names its positions by its
  unit's own source, not by the path its compile was given (S61).

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
  verified). A file given twice in a batch build was the same bug, printing
  `10 10` where a whole compile prints `0 10` (build-system E16). Fixed by a
  rank in the unit's logical name, `a.sml#2` (build-system M3, S91).

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
  a miss and the unit is compiled. A batch build has no two units of one
  name, since a rank tells them apart (build-system M3; before it, a file
  given twice was two), so this changes nothing there; it fixes 21 too.
  Scenario S75.

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

* **25. A class's defaults: what an instance in another module is made
  of.** Found under rhc (the haskell98 roadmap, 2026-11-16), mapping issue
  1: a functor's body resolved where it was declared has, in Haskell, an
  analogue in what a class's declaration gives an instance elsewhere. An
  instance that leaves a method out is made of the class's default where
  the class has one (4.3.2), `%dm:` in Core, and of a call of `error`
  where it has none; the instance's module reads that from the class's
  unit's desugaring, which no usage records, and the class's fingerprint
  held its methods and their types, not which have a default. Two probes,
  each built through the store, edited, built again and compared with
  `--no-store`:

  ```haskell
  -- C.hs
  module C where
  class Describe a where
    describe :: a -> String
    describe _ = "default"          -- the edit takes this line away
    name :: a -> String
  -- I.hs
  module I where
  import C
  data T = T
  instance Describe T where name _ = "T"
  -- Main.hs
  import C
  import I
  main = putStrLn (name T) >> putStrLn (describe T)
  ```

  * the default taken away: I is taken, its dictionary naming `%dm:` that C
    no longer makes, and the link fails ("the variable %dm:C.describe is
    not bound"), at every build after it until the store is removed;
  * the default given (the edit the other way): I is taken, and the
    program ends in "no method describe in the instance Describe T"; it
    should print `default`.

  Status: fixed. A class says which of its methods have a default
  (`HsClasses.class`'s `defaults`, in its interface, HsIface 4), and its
  fingerprint holds them, so that an instance of another unit is made
  again where one comes or goes. The probes are `hs/units/holes/class-default`
  and `hs/iface/fingerprints/default`, which the rhc before the fix fails;
  the mutant `HU12` takes the defaults out of the fingerprint.

* **26. An instance in scope along a chain of imports.** Found under rhc
  (the haskell98 roadmap, 2026-11-16), mapping issue 2: what an overloaded
  name resolves to is read away from its type, and in Haskell an instance
  is in scope in a module only where a chain of imports leads from it to
  the module that declares the instance (5.4). The checker found the
  instance (a usage, `instance C T`, E13's H2) and then asked whether the
  module's imports reach the instance's, which is a read of other modules'
  import lists, and no usage. So an import taken from, or given to, a
  module on the way moved what a module that imports neither means. Three
  probes:

  ```haskell
  -- N.hs: newtype N = N Integer, with Eq and Show
  -- Orphan.hs: import N; instance Num N where fromInteger k = N (k * 10) ...
  -- Mid.hs
  module Mid where
  import Orphan ()                  -- the edit takes this line away
  -- A.hs
  module A where
  import N
  import Mid
  default (N, Integer)
  a = show (1 + 2)
  -- Main.hs
  import Orphan
  import A
  main = putStrLn a
  ```

  * the import taken away: in A, `Num N` is out of scope and the default
    is Integer; A is taken, and the program prints `N30`, where `3` is
    right, with no error (since the fix of the default's check, found on
    the way below, A's `default (N, Integer)` is itself refused where `Num
    N` is out of scope; `hs/units/holes/instance-chain` moves `Read N`
    instead, which `read "5" + 1` asks, and prints `N15` or `6`);
  * the import given (the other way): the program prints `3`, where `N30`
    is right;
  * an instance of `Show` reached only through Mid, and A's `show T`: the
    import taken away, the build through the store takes A and succeeds,
    where a build without it refuses the program ("the instance Orphan
    declares is not in scope in A").

  Status: fixed. Whether a chain of imports reaches the module that
  declares an instance the checker finds is a usage of its own,
  `HsUsage.Reaches`, answered from the program's graph (`RhcGraph.reaches`)
  as every usage is (H3). The probes are `hs/units/holes/instance-chain`
  and `instance-chain-refused`, which the rhc before the fix fails; the
  mutant `HU13` drops the read.

* **27. A literate file read as a plain one.** Found under rhc (the
  haskell98 roadmap, 2026-11-16), reading what a key holds against the
  tester's edit that makes a module literate, and probing a module renamed
  to `.lhs`. A unit's key was its name and its members' texts, and
  a module's header was kept by its text's hash; neither said how the text
  is read, and the same bytes read literate are another program (or
  none). Probe:

  ```haskell
  -- A.hs, renamed to A.lhs and nothing else
  module A where
  a :: String
  a = "plain"
  {-
  \begin{code}
  module A where
  a :: String
  a = "literate"
  \end{code}
  -}
  ```

  Read plain, `a` is `"plain"`; read literate, the code is what
  `\begin{code}` encloses, and `a` is `"literate"`. After the rename, A
  was taken and the program printed `plain`, where `literate` is right; a
  text with nothing literate in it, renamed, was taken where it is no
  module A at all and the build without the store refuses the program.
  Status: fixed. A unit's key says of each member whether it is literate,
  and so does the way a header is kept (`docs/units.md`, *rhc's units*);
  `--dotted-names`, by which a text is read otherwise too, is in the
  units' configuration. The probe is `hs/units/holes/literate` (the
  runner's holes now take `.lhs` files and a step's `rm`), which the rhc
  before the fix fails; the mutants `HU14` and `HU15` drop the key's and
  the header's. `HU15` was not caught until the case's last steps
  (2026-11-17): a text whose two readings have one header passes with the
  header of either, and the last steps' literate reading imports a module
  the plain reading does not.

* **29. The link's memo across levels and instruction sets.** Found under
  rhc (the haskell98 roadmap, 2026-11-16), probing the link memo, whose
  entries must not be shared across levels and instruction sets as a
  unit's are. The memo's configuration names the level and the
  instruction set, but it was made when the compile began, before the
  options that set them were read, so every compile had the default's.
  Probe: a program of two modules through one store at `-O2`, then `-O0`,
  `-O1`, `-O2 --target=stack`: `-O1` took `-O0`'s program, and
  `--target=stack` took the register machine's bytecode, which the stack
  machine cannot run; `-O2 --strictness=off` took `-O2`'s, an option the
  memo's configuration does not hold, which the memo left out for
  `--eta=` and `--fuel=` and not for it. The tester's first run, on the
  rhc before the fix, found it at every change of level or machine: 61 of
  732 builds took a link of another configuration. Status: fixed; the
  link's configuration is made where the link is looked up, and
  `--strictness=` leaves the memo out (`hs/units/memo`).

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

* **28. A damaged part of an entry, read after the entry is taken.** Found
  under rhc (the haskell98 roadmap, 2026-11-16), flipping bytes of a
  store's entries. The store holds an entry's head to its hash before the
  entry is taken, and each section to its own only as its client reads it
  (`UnitStore`); Rune's client reads every section it needs inside the
  lookup, so a damaged one is a miss. rhc reads a unit's parts long after
  it takes the unit -- its fingerprints at once, its desugaring's where a
  unit after it is made, its Core's declarations where the link reaches
  them -- and a damaged one raised the store's `Damaged` out of the
  compile: `runevm: uncaught exception Damaged`, at every build after it
  until the entry was removed by hand. Probe: `tests/hs/units/drive`
  through a store, one byte flipped at a quarter, a half and three
  quarters of the link's entry or of Main's, and a warm build. Status:
  fixed. An entry of the program's store is held whole before it is
  taken, every part read once (a part a compile reads anyway is not read
  again), and one that does not hold is no entry, and is removed; the
  parts of a layer's entry, which rhc never writes, are read as they are
  asked for, and one that does not hold stops the compile with an error
  naming the layer, or is not taken where it is read at once (a unit's
  fingerprints, the link's bytecode). `hs/units/damaged` flips a byte in
  the head, the middle and the end of each entry, of the store and of a
  layer.

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

* **32. No way to check rhc's warm build.** Found under rhc (the haskell98
  roadmap, 2026-11-16), mapping issue 6: rhc had `--no-store` and `cmp`.
  Status: done. `--verify-store` takes nothing from the store: it makes
  every unit and the link, and holds each entry that stands for one of
  them to what making it gave -- its usages, its interface and every part,
  HsLint's where both have one -- and the link's bytecode to the memo's,
  failing where one is not. `hs/units/verify` plants an entry whose usages
  hold and whose content is another compile's: a compile takes it and
  prints the old program, and `--verify-store` refuses it, naming the
  unit. Run on the stores the tester left, it found issues 30 and 31.

* **33. rhc's units tested by hand-written cases.** Found under rhc (the
  haskell98 roadmap, 2026-11-16), mapping issue 5. The store was tested by
  E13's holes, a case each (`tests/hs/units/holes`), and by random walks
  over those cases' states: written with the code, they shared its blind
  spots, and issues 25 to 30 were in none of them. Status: done for now.
  The probes are cases (`class-default`, `instance-chain`,
  `instance-chain-refused`, `literate`, `fresh-names`) and jobs
  (`hs/units/memo`, `damaged`, `verify`, `trim`), with mutants `HU12` to
  `HU16`. Beside them,
  a tester of mechanical edits, as Rune's `mutate.py` and kept with the
  roadmap's drafts (`impl/bc/tools/mutate.py`; no `.py` lands): a program
  copied and edited a step at a time -- a fixity, a numeral, a string, a
  constructor added, removed, swapped or renamed, a deriving clause, a
  type synonym, a `default`, an export list (`module M` among them), an
  import list (`hiding`, `qualified`, `as`), an import of a module's
  instances alone (`import M ()`, which moves what is in scope along a
  chain, 5.4), a signature removed, a class's default or superclass, an
  instance removed, moved to another module or given up a method, a module
  renamed, a module made literate, an import that makes a cycle, comments
  and blank lines, a step back to an earlier state -- each step built
  through a kept store at one of the levels `-O0`, `-O1`, `-O2`, lint
  levels 0 and 2 and both machines, and held to a build without the store,
  the same bytes or the same refusal, and now and then to `--whole`. Its
  runs are in *Found under rhc: what was run*, below.

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
  loaded -- so that `--verify-cache` can compare it too. Since
  functors-units' M7 (2026-10-25) the functor's case is gone: a functor's
  unit keeps no binders in its basis (issue 1), and its code is its
  function, which names the units it uses as any code does. The rest is
  as above: MLton's S48, which compiled six units because four held only
  across `profile.fun` changed, compiles `profile.fun` alone, since an edit
  of a body no longer changes its unit's identity. Since the build-system
  roadmap's M2 `--verify-cache` compares such an entry: loaded with its names
  remapped, its basis written again and its code read and written, against
  the same made of the unit compiled, identities and what only a hash reads
  left out (`src/driver/cachecheck.sml`, S98). Status: fixed (the
  build-system roadmap's M4). A basis keeps nothing that only a hash reads,
  so one written again from what loading it left is the same bytes, which
  every unit compiled at lint level 2 is held to (`basis-rt`); and an
  identity holds no unit's identity, an import being hashed as what it is
  (docs/units.md, *The export basis*), so an entry taken across a unit that
  changed in nothing it names has the identity a fresh compile gives, and
  its basis written again is a fresh compile's bytes, which `--verify-cache`
  compares. A unit that names nothing that changed is now exact by its
  binders (S121), where it held by fingerprint before.

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

* **30. A unit's fresh names numbered after what the session made
  before it.** Found under rhc (the haskell98 roadmap, 2026-11-16) by the
  tester, at `-O2`, and read with `--verify-store`. The checker numbers a
  program's fresh type variables and dictionaries from 10^8, and each of
  the program's groups goes on from where the one before it ended, so that
  no two of a program have one name (`RhcNames.unitCounters`). A unit
  taken from the store was numbered in the session that made it, after
  whatever that session made before it; one made now goes on from what
  this session made. So a unit made after a unit taken is numbered
  otherwise than in a build without the store, and its Core is other
  text: a derived `Show` of `tests/hs/units/holes/h5-context`'s `D` binds
  `a1_100000001` where a build without the store binds `a1_100000003`. The
  program does the same, but it is not the same bytes at `-O2`, whose Core
  simplifier names what it makes after what it is given (the tester: an
  instance in 1 of 732 builds before this issue was found; the walk of
  `h5-context`, seed 100, step 52), and a link keyed by its Core (issue
  35) misses where only the names moved: a comment in a unit made after
  one taken compiled the link again. Status: fixed. Each of the program's
  groups is numbered from a range of its own, a million wide, by a hash of
  its modules' identities (`RhcNames.programSlot`), as the library's units
  are by their place (`RhcNames.librarySlot`): its names are its own, and
  two groups' meet only where their hashes do (one in 2^28). Numbering
  every group from 10^8 makes the names a unit's own too, but a whole
  compile's HsLint (`--whole --lint=2`) then refused programs ("the
  parameter d100000002 is a dictionary of Show a_100000001, and Show
  a1_100000001 is wanted"): its replay takes a program's numbers to be its
  own, as the groups' ranges keep them. The probe is
  `hs/units/holes/fresh-names` (a comment in a unit made after one taken
  takes the link), which the rhc before the fix fails, and the mutant
  `HU16`; the walk of `h5-context` that found it agrees at every step.

* **31. Paths in a unit's entry.** Found under rhc (the haskell98 roadmap,
  2026-11-16), with `--verify-store`, mapping issue 9. An entry's interface
  holds each definition's place, with the path its module was read from,
  and so does HsLint's part: the snapshot `make` writes holds the build
  tree's paths of the library (`bin/../share/rhc/haskell98/Array.hs`), and
  a program's entries the paths their modules were given by. Nothing a
  program prints or does reads them [inferred: another unit's places are
  read only to tell whether a diagnostic is the library's, by its file],
  so no build differs; but an entry is not the bytes a compile from
  another place gives, and `--verify-store` refuses the library's entry
  of a bin/rhc run anywhere but where make built it, as issue 24 refused a
  correct entry. Status: fixed (2026-11-17), as issue 9 was: an
  interface's places are written with no file and a unit taken has each
  put back where its module is now (`RhcDriver.placed`), and HsLint's part
  writes a place by its module, which the part's map of files to modules
  then gives as itself (`HsLintCodec`). `hs/units/elsewhere` runs a bin/rhc
  whose library is a copy at another path on a store: it takes every unit
  and the link, and `--verify-store` holds every entry, the snapshot's
  library among them, which the rhc before the fix refuses.

* **34. The store trimmed between the units and the link.** Found under
  rhc (the haskell98 roadmap, 2026-11-16), probing `StorePolicy.trimAfter`.
  rhc trimmed its store once its units were kept, before it looked up the
  link's memo, where Rune's store is trimmed after a build: a program
  untouched for a week had its units taken, which keeps them, and its link
  removed by the trim just before it was looked up, and compiled again.
  Not a wrong result, a link compiled for nothing (95M instructions for
  `tests/hs/units/drive`'s). Status: fixed; the store is trimmed when the
  compile is done (`hs/units/trim`).

* **35. A link keyed by its units' entries.** Found under rhc (the
  haskell98 roadmap, 2026-11-16), measuring what a warm build costs. The
  link's memo was keyed by the sums of the units' entries, so that a link
  taken reads no Core; but an entry holds its definitions' places with
  its Core, so a comment or a blank line before a definition is an entry
  of other bytes with the same Core, and the link -- the whole back end
  over what `main` reaches, most of a build -- was compiled again: a
  comment in `Types.hs` of a seven-module program cost a warm build 399M
  instructions, against 394M without a store. Status: fixed. A unit's
  entry keeps the hash of its Core, its index's text and each
  declaration's, as a part of its own, and the link's memo is keyed by
  those, which with the runtime's are all the back end reads (`RhcStore`
  4), and with issue 30 fixed, a comment in a unit made after one taken
  takes the link too; the same comment's warm build costs 51M, 0.13 of
  the build without a store.

* **36. Every unit given the interfaces of all the units before it, each
  time.** Found under rhc (the haskell98 roadmap, 2026-11-16), measuring
  chains and trees of 10, 100 and 500 modules. To name and check a unit,
  and to judge whether its entry stands, rhc installed the interfaces of
  every unit before it into a fresh state (`RhcNames.install`), whose list
  of entities is appended to: unit k paid for k units, and a warm build
  with nothing edited cost per unit 2.7M instructions at 10 modules, 3.4M
  at 100 and 8.2M at 500 (4.1G for a chain of 500, more than half of its
  7.6G without a store). Status: fixed; the state is made once, a unit's
  interfaces installed into it as the unit is done, which is the state
  installing them all at once gives (a fold): a unit taken costs 1.9M at
  10 modules, 2.0M at 100 and 2.1M at 500, a chain of 500 with nothing
  edited 1.1G, and the build without a store 4.6G.

* **37. A unit taken costs the naming of its modules.** Found under rhc
  (the haskell98 roadmap, 2026-11-16), measuring warm builds. A usage of
  a name is answered in the scope of the module that read it, as a compile
  of the unit finds it (H3), so every unit whose entry is judged has its
  modules parsed and named again: about 2M instructions a unit, more than
  half of a warm build with nothing edited (15M of 26M for a seven-module
  program, 61M of 78M for `fluid`'s eighteen). Not wrong, and cheaper than
  checking, but what a hit costs grows with the program, not with what
  changed. Status: open; usages read against each import's exports, as
  GHC records them, would need no scope of the reader's, and are the
  design's to change.

* **38. A warm build after an edit of a body costs a build without a
  store.** Found under rhc (the haskell98 roadmap, 2026-11-16), measuring
  warm builds. The link of the roadmap's C compiles whole what `main`
  reaches, Shake and all, and that is most of a build: 301M of a
  seven-module program's 389M, 608M of `fluid`'s 776M at `-O1`. So an edit that changes
  any Core main reaches -- a numeral in a body -- makes a warm build cost
  1.01 to 1.03 of a build without the store, the front end of the units
  that miss being a few million instructions; only an edit that changes
  no Core (issue 35) is cheap. Not an issue of the store's
  correctness, but of what it saves, which is the front end alone.
  Status: open; it is the roadmap's choice (M21, the link of C, over a link
  of each unit's code, which made hello 932,791 bytes), and a back end
  that kept its work by declaration would be another milestone.

* **39. A unit's desugaring and HsLint read all the units before it.**
  Found under rhc (the haskell98 roadmap, 2026-11-16), measuring the same
  chains. A unit is desugared after the desugaring interfaces of every unit
  before it, given again for each (`HsDesugar.unit`'s `interfaces`), and at
  lint level 2 checked by HsLint after every unit's part joined again
  (`HsLint.join`): a build that makes every unit -- the first, or one
  without a store -- grows faster than the units: desugaring and keeping
  4.6M a unit at 100 modules and 8.0M at 500; HsLint 2.1M a unit at 10,
  3.8M at 100 and 16.5M at 500, 8.3G of a chain of 500's 13G at level 2. A warm build makes few units and
  pays it once each (85M of a chain of 500's warm build with one edited, at
  level 2). Status: fixed (2026-11-17). The driver keeps what the units
  before a unit leave its desugaring, each unit's interface learned once as
  the units are made in order (`HsDesugar.learnMore`, `unitFrom`), and the
  parts of HsLint's joined once each onto what was joined before
  (`HsLint.join`, whose maps now start from the first part's). That left
  the folds over everything known that a unit made for its own share, each
  small and each the size of the units before, which a profile of the chain
  of 500 found one by one: HsLint's replay read the whole compile's
  evidence table for a unit's records (each unit now checked with a table
  of its own); its part, its report and its target's data folded every map
  and every instance (now each module's keys, `HsStringMap.foldPrefix`, and
  the instances added since the units before were restored,
  `HsLintClasses.addedBy`); an instance was found by trying each of its
  class's (now by class and type constructor, `HsLintClasses.heads`); 5.4's
  chain of imports was followed to every module a module reaches, HsLint's
  and the checker's (now searched until it reaches the one asked for); the
  desugaring listed every imported type for the ones a unit names, and
  every known constructor, field and default for what it added (now looked
  up, and the keys given since the unit began); and the interface of a
  module listed every module's definitions and entities (`RhcIface`,
  `HsInfer.part`, now by its keys). The programs, the store's entries (the
  usages, the interface, every part) and HsLint's verdicts are the bytes
  they were: the tester's 81 programs at `-O1` into a store and at `-O2`
  without one, the same programs and the same 871 entries before and after;
  `hs/hslint` 39 of 39, its library's dump among them; HsLint's and the
  checker's mutants caught. What one more unit costs a build without a
  store, from 10 modules to 100 and from 100 to 500 (rhc's VM instructions
  at `-O1`, `impl/bc/perf/` of the roadmap's drafts): a chain at level 0,
  4.6M then 10.0M before, 2.3M then 2.3M after; at level 2, 8.9M then
  30.0M before, 2.9M then 3.1M after; a tree the same (2.7M and 2.7M, 3.7M
  and 3.7M after). A chain of 500 without a store, 4,552M to 1,263M at
  level 0 and 13,022M to 1,703M at level 2; its first build into a store
  14,357M to 3,029M at level 2; a unit's front end, named and checked,
  3.2M at 500 modules before and 1.7M after, as at 10 and 100. The
  tester's 81 programs, of 1 to 18 units: 0.978 of their cost without a store at
  level 0 and 0.974 at level 2 (nofib's `infer`, 15 units, 0.93), and their
  first builds 0.980 and 0.975. A warm build with nothing edited costs
  what it did (issue 37's).

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

**Under rhc** (the haskell98 roadmap, 2026-11-16), found while probing its
store:

* **A diagnostic of a module read for an import named the root's file.**
  A literate file that holds no code is a module without a header, `module
  Main (main) where` (5.1), whose export of an absent `main` was said at
  `Main.hs`, the file rhc was given, not at `A.lhs` (issue 27's second
  probe: "Main.hs: error: an export list names `main`, which is not in
  scope"). A diagnostic with no file of its own is placed at the root
  (`RhcSyntax.message`). Status: fixed (2026-11-17): the assumed header's
  export is placed at the start of the module's own file
  (`RhcGraph.withHeader`); `hs/errors/mod.header.abbrev.nomain_imported`,
  whose first line is now `./A.hs:1:1`.
* **A `default` type checked against every instance, in scope or not.**
  A `default (N, Integer)` where `Num N` is out of scope (5.4) is accepted
  (`HsInfer.defaultDecl` asks at no module), and its N is never chosen,
  since defaulting asks at the module (issue 26's probes). 4.3.4 asks that
  `Num ti` hold, and 5.4 puts an instance in scope only where a chain of
  imports leads to its module, so it holds by an instance in scope or not
  at all. Status: fixed (2026-11-17): the check asks at the module, and
  says why where the instance is out of scope, and HsLint's check of a
  default declaration does the same (`hs/hslint/errors` holds both judges
  to refuse it); `hs/errors/def.decl.num_scope`, under 4.3.4's row
  `def.decl.num`.

* **A superclass named twice in a class's context.** `class (Eq a, Show
  a, Eq a) => C a` desugars to two superclass selectors of one name,
  `%super:Main.C>haskell98:Prelude.Eq`: a whole compile's CoreLint refuses
  the program ("the value ... is declared twice", an internal error),
  where a compile in units takes it and runs it. Found by the tester's
  edit "superclass added" on `nofib/spectral/circsim`, held to `--whole`.
  4.1.3 makes a context a list of assertions and forbids no repetition,
  and 4.3.1 makes the context the class's superclasses: one class named
  twice is one superclass. Status: fixed (2026-11-17): a class's
  superclasses are the classes its context names, each once, in the
  checker and in HsLint, so that a dictionary has one field for it; the
  `hs/lang/cls.class.super_repeat`, under 4.3.1's row `cls.class.super`,
  the same program whole and in units.

* **A compile with `--no-cache` makes the Basis Library's index again,
  wherever no store holds this compiler's.** Seen by the haskell98
  roadmap's agent CS measuring benchmarks (a `lib/cache` of another
  compiler build "doubled a compile's work"), and read under rhc's
  verification: the compile of `examples/benchmarks`' tak with `--whole
  --no-cache`, `RUNE_CACHE` empty, runs 98.7M instructions where the
  `lib/cache` beside its Basis is its own compiler's, and 175.0M where
  there is none or one of another compiler build (175.0M either way: a
  record refused costs nothing to speak of; CS's lower figure, with a lib
  copy without `lib/cache`, was a compile that found the record elsewhere,
  in its workspace's `.rune` [inferred]). The difference is the index
  pass (`--pass-stats`: 0.04 s against 0.33 s): the index is kept as a
  record named by the compiler's identity (`LibraryIndex`, its
  `library-index` key), read from the store and the frozen layer, and a
  compile with `--no-cache` reads such records and writes none, so each
  one makes the index again from the Basis's sources. The programs are
  the same bytes and run the same (149.6M instructions for tak, every
  way). Not a wrong result, but a trap for measuring: a `--no-cache`
  compile costs 1.8 times as much in a tree whose `lib/cache` is stale or
  absent. Status: open; writing the record under `--no-cache`, or naming
  it by what the index is made of rather than by the compiler, would
  change what `--no-cache` means or how the store keys it, which is the
  cache's design.

## Found under rhc: what was run

The haskell98 roadmap's agent BC, 2026-11-16; the tools, their logs and
seeds are with the roadmap's drafts (`impl/bc/`).

* **Each issue above mapped onto rhc.** 1 (a functor's body) and 2
  (overloading registered elsewhere) have analogues, issues 25 and 26; 4
  (a hit that cannot link) is 25's first probe, and 28; 5 and 6 are 33
  and 32; 9 (paths) is 31; 13 (two sessions) is 30; 14 and 19 (sizes that
  grow) were measured, and found 36 and 39; 7 is the same hash; 3 and 21
  to 24 are the REPL's, which rhc has none of; 8, 11, 12, 15 to 18 and 20
  were probed or read and have none [inferred where read].
* **The tester** (`tools/mutate.py`), over 81 programs: the
  multi-module programs of the run set (69 of nofib's, nhc's nofib's and
  the conformance suites', the corpus under `/home/ruud/haskell`, copied),
  the cases of `tests/hs/units` and a program of classes, instances,
  operators and defaults of its own. Before the fixes, 732 builds of 12
  programs: 62 disagreed with the build without a store, 61 of them issue
  29's and one issue 30's. After issues 25 to 29, 2,511 builds at `-O0`
  and `-O1`, lint levels 0 and 2 and both machines (seed 200, 30 steps a
  program), none disagreeing, and 3 where `--whole` refused what both
  compiles in units took (the superclass named twice, above); after issues
  30, 35 and 36, 1,701 builds at `-O2` and `-O1`, lint levels 0 and 2 and
  both machines (seed 300, 20 steps a program), none disagreeing. After a
  comment, blank lines or trailing spaces, no unit but the edited one was
  made, in 350 builds; after a comment the link was taken in 87 of 97
  builds, where it had been in 39 of 161 before issues 30 and 35 were
  fixed, and the warm build cost a median 0.18 of the build without a
  store, where it had cost 1.00.
* **The store**: two and six compiles at once on one store, of two
  programs at three settings each (36 compiles, 4 disagreeing, issue 30's
  at `-O2`; after its fix 30 more, none disagreeing); 110 compiles killed at a random moment, 55 of them while
  they ran, each followed by a compile through the store, none
  disagreeing and no file half written; every entry of a store with a byte
  flipped or cut short (issue 28); a store written by another rhc, which
  shares no entry and which `--prune-store` drops; a snapshot of another
  rhc, whose library is then compiled at each compile (315M instructions
  for hello, against 44M) and is the same program; a store read only, a
  directory where `.rhc` cannot be made, `--layer` before the snapshot and
  after the store, a program moved, copied and compiled from outside its
  directory, each the program a build without the store gives; a store a
  week old (issue 34); the link's memo across levels and machines (issue
  29).
* **What a warm build costs** (rhc's own VM instructions, at `-O1` and lint
  level 0, after the fixes), against a build of the same state without a
  store: nothing edited, 0.07 (a program of seven modules) to 0.24 (a chain
  of 500); a comment above every definition of a module, 0.13; a numeral
  in a body, 0.99 to 1.03 where `main` reaches it (issue 38), 0.30 in a
  chain of 500 whose link is small; a first build into an empty store,
  1.04 to 1.47. Over the tester's 2,511 builds, before issues 30, 35 and
  36 were fixed, the warm builds cost 0.85 of the builds without a store
  in all, the median 1.00: the link (issue 38). A unit taken costs 1.9M
  instructions at 10 modules and 2.1M at 500 (issue 36); a chain of 500
  with nothing edited 1.1G, against 4.6G without a store. Since issue 39's
  fix a build without a store costs some 2.3M a unit made, so a warm build
  with nothing edited is 0.62 of one at 100 modules and 0.80 at 500
  (1.0G against 1.26G): what is left of it is issue 37's.
* **After 31, 39 and rhc's three of its own** (2026-11-17, branch
  `hs-bc2`): `hs/units/elsewhere` (31); the three cases of the defects
  above; the tester's 81 programs compiled by the rhc
  before and after 39's whole fix, the same programs at `-O1` and `-O2` and
  the same 871 entries; `hs/hslint` 39 of 39; rhc's mutants of the files
  changed (HK01 to HK05, HD01 to HD03, HM01 to HM03, HU01 to HU16) all
  caught but HU10, equivalent, once `hs/units/holes/literate` caught HU15
  (27, above); `hs/*` at the check tier, 5,039 tests, 5,032 passing and
  7 failing, two of a table with two rows more than E9's (the two new
  cases now come under their clauses' rows) and five of a case renamed
  while they ran, all of which, renamed, pass.
