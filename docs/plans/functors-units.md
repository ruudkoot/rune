# Roadmap: functors compiled once, and units that cost what a whole compile costs

Rune compiles a functor by static interpretation. The body is checked once
at its declaration, then copied and elaborated again at every application
that makes code, in the unit that applies it. Since performance M3, the copy
no longer decides the application's type, except in four corners. It still
decides the following:
- **what a build in units costs:** a unit that applies a functor carries its
  body's text and the bindings it used, and depends on every change to it;
- **what nested functors cost:** the copies multiply with each level;
- **how much of the cache's logic exists only for functors:** three of the
  fifteen issues of the build cache came from it.

MLton's compiler, compiled in units at tier 2, takes 5.4 times the
instructions of its whole compile, and 6.2 times the cycles. The largest
part is hashing the printed text of functors' and signatures' fingerprints:
about 40% of the cycles, with more for the collector's work on that text.

This roadmap plans four things:
- **Tier 2 dividing by a constant.** This comes first, because the program
  that shows it best is the units build this roadmap makes fast.
- **Hashing that costs what it must:**
  - units-fixes.md's F1 and F2;
  - fingerprints fed to the hasher rather than built as text;
  - fingerprints as hashes of their parts' hashes;
  - the data hashed directly;
  - and a hash chosen for Rune's tier 2, 18 times as fast as today's there.
- **Typing that follows the Definition** in the corners that are left.
- **Functors compiled once, as functions, in every mode.** Whole programs get
  their copies back from an expansion in the middle end, the same in a whole
  compile and in a whole program built from units. A build in units calls
  the function. The units' machinery for functor bodies goes.

  Two prototypes and a gate that is the owner's come before anything is
  removed.

Writing it found a hole in the cache: a warm build can accept a program that
does not type-check, because fingerprints drop the equality of type
variables (issue 16, *Found while writing this roadmap*). Its fix comes
before everything else.

It was written on 2026-10-21 against `78192dfd9`, the merge of pull request
#67 into master. It lives in a worktree, on branch `functors-units`.

What it rests on:
- **The code:** a reading of the elaborator's functors, Translate, the
  representations, the middle end, the unit basis, the cache and its
  fingerprints, `Pickle.hash` and tier 2's division (*Where we are*).
- **Eleven experiments** (*The experiments*):
  - where Rune still types an application otherwise than the Definition,
    against six other systems (E1);
  - a census of the functors of MLton, the benchmarks, the Basis, HOL4 and
    SML/NJ (E2);
  - what the copies cost (E3), and how much run time sits in functor bodies
    (E4);
  - where a build in units spends its time (E5), and hash functions for
    Rune's tier 2 (E6);
  - what an edit of a body compiles again (E8), and whether fingerprints keep
    the equality of type variables (E9);
  - how much of units exists for functors (E10);
  - the literature, and the code of SML/NJ, Poly/ML, MLKit, MLton, OCaml,
    GHC, rustc and Go (E11).
- **Five prototypes, thrown away:**
  - tier 2 dividing by a constant (E7);
  - fingerprints streamed, F1 and F2 (E5);
  - rx2fw, a hash for tier 2, in the compiler, with a probe of it in the
    cache (E6);
  - a fix of a hole in the cache that E9 found;
  - a linear link (E3).

## Status

| Milestone | What | Track | State |
|---|---|---|---|
| M0 | This roadmap | | done |
| M1 | Tier 2 divides by a constant | H | done (2026-10-24) |
| M2 | Hashing that changes no output | H | done (2026-10-24) |
| M3 | Typing that follows the Definition | T | done (2026-10-24) |
| M4 | Fingerprints by structure; gate G1 | H | done (2026-10-24) |
| M5 | Prototype: functors compiled once | F | done (2026-10-25) |
| M6 | Prototype: the expansion | F | done (2026-10-25) |
| G2 | Go or no-go for M7 and M8 (the owner's) | F | go (the owner, 2026-10-25): inline functors bring performance back to today's, and the four checks asked before M7 are clean |
| M7 | Functors compiled once | F | done (2026-10-25) |
| M8 | Nested functors that do not blow up | F | not started |
| M9 | Retire | | not started |

The owner decided D1 to D17 on 2026-10-21, each as recommended
(*Decisions*). D1's functors compiled once wait on gate G2, which stays the
owner's.

The tracks do not wait for each other:
- **H, hashing,** makes a build in units cost what a whole compile costs:
  units-fixes.md's F1 to F4, and the division F4 asked of the JIT.
- **T, typing,** makes Rune type applications as the Definition does in the
  corners that are left.
- **F, functors,** compiles each functor once, as a function, and gives whole
  programs their copies back in the middle end. Its two prototypes come
  first and end at gate G2, which is the owner's.

## The implementation so far

The owner asked on 2026-10-24 to implement the roadmap. It was rebased onto
master `79805ac6f` first; since 78192dfd9 master had moved the compiler into
`lib/compiler` and the test drivers into `tests/runner`, so the `file:line`
references below are to 78192dfd9 and the milestones name files by their
new places.

**M1** (by an agent; on the branch after M4):
- tier 2 keeps the fact that a register holds a constant (`INT`, `CONST`,
  `MOVE`) and divides by one without `idiv`: shifts for a power of two, a
  multiply-high by a magic number for any other (Granlund and Montgomery;
  *Hacker's Delight*), for `int` and `word` `div`, `mod`, `quot`, `rem`,
  and `Int64`/`Word64`'s own, on x86-64 and aarch64; `Simplify` folds a
  constant divided by a constant, leaving what raises;
- `tests/lang/rt.div_constant` (108,304 checks against a divisor read from
  a `ref`) and `tests/register/divconst_test.c` (6.7 million checks of the
  emitted code against C, on aarch64 too under qemu);
- the old `Pickle.hash` loop kept as `tests/perf/hash_mod`: 179.5 cycles a
  byte to 45.7; MLton's 606 files in units at tier 2 (measured before M2,
  as the brief asked): 1,633.4G instructions to 1,588.7G and 0.730 times
  the cycles, against E7's 0.697 and the 0.72 asked -- E7's base ran in
  more cycles; the instructions saved are E7's to the count.

**M2** (`0605214ab`, `88a48f2fd`):
- issue 16's fix landed first, with S68 and S69 (`UnitBasis.version` 8);
- S0, the counters (`--pass-stats=hash`), F1, F2 and the link made linear
  changed no byte of the unit files of the compiler's own sources or of
  MLton's 606 files, once each compiler's own identity in a unit's
  provenance is masked;
- F1's rule that a signature's or functor's usage is fingerprinted at the
  unit's start changed one more case than E5 found: a unit that applies a
  functor it declares itself wrote that functor's own fingerprint in its
  binding list, and writes nothing now, as for every other name of its own
  (S72 is E5's case);
- MLton's 606 files in units: 1,196.6G instructions to 663.4G with MLton's
  build of Rune (-44.6%; E5 predicted -38%), and 1,633.4G to 1,045.8G at
  tier 2 (-36%; E5 predicted -28%).

**M3** (`59694b2b3`, `8bf885b55`, `5e54b7e9b`):
- `--typecheck-only`, `--serve` and the library's analyses make no copies
  (D15): MLton's 606 files type-check in 43.0G instructions, from 93.6G;
- a functor whose result keeps a free type variable is refused (D8); it
  refuses nothing in MLton's sources, HOL4's kernel and functor files, the
  xc2 configurations, the benchmarks, Rune's sources or its libraries;
- every program of `tests/lang` and `tests/errors` is also checked by
  `--typecheck-only`; the corners (a), (c) and (d), where a compile and the
  check still disagree until M7, are each pinned by a test that says so
  (`NAME.typecheck-error`, `NAME.typecheck-ok`).

**M4**:
- rx2fw with the three loops by `Word`'s width, and its probe in the
  cache's configuration and in a basis's header (`UnitBasis.version` 9,
  `UnitCache.version` 7, `UnitMid.version` 4; S70, S71). The probe is
  E6d's value, `089e9c1f195c88743551d55e9a2eb6d5`, on Rune's builds and
  on MLton's, whose `Word` is 32 bits;
- fingerprints of tokens; a structure's of its entries' fingerprints,
  shared with the usages of them; a recursive group of datatypes one value
  (Tarjan's components, members by their anchors; S73). Hashing every
  entry of every signature and functor apart, as S1 first read, made 11
  million small hashes and gained little: a signature's and a functor's
  fingerprint is one stream of tokens, since no usage names their entries;
- the soundness checker, `bin/rune-incremental soundness`: M2's compiler
  against M4's over the scenarios' project, the functors project and the
  compiler's sources (73,121 usages), no violation; M2's against a compiler
  without issue 16's fix, five on the probes; `make test-incremental` holds
  a compiler to itself and checks that a weak hash is caught;
- export beyond hashing: a type was keyed by the text of all its parts at
  each part (the square of its depth), and another unit's name by its
  identity's text; `Pickle.writer` was a list of one-byte strings. All
  three changed, with the same bytes written;
- **measures** (MLton's 606 files at tier 2): 1,045.8G instructions after
  M2 to 698.0G, 884G cycles to 344G, `unit-usages` 106 s to 21 s and
  `unit-export` 111 s to 46 s; hashing 4% of the cycles (from 33.5%);
- **gate G1 is not met:** 1.73 times the whole compile's processor time
  (77.9 s), from 5.2 when units-fixes.md was written (1.51 times in
  cycles). What is left is the units' interface work -- `unit-export` 46
  s, `unit-usages` 21 s, `unit-load` 10 s -- and a profile spread over
  generic code (maps, the collector). Much of it is functors': bodies and
  declaration environments in bases, signatures of functors in usages,
  bodies parsed again on load, copies elaborated in each applying unit,
  which M7 removes;
- MLton's S44 to S48 at the branch's tip (Rune at tier 2, through the
  cache): cold 122.2 s, warm 16.8 s, a leaf 51.0 s (1 unit), a root 15.3 s
  (1), an interface 130.3 s (241), a functor's body 60.0 s (6), and the
  last warm build the bytes of one without the cache; E5 had measured the
  cold, warm, leaf and functor builds at 287, 50.2, 124.6 and 118.5 s with
  MLton's build of the compiler, which is faster than Rune's;
- found on the way: the provenance of a unit
  (`\001RuneSource:HASH:IDENTITY`) was parsed with a 24-digit hash in
  `Link.sourceOf`, in the runtime (`unit_source_current`) and in
  `Runtime.linkedUnitSources` -- S61 failed with rx2fw's 32 digits -- and
  each now takes the hash up to the first `:`; and Rune's
  `CharArraySlice.vector` and `CharVector.tabulate` go through
  `List.tabulate`, a recursion as deep as the vector is long, which
  overflowed the 1 GiB stack on a functor's signature written whole
  (10 MB of tokens). The writer takes `CharArray.vector` instead; the
  Basis is left as it is, for the owner.

**M5 and M6** (by an agent; `54b50cf3d` to `77376491a`): functors compiled
once to functions behind `--functors=functions`, and the expansion that
gives whole programs and a unit's own applications their copies back in
Mid; see *Gate G2* under *The milestones* for the evidence. G2 was go
(the owner, 2026-10-25).

**M7** (by an agent; `1049facdd` to `d55bbe8a4`): the prototypes' way is
the only way.
- `--functors=` and `--datatype-tags=` are gone (no release had them):
  every functor is compiled once to its function, the expansion gives a
  whole compile, a unit's own functors, the functors marked inline and
  `--units --whole` their copies within the budget, and the Basis's marks
  apply unless `--no-inline-functors`; every datatype numbers its
  constructors by their names, with `nil, ::` and `LESS, EQUAL, GREATER`
  as before, and the sorted VM and `_export`'s renumbering of tags go;
  dynamic modules take the functors' nested records (their ABI's
  fingerprint changes).
- Removed: the elaborator's copies (`copied`, `signatureTyped`, the replay
  of counters, `Ast.copyStrexp`, `FunInfo`'s fields of a body), and from
  units the re-parse of bodies, issue 1's binders, `funat` and
  `Expand.current`; a functor's basis is its signature and its function.
  Issue 9's paths stay, for inline copies, and so do the source's hash and
  mode in a basis's prefix, which M7 took out with the re-parse, E10 not
  having seen that the compiler library checks a unit's source by them
  (`RuneCompiler.readUnit`, `readMid`; put back, `UnitBasis.version` 12). 98 files, +964 and -1,531 lines; the elaborator,
  units and `Ast` -532 net, as E10 estimated (520).
- The corners (a), (c) and (d) are closed: their tests are errors now, or
  swap sides. A flexible record a functor's result keeps is refused at
  its declaration.
- What an edit compiles again: S8, S65 and S66 the changed unit alone,
  S49 to S51 `a.sml c.sml` (no longer `main.sml`), S61 `a.sml b.sml`;
  S55's planted entry is `c.sml`'s; S21 keeps `c2.sml d.sml`, since
  `d.sml` names the renamed unit (E10 said "probably" `c2.sml`); MLton's
  S48 one unit, from six. MLton's 606 files: cold 606, warm 0, S45 1, S46
  1, S47 236, S48 1, and the last warm build the bytes of one without the
  cache.
- Against today (e6accb2c0 with the flag off), MLton's benchmark set in
  bytecode and machine instructions: whole 0.997 and 0.984 (the worst,
  `simple`, 1.011 and 1.014), in units 0.981 and 0.961 (the worst,
  `pidigits`, 1.050 in machine instructions); no program past 1.05; the
  same as the flag on, program for program. The bootstrap's instructions
  are today's, its output the same. HOL4 to `hol.state` through the cache
  with `RUNE_VERIFY_CACHE=1`: 362 s, no entry differs.
- What it costs: a compile loads the Basis's marked functors' Mid, about
  0.39M bytecode instructions, `compile-hello` 2.03M to 2.42M; a program
  in units keeps a marked functor's function beside its copies, so
  `wordcount` in units starts in 1.08 times today's machine instructions
  (its work the same).
- Found on the way and fixed: a marked functor's Mid named its positions
  by the path its source was given by, so a unit from the shipped cache
  differed from one compiled again (S61); the expansion aliased a value to
  a global a function sets again, a dynamic module's slot after
  `Dynamic.reload`; and the REPL's entries named their printer's source by
  the session's count, so an entry did not verify in another session
  (build-cache issue 24; S76).

## Found while writing this roadmap

The experiments found the following. Each is answered by a milestone, unless
it is said to be outside this roadmap.

**In Rune:**
- **A hole in the cache: issue 16** (E9). Fingerprints drop a type
  variable's equality, and a signature's local type names' arity and
  equality.
  - In seven of fourteen cases a warm build takes a unit from the cache and
    accepts a program that `--no-cache` rejects. In one of them, the program
    built runs `=` on a function value.
  - In one more case, a warm build rejects a valid program.
  - A fix of four hunks passes every case. It is M2's first item, and the
    first thing to land.
- **The four corners where an application is still typed by its copy**
  (E1). Rune accepts ten programs the Definition rejects, and rejects two it
  accepts. `docs/language.md:28` and `:154` say otherwise. M3, M7.
- **A fingerprint that depends on which member of a recursive datatype group
  is worked out first** (E5). This gives spurious misses, not wrong hits.
  M4.
- **F1's edge case** (E5, E9). The fingerprint of a `sig` or `fun` usage is
  taken after the unit's own declarations, whereas a value's is taken at the
  unit's start. A unit that redeclares a name records one functor's identity
  with another's fingerprint. This also gives spurious misses only. M2.
- **The link is quadratic** (E3): `StringMap.numItems` per key, and an
  insertion sort. MLton's link in units takes 15.7 s, and 1.26 s with the
  fix, for the same bytes. M2.
- **A warm build with no edit hashes every basis's bytes twice** (E5):
  481.5 MB in all, 220 MB of it the second time. M2.
- **Errors print `Int64.int` as `_int64`** (E1). M3.
- **`repOfTy` recognises `array`, `vector` and `ref` by name**
  (`lower.sml:343-346`). It has not been shown wrong; M5 keys them by stamp,
  since abstract parameter types reach Lower there.

**Outside this roadmap:**
- **SML/NJ 110.99.9 on amd64 crashes on some uses of a large word
  constant** (E6): "MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented".
  - The smallest case is a word constant of 2^30 or more passed as the
    accumulator of a recursive function over a list that adds to it:
    `fun go ([], a) = a | go (v :: r, a : word) = go (r, a + v)` applied to
    `0wx40000000`.
  - `0wx3FFFFFFF` compiles; so does `Word64`'s case with a constant of
    2^31. A plain literal, or a multiplication by one, compiles too.
  - SML/NJ 2026.2 compiles them all.
  - The cause is MLRISC's spill rewrite, which moves a 64-bit immediate
    straight into a spill slot, where x86-64 cannot encode it.
  - rx2fw builds its constants at start-up for it.
  - Reported in `docs/bugreport/smlnj/MLRISC/movabsq-spilled`; not sent
    upstream, and no fix written.
- **`smlnj32`'s `Word64` is wrong** (E6): `fromInt`, shifts and `+` give
  wrong results, and `0wx40000000 : Word64.word` prints 0.
- **Rune's int64 VM has a 64-bit `Word` whatever the bytecode** (E6), so a
  program that relies on `Word`'s 63 bits computes otherwise there.
- **`lib/random`'s `hashString` differs on `smlnj32`** (E6), for that
  reason, so the library's promise of the same numbers on every compiler
  does not hold there.
- **MLKit 4.7.25 fails with an internal error** on a functor whose body has
  `val r = ref []` applied after a `;` ("Impossible:
  IntModules.reelaborate.ParseElab.FAILURE"; E1, program b6).
- **SML/NJ 110.99.9 accepts equality through an opaquely ascribed functor
  result** (E1, program e3). This is a deviation of its own.

## The request

The owner's brief, as written:

> - this is a draft roadmap to change/fix how functors and units are handled in rune.
> - relevant documents are:
>   - docs/plans/functors.md
>   - docs/plans/units-fixes.md
>   - docs/plans/build-cache-issues.md
> - the scope of this roadmap is:
>   - fix "F4. A hash that costs less a byte" by making div/mod with constants faster. not because it is very relevant for this roadmap - it is really for docs/plans/performance.md or docs/plans/jit.md - but because we may lose the testcase after this roadmap is done.
>   - when doing separate/incremental compilation rune should elaborate the body of the functor once. when doing whole program compilation is continues to make copies of the fuctor. the reason for this is based on the following assumptions:
>     - copying the functor generates faster code and whole program compilation is intended to generated the fastest code (e.g. via link-time expansion)
>     - elaborating once makes is faster and thus improves compile time - the incremental compilation modes are supposed to be fast
>     - elaborating once allows us to significantly simply how units are compiled as a lot of the complexity comes from how the units / build cache / pickling needs to handles the functors and a lot of this complexity goes away when functors only need to be elaborated once
>   - all the above assumptions need to be validated using prototypes and benchmarks as part of this roadmap
>   - improve the performance of incremental compilation (F1 F2 and F3 in units-fixes.md)
>     - we currently seem to be hashing strings. i.e. we pretty print data types then hash them. F3 suggest to use hashes of hashes. i wonder if we can instead directly hash the underlying datatype w/o going via a pretty print.
>     - check if this is feasible and if this indeed increases performance (w/o introducing correctness issues)
>     - you should also look at faster hash functions
>   - i believe rune is currently more lenients in the typing of fuctors applications than the sml definitions (like mlton is). we should follow the definition. it may be that the leniency is only possible because of copying the fuctors at each application. if it is possible to retain leniency when elaborating functors only once w/o introducing new complexity then you may consider making this into a language feature like we did for flex record typing. we default to the sml97 spec but then offer mlton's more leninet typing as an option.
>   - in functors.md it is noted that "SML/NJ, which never elaborates a body again, is the only one that does not blow up on nested functors." Rune should not blow up either.
> - useful things to study are
>   - the SMLSC (SML separate compilation) literature
>   - unit/build cache/pickling code in other compilers

**The owner's answers while this was written (2026-10-21):**
- **Where:** in the worktree `.worktrees/functors-units`, on a new branch
  `functors-units` from master `78192dfd9`. Committed as M0 and not pushed.
- **What it rests on:** a hybrid. Cheap measurements and small prototypes,
  thrown away, came before the writing (*The experiments*). The large
  prototype the brief asks for -- functors compiled once as functions, and
  the expansion that gives whole programs their copies back -- is too large
  to build before a roadmap that decides its shape. It is this roadmap's M5
  and M6, ahead of the change itself, with a go/no-go gate (G2) that is the
  owner's.
- **Form:** that of `docs/plans/utf8.md`.
- **Heavy runs** (MLton's compiler, HOL4) were allowed, one at a time.

**The owner's ruling after M0 was first written (2026-10-21):** the hash
function is chosen for its speed and correctness on Rune at tier 2 alone.
SML/NJ, a broken compiler, is not to constrain it. The other compilers are
measured for information only. E6 was run again under that rule, and D11
changed with it (rx2fw, 126 bits, in place of four 30-bit lanes).

**And (2026-10-21):** a hash that depends on the size of `Int` and `Word` is
acceptable for its speed, if the cache records that dependence, so that
compilers built by different hosts never mix entries: a probe, one quick hash
whose value tells the hash apart (D11). The owner asked too whether MLton's
build should use 64-bit default types anyway (D17).

**And (2026-10-21):** D11's constants are xxHash64's primes with bit 63
cleared, the owner's suggestion, which E6 checked; D3 moves dynamic modules
to the same records; D4 numbers every datatype's tags by sorted name, without
exceptions, the owner's direction, and M5 measures every ordering.

**The decisions (2026-10-21):** the owner took every recommendation, D1 to
D17.

| The brief asks | Answered in |
|---|---|
| a roadmap to change and fix how functors and units are handled | this document |
| functors.md, units-fixes.md and build-cache-issues.md as the starting point | *Where we are*; *Relation to the other plans* |
| F4 by division by a constant, before the test case is lost | D12, M1; the test case measured and kept (E7, *Measuring*) |
| elaborate a functor's body once in separate and incremental compilation | D1, *The architecture*, M5, M7 |
| keep copying in whole-program compilation | D1, D13: the copies stay, made by the middle end rather than the elaborator (*What the brief gets wrong*) |
| assumption: copies make faster code, and whole programs should be fastest, by a link-time expansion | E4, M6, gate G2 |
| assumption: elaborating once compiles faster | E3, E5 (the usages a copy drags in), E8 (what an edit compiles again), M5, gate G2 |
| assumption: elaborating once makes units, the cache and pickling much simpler | E8, E10, M7 |
| every assumption checked by prototypes and benchmarks | E1 to E11 before writing; M5 and M6 with gate G2 |
| F1, F2 and F3 | M2 (F1, F2), M4 (F3) |
| hash the data, not its printed text | W3, D9 (S0, S1, S2), E5, M2, M4 |
| check that it is feasible, faster and still correct | E5, E9, M4's soundness checker |
| faster hash functions | E6, D11 |
| Rune more lenient than the Definition at functor applications; follow the Definition | W1, E1, D8, M3, M7 |
| the leniency perhaps possible only because of copying | W2, D7 |
| MLton's leniency as an option, if it costs no new complexity | D7 |
| nested functors must not blow up | E3, D13, M8 (on a no-go at G2, D13 D) |
| the SMLSC literature | *What the literature says* (E11) |
| other compilers' units, caches and pickling | *What the implementations do* (E11) |

## What the brief gets wrong, leaves open, or makes dangerous

The items are grouped in the manner of utf8.md, each with the decision or
milestone that answers it.

### Wrong, or out of date

- **W1. "rune is currently more lenients in the typing of fuctors
  applications than the sml definitions (like mlton is)."** Mostly no longer. Performance
  M3 (merged on 2026-10-20) types every application by the functor's
  signature, and Rune rejects functors.md's equality program, which MLton
  accepts. Four corners remain where the copy still decides (*Where we are*,
  (a) to (d)). E1 tried them: Rune accepts ten programs the Definition
  rejects, and rejects two it accepts. D8, M3, M7.
- **W2. "it may be that the leniency is only possible because of copying
  the fuctors at each application."** Right for all four corners and for
  MLton's: each is the copy's typing showing through. It follows that
  elaborating once closes them all, and that MLton's typing cannot be kept as
  an option of the one elaboration, but for one part, the equality of a
  generated datatype, which a summary could carry (D7 B).
- **W3. "we pretty print data types then hash them."** Partly. A type name's
  fingerprint is already its anchor and the hash of its definition (issue 12),
  memoised by stamp. What is printed in full is the environment of a
  structure, of a signature and of a functor's parameter and result
  (`fpEnv`), and that is where the megabytes are. The answer is D9's three
  steps.
- **W4. The test case of F4 cannot be kept where the other tests are.** The
  performance budgets (`tests/perf/*.budget`) count bytecode instructions,
  which division by a constant in tier 2 does not change. The test case
  becomes a cycles benchmark (M1).

### Contradictory

- **C1. Copies by the elaborator in whole compiles, functions in units, and
  S42.** A whole compile and a build from the units' Mid must be the same
  bytes. With functions in the units' Mid and the elaborator's copies in a
  whole compile, they cannot be. The brief's aim -- whole programs as fast as
  copies make them -- is kept by making the copies in the middle end, the
  same way in both (D1 B, D14).
- **C2. An option for MLton's typing, and builds in units that type as
  whole compiles do.** With a body elaborated once in units, MLton's typing
  could exist only in whole compiles (D7 C), and a program would type one way
  or the other by how it is built.

### Ambiguous

- **A1. Which modes are "separate/incremental".** Rune has a whole compile,
  `--units` (with or without the cache), `--units --whole`, the REPL (a unit
  per declaration), and `--typecheck-only` and `--serve`, which make no code.
  `--units --whole` is both: a whole program from the cache. *The
  architecture* gives each its place: functions everywhere; calls in
  `--units` and the REPL; copies made by the expansion in whole compiles and
  `--units --whole`; and no copies at all where no code is made (D15).
- **A2. "Elaborate once" and "compile once".** Since M3 a body is already
  *typed* once, by its summary; what is elaborated again is the copy that
  makes code. So elaborating once means compiling once: a function, and an
  interface for it (D3 to D6).
- **A3. "Faster hash functions."** Faster per byte matters less once no text
  is hashed (S0 to S2), and more what a hash costs per combine; the cache
  trusts its hashes, so quality and width matter as much as speed. The owner
  ruled that Rune's tier 2 alone decides (*The request*, D11).

### Dangerous

- **X1. Datatypes across a functor compiled once.** A datatype a parameter
  specifies has the argument's tags and layout, which the body cannot know;
  one a body declares over a parameter's type would be laid out one way in the
  function and another in its clients. Either, done naively, is a wrong
  program, not a slow one. D4, D5.
- **X2. The Basis's functors become calls in a build in units.** `Word8`,
  `Word32`, `Int32`, the vectors' and arrays' slices and the IO stack are
  functor applications. Every program built in units would reach them
  through closures (D2). E4: a call of `Word32.+` goes from 39 to 60
  instructions, in programs that already take 1.6 to 1.85 times the
  instructions in units that they take whole.
- **X3. A new hash changes every identity.** Every cache, frozen Basis
  included, becomes a miss; `plant.py` must follow; the instruction set's
  fingerprint must not (*Constraints*).
- **X4. A fingerprint that ignores the equality of type variables** would let
  the cache keep a unit whose program no longer type-checks. E9 confirmed
  it, wider than suspected: in seven of fourteen cases a warm build accepts
  what `--no-cache` rejects, because neither a type variable's equality nor a
  signature's local names' arity and equality reach the fingerprint. It is
  issue 16, fixed first in M2.
- **X5. Names in traces.** A call of a functor's function is named by the
  functor, not by the applying structure, wherever it is not expanded; tests
  that print traces need new baselines (M7).
- **X6. The frozen Basis grows** by the bodies of the Basis's functors as
  functions, which today make no code until applied. E3: 45 AST nodes in the
  Basis, 2,105 in MLton (0.46% of its bodies): small.

### Where this roadmap recommends otherwise than the brief

- **Copies in whole programs are made by the middle end, not the elaborator**
  (D1 B). The brief's "continues to make copies" holds of the code; it does
  not hold of the elaborator, which elaborates every body once in every mode.
- **Copies within a unit, even in a build in units** (D2 A). The brief's
  "elaborate the body of the functor once" holds: the body is elaborated once.
  But a unit's applications of its own functors are expanded in the middle
  end, so that a program of one file keeps its code's speed (E4). No unit
  depends on another's body.
- **No option for MLton's typing** (D7 A).
- **The large prototype is a milestone, not an experiment** (M5, M6, G2), by
  the owner's answer.

## Where we are

At master `78192dfd9`. Line numbers are of that commit.

### How an application is typed

Performance M3 (`a6d3f8108` on master, merged with pull request #65 on
2026-10-20) typed every
functor application by the functor's signature, as rule 54 says
([functors.md](functors.md), *A, extended* and *What M3 built and found*).
What the elaborator keeps of a functor is `FunInfo`
(`src/elab/elaborate.sml:30-34`):
- the parameter's name and signature;
- the body as syntax;
- the environment it was declared in, with `allowPrim` and the signatures and
  functors in scope then (`defEnv`, `defSigs`, `defFuns`);
- the **summary** (`:28`): the datatypes the body generates and the result's
  environment, which the declaration's check computes when its result is
  closed (`closedEnv`, `:451-462`; `:1363-1367`);
- `origin`, the identity of the unit that declares it.

An application (`StrApp`, `:1400-1463`) matches its argument against the
parameter, then takes one of two roads (`apply`, `:1459-1462`):
- **`typed`** (`:1412-1419`), inside another functor's declaration only: the
  summary, realised by the match, with fresh names for the datatypes it
  generates. Nothing of the body is looked at again. That is rule 54, and it
  is the summary branch of MLton's `functorClosure`, whose other branch
  elaborates the body again, as `copied` does.
- **`copied`** (`:1423-1456`), everywhere else: the body is copied with fresh
  annotation slots (`Ast.copyStrexp`, `src/frontend/ast.sml:245-319`) and
  elaborated again in the declaration's environment, with the matched
  argument bound to the parameter. The copy is what Translate compiles. Its
  result is then retyped by the signature (`signatureTyped`, `:551-691`):
  - a **fast path** (`:678-681`) returns the copy as it is where it cannot
    differ, that is where every generated datatype admits equality in the
    summary and no parameter type function drops a parameter;
  - otherwise the copy is walked against the realised summary, its equality
    corrected, or its schemes replaced by the summary's where it is more
    general (`merged`, `:635-662`);
  - `--lint` checks the fast path's claim and fails on a disagreement.

So a body is elaborated once against the parameter (the declaration's check),
and again for every application that makes code, nested ones included.
`--typecheck-only` and `--serve` (`src/driver/serve.sml:143`) make the
copies too, although nothing compiles them.

Of `elaborate.sml`'s 1,825 lines, about 200 exist only to elaborate copies
(E10), `signatureTyped` 141 of them. `src/elab/sigmatch.sml` has nothing used
by functors alone.

### Where Rune is still more lenient than rule 54

The brief believes Rune types applications more leniently than the
Definition, as MLton does. That was so until performance M3: Rune accepted
functors.md's equality program, as MLton does; since M3 it is
`tests/errors/err.functor_equality.sml`. Reading the code for this roadmap
found four corners where the copy still decides what the signature should:

- **(a) Overloading settled by the client.** A body's overloaded operators
  and literals are defaulted at the declaration's check (`:1362`), but in a
  copy they stay pending until the end of the *client's* top-level
  declaration (`resolvePending`, `:1796`), and `signatureTyped` ignores them
  (`:585`, `:594-596`). Appendix E gives the default "when the surrounding
  text does not resolve the overloading", the surrounding text being "no
  larger than the smallest enclosing structure-level declaration" -- inside
  the body.
- **(b) A functor with no summary.** Where the declaration's result is not
  closed -- a `val r = ref []` the value restriction leaves ungeneralised --
  there is no summary, every application is typed by its copy, and every
  leak M3 closed is open again; such applications are copied even inside
  other functors' checks (`:1459-1462`). Rule 89 keeps free type variables
  out of the basis, and its commentary (the Definition's Appendix G) lets an
  implementation meet that by refusing the declaration or by replacing the
  variables with arbitrary monotypes. Rune does neither.
- **(c) The equality of type variables.** `signatureTyped`'s comparison of
  types pairs type variables without comparing their equality (`:577-605`,
  which `walk` reaches), the fast path does not look, and `drops` does not catch a
  parameter `eqtype 'a t` realised by `'a ref`, whose equality imposes
  nothing on `'a` (`src/elab/unify.sml:92`). The copy then has `'a * 'a ->
  bool` where the signature has `''a * ''a -> bool`.
- **(d) `--default-type=int64` in a library's functor.** The option applies
  "in the input files and not in the libraries" (`docs/language.md:39`;
  `src/driver/main.sml:555-563`, `:1044-1049`); a copy of a library functor
  is elaborated inside an input file.

E1 tried each on Rune and six other systems. In (a) to (d), Rune accepts ten
programs the Definition rejects and rejects two it accepts, and it agrees on
the rest. Each corner but (d) is one that MLton or Poly/ML has too, though no
other system accepts (a4), a body's literal used at `Int64.int` (*The
experiments*, E1).

Two documents overclaim. `docs/language.md:28`, the deviation "Functors",
still says the copy "is type-checked against the actual argument" and that
this "is not observable". Its row `mod.functor` (`:154`) says a value is "as
polymorphic as the body's check found it", which (b) and (c) contradict.

### Code: no functors at run time

Translate compiles a declaration of a functor as nothing (`DFunctor =>
k ()`, `src/core/translate.sml:534`) and an application as its copy
(`:539-548`). Structures have no run-time form: a value declared at
structure level is a global indexed by its stamp. Each copy has fresh
stamps, so each application makes its own exceptions (`NewExn`, `:507-515`),
which is rule 154. Constructor tags are static, in declaration order, or in a
signature's order under `_export` (`exportTags`, `elaborate.sml:1174-1185`).

The one place a structure is a value at run time is a dynamic module
(`StrDynamic` and `StrExport`, `translate.sml:550-615`; the ABI of D17 in
[incremental-compilation.md](incremental-compilation.md) and
[units.md](../units.md):449-451): one flat tuple of slots -- the
signature's values and exceptions by name, then its structures', by name,
recursively -- each cast to `unit`, with exceptions as values in their
slots. It is the template for a functor's argument and result.

### Representations

- **A constructor's layout is the datatype's,** decided from its *declared*
  argument type (`src/backend/rep.sml:1-33`, `docs/ir.md:497`): an argument
  that is a tuple of two or more makes one object of those fields, tag in the
  header; any other is boxed. "The choice is the datatype's, whatever types
  it is used at."
- **Abstract types are transparent to the compiler:** "an opaque signature
  hides a type from the program, not from the compiler" (`docs/ir.md:151-152`,
  `Ty.realizations`). Lower's `repOfTy` (`src/backend/lower.sml:312-346`)
  maps a type variable to `RAny`, which tier 2 tests at every use and never
  gives a raw home. `poly_eq` at a type that is not ground is the generic
  walk (`jit_h_values_equal`).
- **Lambda** has ML polymorphism only (`Inst`, `src/core/lambda.sml:25`).
  **Mid** has System F types (`src/core/mid.sml:18-27`), rank 1, with `Ty.Gen`
  taking no arguments (`src/core/ty.sml:28`): a type parameter of a function
  can stand for a type, not for a type constructor.
- `repOfTy` recognises `array`, `vector` and `ref` by name when it does not
  know a constructor (`lower.sml:343-346`).

### The middle end, and whole programs from units

The passes after Mid are `midcanon`, `shake`, `lift`, `workers`, `simplify`
(with `inline`, `specialise` and, at `-O2`, `equality`), `refs`, `shake` and
`lower` (`src/driver/pipeline.sml:20-60`). Inlining takes top-level functions
of at most 12 nodes (24 for one that returns functions), or functions named
once (`src/core/simplify.sml:694-760`);
`specialise` copies a self-recursive function for calls that pass it
top-level functions unchanged (`:791-812`). No pass specialises a function
for a record of known values passed to it, and nothing crosses units in a
build in units (`docs/units.md:44-58`).

`--units --whole` (incremental M7) captures each unit's Mid before the
optional passes (`MidCanon.capture`, `pipeline.sml:57`), keeps it in the
cache entry (`UnitMid.write`, `main.sml:734`), concatenates the units'
(`MidCanon.concat`, `main.sml:929-941`) and runs the whole-program passes.
Today each unit's Mid already holds the copies it applied. S42 (`check-units`,
`check-cross`) requires a program built so to be the bytes of the same program
compiled whole. The cache's configuration does not hold `--whole`
(`src/driver/unitcache.sml:98-104`), so the two share entries.

### What functors cost units and the cache

A unit that applies a functor elaborates its body again, in the declaring
unit's basis, "as it was parsed there" ([units.md](../units.md):296-299). So the
unit's basis must carry what the body needs (`funinfo`,
`src/driver/unitbasis.sml:777-804`):
- the body's hash, the declaration's environment as a delta, `allowPrim`,
  and the signatures and functors declared before it;
- the body itself is not written: loading the basis reads the declaring
  unit's source, checks its hash and parses the whole file again with the
  fixity it began with (`bodyOf`, `:1373-1391`; `functorsOf`, `:1198-1204`),
  on every load, after a compile and on every cache hit -- the Basis's
  functor files included, which the REPL reads for it too
  (`src/repl/session.sml:199-200`);
- the binder of every name the declaring unit's compile used, fixity
  included, so that a change in any of them gives a new identity (issue 1 of
  [build-cache-issues.md](build-cache-issues.md); `export`, `:901-918`).

Three of build-cache-issues.md's fifteen issues came from this:
- **1:** the body's fixity and bindings were in no key, and gave wrong output
  silently;
- **9:** a unit's code names the functors' source files, which a unit from
  the cache named where they were;
- **15:** a functor's unit, whose code names nothing, slipped through the
  rule for programs that keep their units' identities.

A use of a functor depends on the body's hash for code, and on its
signature's fingerprint for types. So every unit that applies a functor is
compiled again when the body changes, although its basis no longer does
(the cut-off of M3's S65).

The code that exists only because applying units elaborate bodies again:
about 225 of `unitbasis.sml`'s 1,527 lines, and parts of `unitcache.sml`,
`unitmid.sml`, `pipeline.sml`, `main.sml`, `repl/session.sml` and
`backend/unitfile.sml`. E10 counted about 520 lines in all, 225 of them in
`unitbasis.sml` and 200 in `elaborate.sml`.

### Fingerprints

A fingerprint is the hash of a text that spells out what a name names
([units.md](../units.md), *Fingerprints*; `unitbasis.sml:205-359`). The text
is built by concatenation:
- `fpTy` (`:214-229`) numbers type variables `'i` by first occurrence;
- `fpTycon` (`:231-265`) gives a type name by its anchor and the hash of its
  definition, memoised by stamp (`tyconFps`): a hash of a hash already, since
  issue 12;
- `fpEnv` (`:292-295`) writes every entry of a structure, nested structures
  whole;
- `fpSigma` (`:297-299`) a signature's environment, its bound names local;
- `fpFunctor` (`:320-330`) the parameter's environment and the result's.

`fingerprint` (`:338-359`) builds the text and hashes it with `P.hash`.
`fingerprintAt` (`:398-404`) memoises it by binder and key (`fpMemo`, emptied
once a session by `startSession`, `:102-105`). Structures and signatures have
no stamps: a structure is three maps (`src/elab/env.sml:18`), a signature its
bound names and environment (`sigmatch.sml:9`), known only by their binder
and path. The elaborator's types are not hash-consed; the IR's are
(`ty.sml:70-81`).

Units-fixes.md measured where the time goes at performance M10's tip: MLton's
606 files compiled in units at tier 2 take 433 s against 84 s whole, of which
`unit-usages` 174 s and `unit-export` 148 s; 2,136 MB hashed; `P.hash`'s loop
36% of the cycles, the collector 25%, concatenation 8%. Its fixes:
- **F1:** `export`'s `binding` (`:913-918`) asks `fingerprint` for a functor
  rather than `fingerprintAt`, so 432 MB are hashed twice;
- **F2:** the identity is hashed in `export` (`:941`) and again in `load`
  (`:1343`), 220 MB twice;
- **F3:** fingerprints as hashes of their parts' hashes;
- **F4:** a hash that costs less a byte.

E5 measured them again at `78192dfd9`:
- **At tier 2:** a build in units costs 5.4 times the instructions of a whole
  compile, and 6.2 times its cycles.
- **2,145.7 MB are hashed,** the same picture as units-fixes.md's.
- **A warm build with no edit hashes 481.5 MB:** each entry's integrity
  (245 MB), and each cached basis's identity (220 MB), which hashes a
  basis's bytes a second time.

### The hash

`P.hash` (`src/util/pickle.sml:84-102`) keeps four lanes, each `(h * k + c) mod
p` with a prime `p` below 2^24, and writes them as 24 hex digits: 96 bits.
The lanes stay below 2^31 so that a host with 31-bit integers (SML/NJ's
`smlnj32`) computes it as every other host does; `check-cross` holds them
equal. Other hashes in the tree:
- the IR's hash-consing (`ty.sml:70-81`), in `word` masked to 30 bits;
- `Sha256` and `Murmur2` in `lib/digest`, and `Random.hashString` in
  `lib/random`; the compiler's build file takes neither library
  (`rune.build`).

`P.hash` is copied outside the compiler: `tests/incremental/plant.py:16-24`
reimplements it, and `src/isa/reggen.sml:44` and `src/isa/isagen.sml:51`
reimplement its first lane, `(h*31 + c) mod 16777213`, for the instruction
set's fingerprint.

### Division in the JIT

Tier 1 and tier 2 share their emitters. `int_div`, `int_mod`, `int_quot` and
`int_rem` (`runtime/register/jit/emit.c:437-468`):
- send a divisor of 0 or -1 to the C primitive;
- test, for `mod`, whether the divisor is a power of two (native frames M2);
- otherwise `cqo; idiv`, with the floor's fix-up for `div` and `mod`
  (`floor_div`, `:200-211`).

Nothing knows that an operand is a constant: `emit_INT` stores the value
(`emit.c:24`), although Lower makes a fresh constant for each use
(`src/backend/lower.sml:838-843`) and Regs emits it as `INT` just before the
`PRIM` that reads it (`src/backend/regs.sml:187-189`). The x86-64 encoder has
no one-operand `imul` (`runtime/register/jit/x64.h:88-89`); aarch64's has
`smulh` (`a64.h:66`). `Simplify.fold` folds no division. jit.md's *Left by the
performance plan* (`:2592`) lists division by a constant: the bootstrap
executes 10.5M `idiv`s, 2.5M of them by constants, and `Pickle.hash`'s four
`mod`s a byte make it about 170 cycles a byte at tier 2. The performance
budgets count bytecode instructions (`tests/perf/run-perf.sh:4-9`), the same at
every tier, so none can show this.

### Nested functors

An application inside a functor body is typed by the summary in the
declaration's check, linear since M3. For code, every application inside a
copy makes a copy of its own, since `copied` does not count as a check: a
body applied M times at each of D levels is elaborated, and compiled,
Σ M^k times for k = 0 .. D. Copies cannot be shared: each needs its own
stamps, globals, exceptions and datatypes. `tests/perf/compile-funnest.budget`
is depth 8 with two applications in each body (155.5M instructions); it has no
`scale` line, so the growth is not asserted. E3 measured it: the front end and `--units --whole` grow
linearly with the copies, and a whole compile's `shake` removes the
generated programs' code; what grew faster, in `--units --no-cache`, was the
link, which is quadratic (E3).

### What the corpora hold

E2 counted them:
- **MLton** declares 254 functors and applies them 650 times, 359 of them for
  code, nested up to eight copies deep. All but 0.1 s of the copies' time is
  under one
  declaration, `structure Main = Main (...)`.
- **The benchmarks** declare 299 and apply them 892 times.
- **The Basis** declares 19, applied 114 times.
- **Rune's own sources** declare one, `OrdMapFn`.
- **HOL4** declares 32 in 26 files, 23 of them in its parser and lexer
  generators; its kernel's
  name and term tables apply Isabelle's `Table`.

No functor in any corpus lacks a summary.

## What the Definition says

*The Definition of Standard ML (Revised)*; rule numbers as functors.md cites
them, from the transcription on branch `runespec` (`spec/sml97/modules.rs`).

- **A functor declaration (rule 86)** elaborates the body once, against the
  parameter's signature, each of whose type names "acts like a constant in the
  functor body". The result is the functor's signature `(T)(E, (T')E')`: `T`
  the parameter's names, `T'` the names the body generates.
- **A top-level declaration (rules 87 to 89)** adds nothing with free type
  variables to the basis: "if B ⊢ topdec ⇒ B' then tyvars(B') = ∅". For a
  functor whose result keeps a type variable the value restriction left
  open, the commentary (Appendix G) allows two answers: "replacing such type
  variables by arbitrary monotypes", or to "refuse elaboration in such
  situations". Either fixes one type at the declaration.
- **A functor application (rule 54)** instantiates the signature so that the
  argument enriches the parameter's instance, and renames the generated
  names apart. It never looks at the body. Nothing of the argument beyond what
  the parameter promises reaches the result, except through the realisation
  of `T`.
- **At run time (rule 154)** a functor is a closure, and each application
  evaluates the body again in the closure's basis, with the argument cut
  down to the parameter's interface: new exceptions, new `ref`s.
- **Overloading (Appendix E)** gives an overloaded constant or operator its
  default type "when the surrounding text does not resolve the overloading.
  For this purpose, the surrounding text is no larger than the smallest
  enclosing structure-level declaration". In a functor body that text is
  inside the body.

Three things follow for this roadmap:
1. **Whether a functor is compiled once, as a function, or once per
   application, as a copy, is the implementation's choice.** Both implement
   rule 154. The brief's split -- functions where compiling fast matters,
   copies where the code's speed does -- is allowed by the Definition, as
   long as both give the same types.
2. **Types come from the signature, in every mode.** A body checked once
   against its parameter is all the typing the Definition has; elaborating
   it again against an argument can only add what rule 54 forbids. So
   "elaborate once" is not an approximation: it is the Definition's own
   reading, and every leniency that remains (a to d above) is an effect of
   elaborating again.
3. **MLton's leniency is a deviation, not an extension of a choice the
   Definition leaves open.** Unlike the context of a flexible record (Section
   4.11 leaves it to the implementation, which is why `--flex-records` offers
   modes), the typing of an application is fixed by rule 54.

## What the literature says

E11 read the separate-compilation literature of Standard ML and what it
leans on, beyond what [functors.md](functors.md) and the performance
roadmap's reading had covered. The notes, with every citation, are with the
drafts (`lit/`). Each source is marked read whole, in part, or by its record
alone (*References*).

### Separate compilation of Standard ML

- **SMLSC** (Swasey, Murphy, Crary and Harper, ML '06; the working draft
  CMU-CS-06-104):
  - It separates two kinds of dependency. In an *SC* dependency, a unit is
    compiled against an interface written for it. In an *IC* dependency, the
    interface is inferred by compiling the dependency first. Rune's units are
    IC only.
  - An interface may specify a functor. A unit compiled against `functor F
    (X : S) : T` needs only the functor's signature `(T)(E, (T')E')` (draft
    rule 109).
  - In its realisation by the Definition, "A compiled unit contains source
    code that is evaluated after completion" (rule 103). The paper allows "a
    compiler ... to limit compilation to elaboration and type checking, and
    to perform code generation as part of linking" (p. 1).
  - A build whose units are typed separately and whose code is made, or
    specialised, at link time is SMLSC's own model. That is `--units --whole`
    with the expansion.
  - Types are named across units by path, with labels given when an
    interface is inferred (draft §5.1). Elaboration must be principal, or
    separately elaborated units share types by accident.
- **Appel and MacQueen** (PLDI '94; the TR read whole):
  - "In ML the problem is particularly severe because ML's powerful
    parameterized module (functor) facility entails dependencies among
    implementation modules, not just among interfaces" (p. 1). The dependency
    comes from the transparent results of applications.
  - "In ML, a functor is type-checked and compiled into machine code
    independently of its applications" (§2). Ada's and Modula-3's generics,
    by contrast, are "a kind of source-language expansion. This is not really
    'separate compilation' of generic modules themselves".
  - Their pid is a 128-bit CRC, and hashing cost nothing measurable (p. 8).
- **Shao and Appel, "Smartest recompilation"** (POPL '93, TR in part): a
  functor's argument is completed at link time. "A constant data constructor
  ... is compiled as a variable. A value carrying constructor ... is
  compiled as a pair of injection and projection functions" (§4). That is
  D4's option B.
- **Blume** (PhD thesis, Princeton 1997, in part; and SML/NJ's compilation
  manager, CM, in Blume and Appel's "Hierarchical modularity" and Blume's
  "Dependency analysis for Standard ML", both TOPLAS 1999, read by their
  records and reports):
  - Datatype specifications in parameters force boxing. For lists, "all
    implementors of ML have used the efficient representation for lists
    anyway, thus compromising the completeness of their implementation"
    (§1.4).
  - Inlining across units gained 4% to 8% (p. 125). SML/NJ removed it in
    2021, unused.
- **Elsman** (ICFP '99; PhD thesis, DIKU 1999, in part):
  - MLKit's design, today's Rune's: a functor's body is compiled at each
    application, also across separately compiled units.
  - A unit is reused when its basis strongly enriches the one recorded
    (rule 6.46). Matching new names to old ones is "the key operation" (pp.
    115, 190).
  - The thesis describes a memo of functor instances (pp. 177, 190). Today's
    MLKit no longer has it (`IntModules.sml:468`, `reuse_msg` unused).
- **SML.NET** (Benton, Kennedy and Russo, PPDP '04, §2.1): each module is
  parsed, type-checked, translated and partly optimised by itself and cached;
  most optimisation and all code generation come after linking. This is a
  shipped compiler of SMLSC's model.

### What "elaborate once" means

- **For first-order functors, it is rule 54.** MacQueen and Tofte's
  higher-order functors (ESOP '94) elaborate the body again at each
  application, which "necessitates the availability of the functor body
  source at the point of functor application" (Kuan's 2009 proposal,
  pp. 10-11). Kuan and MacQueen's entity calculus (IFL '09) replaced that in
  SML/NJ. SML '97 has no higher-order functors, and its functor signature is
  complete.
- **F-ing modules** (Rossberg, Russo and Dreyer, JFP 2014, in part):
  - A functor is `∀α.Σ → Ξ`. An application is a match that finds the types
    and a coercion, followed by a call (pp. 18-23). The coercion thins the
    argument, and specialises polymorphic values (p. 19).
  - SML's core needs higher kinds (`type 'a t` specifications), and an
    argument record holds polymorphic fields, which is rank 2. Mid is rank 1
    and `Gen` takes no arguments, hence D3's casts.
- **Harper and Stone** (2000, in part): a datatype is a sealed structure,
  made of an opaque type, constructor functions, `expose` and `eq`. A
  datatype specification elaborates to the same signature. "The treatment of
  datatypes ... appears to be essentially forced" (pp. 18-19). It is D4's
  option B again.
- **Dreyer and Blume** (ESOP '07, in part) studied corner (b):
  - Implementations disagree with the Definition, and with each other, on a
    functor whose body leaves a type variable unresolved (Fig. 6).
  - They propose *generalised functor signatures*, `(X : S) → ∀α.S'`: the
    body's open type variables become type parameters, instantiated at each
    application.
  - That accepts programs the Definition rejects and MLton accepts. The
    Definition's own answer would need higher-order unification, which no
    implementation has.
  - D8 recommends rule 89's refusal, and records theirs as the alternative.

### Representations across a functor boundary

- **Leroy** (POPL '92, in part):
  - A layout is fixed when the type is declared (§4).
  - Values of abstract type are wrapped at the boundary, and inlining
    cancels `wrap (unwrap a)`.
  - "it is possible to stop compile-time reductions at any time ... and
    still get a correct program" (§6). That is D5's carried layout, and D13's
    budget.
- **Shao and Appel** (PLDI '95), and **Shao** (ICFP '97, "Flexible
  representation analysis"; ICFP '98, "Typed cross-module compilation"):
  - SML/NJ boxes values of flexible type, and coerces them at a functor
    application, constructors included.
  - Without hash-consed types, "a one-line functor application ... could take
    tens of minutes" (PLDI '95, p. 9).
  - Flexible representation analysis made some programs 27% to 77% faster,
    and others 5% to 10% slower.
  - Old SML/NJ refused some applications because representations disagreed
    (TIC '97, p. 7).
  - "None of these techniques work across functor boundaries" (Appel's
    critique, 1993, pp. 20-21).
- **Tokuda, Sumii and Abe** (2017) gained up to 21% by specialising OCaml's
  generic array accesses *after* inlining, in the classic `ocamlopt`, whose
  "mostly untyped" Lambda could not re-specialise by itself; flambda's IR is
  untyped too (OCaml's code, E11). They also had to re-key type variables
  between compiled files. Two lessons for M6:
  - the expansion runs on typed Mid, and specialises equality and
    representations again after substituting types;
  - a functor's type parameters are keyed by their specification's path, not
    by a session's counter.

### Fingerprints and hashes

- **Broder** (1993): fingerprints of fingerprints need a non-linear step
  between the levels. `P.hash`'s lanes are linear (`(h*k + c) mod p`), so S1
  feeds them through a mixer before combining (D11).
- **Carter and Wegman** (1979, 1981), **Karp and Rabin** (1987): the bounds
  for linear and polynomial hashing. Two different inputs of length `L`
  collide in a lane `mod p` with probability up to `(L-1)/p` for a random
  multiplier. With `p` below 2^24 and inputs of megabytes, that bound is not
  small. E6 measured it on what the build hashes:
  - every lane of every candidate collides at the birthday bound;
  - masked linear lanes collide in all four lanes at once on Thue-Morse
    strings: masked polynomials from 64 bytes, multiply-add lanes from 256;
  - today's lanes, `mod` a prime, did not, up to 2^14 bytes.
- **Widths** (*What the implementations do*): 128 bits in compilers; 120 bits
  in Go's build IDs, which are "sufficient to drive the probability of a false
  'do not need to rebuild' decision to effectively zero"; 256 bits in shared
  caches. A cut-off compares a key's old value with its new one, so it fails
  with probability `m/2^b` for `m` comparisons, not with the birthday bound
  (Pachocki and Radoszewski 2013, §2.3).

## What the implementations do

E11 read the code of each compiler at the versions in `~/reference`. They
were SML/NJ 2026.2 and 110.99.9, Poly/ML 5.9.2, MLKit, MLton, OCaml 5.5.1
and 4.14.4, GHC, rustc 1.98.1 and Go 1.27.1. Paths are relative to each
tree. [functors.md](functors.md)'s *What the others do* covers how each
types an application; what follows is about code, units and fingerprints.

### Compiling a functor

| | A functor in code | An application | Specialised to copy speed? |
|---|---|---|---|
| SML/NJ | a FLINT function over its parameter's `type` and `eqtype` specs and its argument (`compiler/FLINT/trans/translate.sml:1084-1101`) | `APP (TAPP (f, types), arg)`, with run-time type values (`FLINT/reps/reify.sml`) | no: its specialiser skips functors ("requires REWORK", `FLINT/opt/specialize.sml:484-487`); cross-unit inlining removed in 2021 |
| Poly/ML | compiled once, as a function of the argument structure; with `inlineFunctors` (default, `basis/FinalPolyML.sml:263`) kept as an inline property (`STRUCTURES_.ML:2972`, `mkMacroProc`) | expanded by the ordinary simplifier, always: no budget (`CodeTree/CodetreeSimplifier.ML:812-860`, `EnvSpecInlineFunction`) | yes, within one session; no cache |
| MLKit | the body's source, its MD5 and its bases (`src/Manager/ManagerObjects0.sml:36-44`) | parsed and elaborated again (`IntModules.sml:179-272`) | by construction: static interpretation |
| MLton | the body elaborated per application (`elaborate-env.fun:4547-4721`) | static interpretation, then monomorphisation | by construction; whole programs only |
| OCaml | a function (`lambda/translmod.ml:488-519`), its argument coerced to the parameter's slots (`Tcoerce_structure`) | a call; flambda inlines functors with a bias for top-level applications (`middle_end/flambda/inlining_cost.ml:445-449`), or not at all across `-opaque` | partly: flambda's IR is untyped, so generic equality and array accesses survive inlining |
| Rune today | its copies | a copy per application | by construction |
| Rune, D1 B | a function, once | a call in units; an expansion on typed Mid in whole programs | G2 decides |

**Poly/ML does D1 B already, in one session.** A functor is compiled once,
and its applications are expanded by the simplifier that inlines anything
else. What Poly/ML lacks, and Rune would add, is the step across a cache.
Neither SML/NJ nor OCaml has shown a functor compiled as a function and then
specialised across units to the speed of copies. So G2's threshold has no
precedent to borrow; M5 and M6 are the evidence.

**OCaml with dune has D2's split.** Dune's development profile builds with
`-opaque`: calls only, and dependents depend on interfaces. The release
profile inlines across modules. GHC at `-O0` and rustc's `share-generics` at
low optimisation levels make the same choice of a policy by mode that
changes no meaning. SML/NJ has no such mode: it always compiles a functor
as a function.

### Datatypes a functor's parameter specifies

| | Tags | Layout across the boundary |
|---|---|---|
| SML/NJ | sorted by name, constant and value-carrying constructors numbered apart (`ElabData/types/conrep.sml:36-50`, `Elaborator/elaborate/elabtype.sml:142-143`) | fixed at the declaration; a `TAGGED` constructor is never flattened; wrapped and unwrapped at `CON` and `SWITCH` (`FLINT/reps/wrapping.sml:93-176`) |
| Poly/ML | sorted by name, "This simplifies matching with datatypes in signatures" (`ParseTree/TYPECHECK_PARSETREE.sml:2001-2005`) | constructors are values at run time: (test, value) and (test, inject, project) (`DATATYPE_REP.ML:183-217`) |
| OCaml | declaration order, constant and non-constant apart (`typing/datarepr.ml:101-152`) | independent of types; matching requires the same order and arity ("Constructors %a and %a have been swapped", `includecore.ml:376-378`) |
| MLKit, MLton | n/a: static interpretation | n/a |
| Rune | declaration order, one sequence (`ty.sml:233-235`: `nil` 0, `::` 1) | from the declared argument type (`rep.sml`) |

Rune is the one that flattens by a constructor's declared argument type,
which is what Appel's critique says fails at functor boundaries.
- **Sorting by name, Rune's way,** moves `list`'s tags (`::` sorts before
  `nil`) and `order`'s, which the VM's C depends on. SML/NJ's numbering by
  kind keeps `list` and `bool`, but Rune numbers in one sequence. D4 takes
  sorting all the same, and changes the C.
- **Sorting removes the permutation, not the layout.** A flexible argument
  realised as a pair is still flat in the argument and boxed by the
  specification.
- **Hence a descriptor, for the layout alone (D4).** It holds field counts
  where a specification leaves the layout open. It is smaller than Poly/ML's
  constructor functions, a match on it is still a switch without inlining,
  and the expansion folds it.

### What a unit that applies a functor depends on

| | Depends on |
|---|---|
| SML/NJ | the declaring unit's static pid: the functor's signature and its static closure, every type declaration in the body included, not its code |
| GHC `-O0`, OCaml `-opaque` | the interface only |
| GHC `-O` | also the hash of the unfolding exported for inlining |
| OCaml | the `.cmx` CRC, if it was read |
| MLKit, Rune today | the body's source and hash, and the bases it was elaborated in; MLKit rebuilds by timestamps over the MLB scope, and skips rewriting a basis whose pickle is unchanged (`Manager.sml:312-342`) |
| Rune, D1 B | the functor's signature, like any other use of a name |

### Fingerprints

Every compiler studied hashes data, not printed text, and makes it canonical
first:
- **SML/NJ:** a 128-bit CRC of a pickle. Names are sorted (`pickmod.sml:1048-1053`)
  and stamps renumbered by first occurrence (`:607-643`). Nodes are hash-consed
  (`Library/pickle/pickle-util.sml:214-261`). Other units' entities are
  written as (pid, index) (`pickmod.sml:531-546`). Its pids add a GUID of the
  source path and the time of the first compile (`Rehash.addGUID`), so they
  are not reproducible from a fresh checkout: not a model for S42's
  determinism.
- **GHC:**
  - MD5 over the binary form (`compiler/GHC/Iface/Recomp/Binary.hs:30-44`),
    each reference written as the fingerprint of what it names
    (`Recomp.hs:1336-1366`): S1's hashes of hashes.
  - Declarations are hashed by strongly connected component. Issue #18733
    gave mutually recursive types equal fingerprints. The fix hashes the
    group with placeholders and gives member *i* `H(group, i)`
    (`Recomp.hs:1086-1155`, `:1377-1397`). M4 must handle Rune's `datatype
    ... and ...` and `withtype` groups the same way.
- **rustc:**
  - `StableHasher` is a 128-bit SipHash, from the `rustc-stable-hash` crate
    (`rustc_data_structures/src/stable_hash.rs:14-17` re-exports it). The
    trait, `StableHash` in 1.98.1 (`HashStable` before), has rules: equal
    values hash equal and unequal values unequal, nothing specific to a
    session (`:50-77`), a length before every list (`:350-363`), and no
    iteration over hash maps (`:590-594`).
  - `DefPathHash` is the stable key across sessions: a crate id and a hash
    of the parent, kind, name and disambiguator, with a collision checked at
    insertion (`rustc_hir/src/definitions.rs:70-95`, the check at
    `:321-340`). That is D10's "binder
    identity and path".
  - The hashes of interned lists are cached by pointer: "~4,000x slower"
    without (`rustc_middle/src/ty/impls_ty.rs:15-45`).
  - One cached result in 32 is hashed again as a check
    (`rustc_query_impl/src/execution.rs:520-560`).
- **OCaml, the counter-example:** a `.cmi`'s CRC is a digest of the marshalled
  signature (BLAKE2b-128 since 5.5.0, MD5 before; `file_formats/cmi_format.ml:84-93`),
  locations and stamps included, so it cuts off poorly. Dune hashes
  structurally with BLAKE3 (dune 3.23.1, not in `~/reference`:
  `src/dune_digest/digest.ml:168-316`, `feed_repr` and `Feed`).
- **Go:**
  - Keys are SHA-256 with a version salt
    (`src/cmd/go/internal/cache/hash.go:21-46`).
  - `GODEBUG=gocachehash` prints every hash's inputs, and `gocacheverify`
    always rebuilds and compares. These are the two modes M4's checker
    borrows.

What S2's tokens must therefore be:
- prefix-free: a tag per constructor, a length per list or string;
- in a canonical order;
- with no counters or stamps, positions relative or left out;
- with recursive groups hashed as GHC hashes them.

### Hashes and widths

| Bits | Who |
|---:|---|
| 64 | Cargo, ninja, Clang's context hash |
| 96 | Rune today |
| 120 | Go's build IDs |
| 128 | SML/NJ (CRC), GHC (MD5), rustc (SipHash-1-3), OCaml (BLAKE2b-128), MLKit (MD5) |
| 160 | Nix, ccache |
| 256 | Bazel, Go's cache, sccache |

SMHasher rates FNV, `h*33+c`, lookup3, Murmur2 (in Rune's `lib/digest`),
Murmur3's 32-bit form and xxHash32 as poor. Aumasson, Bernstein and Boßlet
found multicollisions of Murmur that do not depend on its seed ("Hash-flooding
DoS reloaded", 29C3, 2012; read through a summary), so seeded copies of one
narrow function are not independent lanes. A shared cache, between
people who do not trust each other, would need SHA-256 or BLAKE3, as Bazel,
Go and sccache use; Rune's cache is local, as Cargo's and ninja's are (issue
7, out of scope).

## The experiments

Each was run at `78192dfd9`, in snapshots of it built under `.worktrees/`, on a
machine that other sessions shared (a load of about 8 to 11). Claims rest on
instruction counts; seconds and cycles are indications, with the load
stated. The scripts and raw results are with the drafts
(`~/.cache/claude-rune-drafts/functors-units/results/E1` to `E11`), each next to the
command that made it. The prototypes were thrown away; their patches are kept
there.

| | What | Answers |
|---|---|---|
| E1 | Where Rune still types an application differently from the Definition, against six systems | W1, D7, D8 |
| E2 | What the corpora's functors are like | D3, D4, D8 |
| E3 | What the copies cost after performance M3 | assumption 2, D13, X6 |
| E4 | How much run time sits in functor bodies | assumption 1, D2, X2 |
| E5 | Where a build in units spends its time, and F1, F2 and S0 built | D9, M2, M4 |
| E6 | Hash functions for Rune's tier 2, and on the other hosts for information | D11 |
| E7 | Tier 2 dividing by a constant, built | D12, M1 |
| E8 | What an edit of a functor's body compiles again | assumptions 2 and 3, D1 |
| E9 | Whether fingerprints keep the equality of type variables | X4, M2 |
| E10 | How much of units exists for functors, and what B adds | assumption 3, M7 |
| E11 | The literature and other compilers | *What the literature says*, *What the implementations do* |

### E1. Where Rune still types an application differently from the Definition

**The test.** 26 programs, each headed by what the Definition requires and
the rule that says so.
- They ran on HaMLet 2.0.1, SML/NJ 110.99.9, Poly/ML 5.9.2, Moscow ML 2.10.1
  (`-P full`), MLKit 4.7.25 and MLton 20241230.
- On Rune they ran in four ways: whole; `--units --no-cache`, in one file and
  split so that the functor is declared in another unit; and
  `--typecheck-only`.
- **Rune's four ways agree on every program.** `results/E1/table.md` has every
  answer and message.

| Program | Definition | HaMLet | SML/NJ | Poly/ML | Moscow ML | MLKit | MLton | Rune |
|---|---|---|---|---|---|---|---|---|
| D3's equality program | rej | rej | rej | rej | rej | rej | acc | rej |
| D3's exceptions | acc | acc | acc | acc | acc | acc | acc | acc |
| (a1) `T.double 1.5`, application and use in one structure | rej | rej | rej | acc | acc | rej | rej | **acc** |
| (a2) the same, no `;` in the file | rej | rej | rej | acc | acc | rej | rej | rej |
| (a3) the same, with `;` | rej | rej | rej | rej | rej | rej | rej | rej |
| (a4) a literal of the body used at `Int64.int` | rej | rej | rej | rej | rej | rej | rej | **acc** |
| (a5) `w + 0w1` of the body used at `Word8` | rej | rej | rej | acc | acc | rej | rej | **acc** (and wraps) |
| (a6) as a1, inside another functor's declaration | rej | rej | rej | acc | acc | rej | rej | rej |
| (b1) a body's `ref []`, used at two types | rej | rej | rej | rej | rej | rej | acc | **acc** |
| (b2) that functor declared alone | either | rej | acc | acc | acc | rej | acc | acc |
| (b3) D3's equality program with a `ref []` | rej | rej | rej | rej | rej | rej | acc | **acc** |
| (b4) the polymorphism leak with a `ref []` | rej | rej | rej | rej | rej | rej | acc | **acc** |
| (b5) an expansive function value | rej | rej | rej | rej | rej | rej | acc | **acc** |
| (c1) `eqtype 'a t` realised by `'a ref` | rej | rej | rej | rej | acc | rej | acc | **acc** |
| (c2) `type 'a t` realised by `int` | rej | rej | rej | rej | acc | rej | acc | rej |
| (d1) a library functor's `int` under `--default-type=int64` | acc | | | | | | | **rej** |
| (d2) the same, used at `Int64.int` | rej | | | | | | | **acc** |
| (d4) the Basis's `RunePackRealFn` under `--default-type=int64` | acc | | | | | | | **rej** |
| MLton's polymorphism leak (functors.md) | rej | rej | rej | rej | rej | rej | acc | rej |

A blank cell is a host without `--default-type`. Under (b), SML/NJ, Poly/ML
and MLton warn. The rest of the programs Rune types as the Definition does:
- an argument more polymorphic than the specification;
- exception replication;
- equality through an opaque and a transparent result;
- `+` at a parameter's type;
- (b6), a `ref []` with a `;` after the application.

SML/NJ alone accepts an opaque result's equality.

**What it shows:**
- **(a) holds only within one top-level declaration as Rune splits a file.**
  `resolvePending` runs at the end of each (`elaborate.sml:1796`). So the
  `;` makes no difference (a2), and a structure that holds both the
  application and the use does (a1). Poly/ML and Moscow ML do the same,
  wider still.
- **(b) brings back everything M3 closed** -- D3's equality leak (b3) and the
  polymorphism leak (b4) -- and accepts the declaration alone silently
  (b2). Rule 89 keeps the type variable out of the basis, and its
  commentary lets an implementation refuse the declaration or give the
  variable an arbitrary monotype; Rune does neither, so (b1) and (b3) to (b5)
  leak what either choice would refuse. HaMLet and MLKit refuse it.
- **(c) is lost by the fast path** (`alike`, `:678-681`) as much as by
  `walk`; a realisation that drops a parameter (c2) takes the `merged` road
  and is refused.
- **(d) is Rune's own,** and goes both ways: a library functor's copy takes
  the input file's default (d2), and so refuses what the library's own typing
  allows (d1). In the Basis it reaches only the internal `RunePackRealFn` and
  `RunePackReal32Fn`, whose `bytesPerElem` literals, 8 and 4, are left to
  defaulting.
- **Every corner of Rune's is one MLton or Poly/ML has,** but for (d); no
  other system accepts (a4) itself. MLton accepts all of (b) and (c);
  Poly/ML and Moscow ML the overloading ones.
- **Nothing measured relies on (a) or (b)** (E2): no functor in any corpus
  lacks a summary, and no copy's overloading was settled other than as the
  class's default. The census did not count (c) or (d).

A wart found on the way: errors print `Int64.int` as `_int64` (d1, d4).

### E2. What the corpora's functors are like

**Method.** A throwaway census in the elaborator (`patches/E2-census.patch`)
writes a line for each declaration, each application, and each overloaded
variable a copy leaves to its client, when `RUNE_CENSUS` is set.
- It ran `--typecheck-only` over MLton's 606 files (46 s, 6.6 GB), Rune's
  sources, the Basis, the 11 other libraries, and the 510 benchmarks of
  `examples/benchmarks`, all of which compile.
- A syntactic scanner covered HOL4 and SML/NJ 110.99.9's sources. On the
  benchmarks it finds all 299 declarations the census finds.

| | MLton | Benchmarks | Basis | Rune's `src` | HOL4 (scan) |
|---|---:|---:|---:|---:|---:|
| functor declarations | 254 | 299 | 19 | 1 | 32 |
| applications that make code / only checked | 359 / 291 | 738 / 154 | 109 / 5 | 2 / 0 | 59 in all |
| deepest copy | 8 | 12 | 1 | 0 | |
| never applied | 16 | 3 | 3 | 0 | |
| with no summary | 0 | 0 | 0 | 0 | |
| applied for code in 1 / 2 / 3-5 / 6+ files | 227 / 7 / 4 / 0 | 103 / 153 / 34 / 6 | 3 / 2 / 6 / 5 | 1 / 0 / 0 / 0 | |
| with a parameter type of arity >= 1 | 166 (65%) | 138 | 0 | 0 | |
| with a polymorphic value spec | 192 (76%) | 128 (43%) | 11 | 0 | |
| applications matching a datatype spec | 356 | 96 | 4 | 0 | |
| of them, constructors in another order | 170 | 10 | 0 | 0 | |
| of them, a flat layout where the spec's is boxed | 0 | 8 | 0 | 0 | |
| `=` at a parameter's type | 179, in 17 functors | 21, in 8 | 0 | 0 | |

**MLton's parameters are large.** Counted through every substructure, a
functor's parameter holds a median of 2,993 value specifications. The 90th
percentile is 24,110 and the largest is 124,485; 185,497 of the 2.38M in all
are polymorphic.

**Tags in another order** are everyday code:
- in MLton, `Ast.Pat.node` (the signature lists `Paren | Or`, the functor
  `Or | Paren`), `Ast.Spec`, `Sigexp`, `SigConst`, `SharingEquation` and
  `Type.Dest.dest`;
- in ML-Yacc, `Errs.err`, `Absyn.exp` and `Absyn.pat`.

**Layouts that differ** are rarer and real: eight in HaMLet's
`GrammarModuleFn` and `GrammarProgramFn`. `Core.AtPat`, `Core.Dec` and
others there are flat because they come from a copy of `GrammarCoreFn` with
`Info = int * int`.

**HOL4** declares 32 functors in 26 files, 23 of them in `tools/mlyacc` (22)
and `tools/mllex` (1); 32 files apply one. Its kernel declares none, but the
kernel's neighbours apply
Isabelle's `Table`: `prekernel/KNametab.sml` and `postkernel/Termtab.sml`.
SML/NJ's own sources have 526 declarations and 997 applications.

**The Basis** has 19 functors, applied 114 times, 96 of their value
specifications polymorphic. The IO functors (`PrimIO`, `StreamIO`,
`ImperativeIO`) leave nothing to defaulting; only `RunePackRealFn` and
`RunePackReal32Fn` do.

**Overloading left by a copy to its client:** MLton 144 type variables (39
defaulted, 105 settled by the client), the benchmarks 2,629 (408 and 2,221),
the Basis 4, the libraries 1. None was settled other than as its class's
default.

**What it predicts:**
- **Tags in another order are everyday code,** which D4's sorted numbering
  answers. A layout the specification leaves open is rare (HaMLet's grammar
  functors), which D4's descriptor answers.
- **D3's flat tuples do not scale to MLton:** an application would copy
  thousands of slots. A structure needs a record of its own at run time, made
  once and shared by every application that takes it (D3, revised).
- **Refusing (b) refuses nothing measured,** and neither does settling (a) in
  the body.
- **Under D2, HOL4's term and name tables become calls** through `Table`'s
  result. G2 measures HOL's kernel work for it.

### E3. What the copies cost after performance M3

**MLton's 606 files,** compiled by MLton's build of Rune (`bin/rune-mlton.bin`):

| | Whole | `--units --no-cache` |
|---|---:|---:|
| instructions | 117.4G | 1,187G |
| processor time | 53.1 s | 281 s |
| peak memory | 6.7 GB | 7.3 GB |
| elaboration | 41.8 s | 19.6 s |
| of it, applications that make code | 23.9 s (57%) | 7.4 s |
| of those, matching the argument | 21.2 s | 5.3 s |
| of those, copying the body | 0.05 s | 0.04 s |
| of those, elaborating the copies | about 2.6 s | about 2.1 s |
| unit-export / unit-usages | | 121.0 s / 102.2 s |
| link | | 15.7 s |

- **In a whole compile, the rest of elaboration is:**
  - checking bodies at their declarations, 9.0 s;
  - applications inside those checks, 4.0 s;
  - everything else, 4.9 s.

  The back end takes about 6.8 s more.
- **All but 0.1 s of the copies' time is in one top-level declaration,**
  `structure Main = Main (...)` (`main/main.sml:10`): 301 of the 359
  applications that make code.
- **Of the 359 applications that make code, 329 are inside other copies.**
  Under D1 B, these are typed once, in their declarations' checks, and never
  matched again. Only the 30 at the top remain.
- **The copies' cost is matching, not elaborating the body:** 21.2 s of
  23.9 s. So assumption 2 holds for a whole compile: about half of MLton's
  elaboration would go.
- **In a build in units,** copies are 2.6% of the time, and the interfaces
  are 79% (*E5*).

**The bootstrap.**
- It takes 1.330G bytecode instructions compiled whole and 2.00G in units.
- Its copies take 43 ms of 766 ms of elaboration: 0.6% of the compile.

**The generated programs** of `tests/perf/gen.py`, in three modes:
- **Whole compiles and `--units --whole` grow about linearly with the
  number of copies** where each body applies two functors (exponents 1.02 to
  1.10), and as the depth to the power 1.4 to 1.6 where it applies one. In a
  whole compile `shake` removes the generated programs' code altogether, so
  there the copies cost the front end only.
- **`--units --no-cache` grew faster:** as the size to the power 1.8 or 1.9
  with two applications a body, and 1.6 with one. Depth 12 with two
  applications a body took 109.0G bytecode instructions, against 3.04G whole
  and 8.69G for `--units --whole`. At tier 2, 440 s of its 476 s were the
  link.

**The link is quadratic, independently of functors.**
- `keyId` (`src/backend/link.sml:88-96`) calls `StringMap.numItems`, which
  is linear (`ordmap.sml:160`), for every new key.
- Each unit's exports and globals are sorted by insertion
  (`link.sml:211-229`).

A throwaway fix of both (`patches/E3-link.patch`) gives the same bytes. With
MLton's build of Rune (at a load of about 20), it takes the link of depth 12
from 231 s to 1.1 s, and the link of MLton's 606 files in units from 15.7 s to
1.26 s. With it, builds in units grow linearly.

**What B adds:**
- Every body is compiled once: 459,555 AST nodes in MLton, against the
  494,069 its copies compile today.
- Bodies never applied, which make no code today, are 2,105 nodes in MLton
  (0.46%), 175 in the benchmarks, 45 in the Basis, and none in HOL4. X6 is
  small.

**What it predicts:**
- **Assumption 2 holds, by two routes.**
  - In whole compiles, the copies' elaboration is about half of MLton's.
  - In builds in units, the copies are only 2.6% of a cold build. The
    hashing (track H) and the link matter more there, and the link's fix
    belongs in M2.
  - The incremental modes gain through what a copy drags in: the usages of
    a unit full of applications (E5: `main.sml`'s 58 s, from one line), and
    the units compiled again after an edit of a body (E8).
- **Nested functors already cost the front end linearly.** What grows as Σ M^k
  is the code before `shake`, and the matching inside copies; D13's budget
  bounds the code.

### E4. How much run time sits in functor bodies

With D1 B, a build in units calls a functor's function. Values of a
parameter's type are abstract there, and calls through the argument are
unknown. E4 bounds what that would cost.

**Method.** A throwaway change to Translate (`patches/E4-marker.patch`) names
each function made inside a functor's body `NAME@F`. Samples of `perf record`
over `--jit-perf-map` are then attributed in two ways:
- **by function;**
- **by source span,** through `--jit-dump`'s listings, so that functor code
  inlined into an ordinary function counts too.

The span is the true exposure. On the Word benchmark it is 57.3% against
41.7% by name; on `lexgen`, 19.0% against 2.6%.

**The compiler compiling itself.**
- 5.3% of its cycles are in functor bodies, by span. Almost all of it is
  `OrdMapFn`'s `go` and `bal`, in `StringMap` and `IntMap`.
- Built in units, the same compiler executes 13.5% more instructions and 18%
  more cycles than built whole, for the same output.

**MLton's benchmark set** (the 35 programs that run within 2 GB).
- By span, in a whole compile, the share in functor bodies is:
  - `checksum` 86.7% (the Basis's `PackWord`), `barnes-hut` 84.7%;
  - `simple` 55.5%, `mlyacc` 47.5%, `fxp` 43.1%;
  - `wc-input1` 27.0%, `hamlet` 22.5%, `lexgen` 19.0%,
    `wc-scanStream` 19.0%;
  - `ray` 10.7%.

  22 of the 35 have none. Across the set that is a mean of 12.0% per program.
- Built in units against whole today, the set takes 1.17 times the
  instructions and 1.23 times the cycles. The outliers are `tensor` (3.5×),
  `zern` (3.2×), `fft-realarray` (3.2×), `raytrace-realarray` (2.0×), `tak`
  (1.74×) and `checksum` (1.62×).
- These outliers are mostly not functors. `tak` spends 17% of its cycles in
  the top-level `not`, called out of line across a unit boundary. The RealArray
  programs call the Basis's array code across units.

**A benchmark of Word8, Word32, Word8Vector, PackWord32Big and BinIO**
(16 MB):
- 57.3% of its cycles are in functor bodies by span, 21% in `RuneWordNFn`
  alone.
- In units it takes 1.85 times the instructions of a whole compile today:
  `Word32.+` and `Word32.fromLarge` become calls.

**One call of `Word32.+`**, beyond an empty loop:

| | instructions | cycles |
|---|---:|---:|
| whole, a known call (inlined) | 10.0 | 6.0 |
| whole, a closure held in a global | 59.1 | 29.2 |
| units today, a known call into the Basis's unit | 39.1 | 20.3 |
| units, an instance as B makes it (a record of closures) | 60.1 | 29.7 |

`OrdMapFn`'s `find` over 20,000 keys, as B's instance against today's copy,
takes 2.0 times the instructions with `int` keys and 1.46 times with
`string` keys. The difference is one unknown `compare` per level of the
tree.

**What it predicts:**
- **The compiler built in units under B:** about 2.5% to 3% more cycles.
  This is an estimate from the micro-benchmarks: the time in `StringMap` and
  `IntMap`, times the slowdown of each. It comes on top of the 18% a build
  in units costs today.
- **The Basis's functors in units** go from about 39 to about 60
  instructions a call (+54%), where programs that use them already run 1.6
  to 1.8 times slower than whole.
- **A program's own functors in the same unit** are the large exposure.
  `barnes-hut`, `simple`, `mlyacc`, `fxp` and `hamlet` spend 22% to 85% of
  their cycles there. A program of one file is one unit, so D2 as first
  drafted ("never expand in a build in units") would put its own functors
  behind unknown calls: six times the instructions and five times the cycles
  per small operation.
  - Expanding an application of a functor declared *in the same unit* makes
    no unit depend on another's body.
  - That is D2 A as this roadmap recommends it.
- **Builds in units are already slower than whole for another reason:** small
  functions in other units, the Basis's above all, are not inlined across the
  boundary (`docs/units.md:44-58`). Inlining them is incremental
  compilation's "Cross-unit inlining in incremental builds", and is worth more
  than B costs (*Later*).

### E5. Where a build in units spends its time, and F1, F2 and S0 built

MLton's 606 files compiled with `--units --no-cache --type-work=1000000000`.

**Counters.** Performance M10's patch of counters was ported and extended to
count the bytes hashed by phase and call site, and the memo's hits and misses
by phase (`patches/E5-counters.patch`). It costs 0.4% of instructions and
changes no output.

**The baseline at `78192dfd9`** (load about 3):

| | MLton's build of Rune | Rune at tier 2 | Rune at tier 2, whole |
|---|---:|---:|---:|
| instructions | 1,181G | 1,629G | 303G |
| cycles | 829.7G | 1,038G | 167G |
| processor time | 263.6 s | 331.3 s | 60.9 s |
| `unit-usages` | 98.9 s | 137.4 s | |
| `unit-export` | 109.4 s | 115.3 s | |
| elaboration | 20.1 s | 36.8 s | |
| `unit-load` / `link` | 11.4 s / 15.9 s | | |

At tier 2 a build in units costs 5.4 times the instructions of a whole
compile, and 6.2 times its cycles. It hashes 2,145.7 MB, which reproduces
units-fixes.md's count:

| What is hashed | MB | Hashes |
|---|---:|---:|
| usages, signatures (`fpSigma`) | 817.5 | 710 |
| usages, functors (`fpFunctor`) | 430.0 | 260 |
| `export`'s `binding`, functors again (F1) | 431.9 | 280 |
| `export`, the identity | 219.9 | 791 |
| `load`, the identity again (F2) | 219.9 | 791 |

The memo hits 61,550 times and misses 23,096. `x86-codegen.fun` and
`amd64-codegen.fun` hash 190 MB each.

**Warm builds** through `--cache-dir` (MLton's build of Rune):

| | Seconds | Units compiled |
|---|---:|---:|
| cold | 287 | 791 |
| no edit | 50.2 | 0 |
| a leaf, `main/main.sml` | 124.6 | 1 |
| a functor's body, `ssa/profile.fun` | 118.5 | 6 |

- **Checking the cache costs almost no fingerprinting.** `broken` works out
  none in the no-edit and leaf builds, and five (2.8 MB) after the functor's
  edit.
- **A build with no edit still hashes 481.5 MB.**
  - Each entry's check of its integrity takes 245 MB.
  - Each cached basis's identity takes 220 MB, so a basis's bytes are hashed
    twice.
  - The other 16.5 MB are the keys' text and the functors' sources.

  F2 has a twin in the cache: keep the identity in the entry.
- **The leaf's cost is `main.sml`'s usages, 58 s.** `main.sml` is one line,
  `structure Main = Main ()`. But elaborating the copy of `Main`'s body
  gives it 7,560 usages, 210 of them functors and 170 signatures, which hash
  711 MB. D1 B gives it one: `fun Main`.

**S0, streaming** (`patches/E5-s0.patch`). Pickle gets a hasher (`hasher`,
`feed`, `finish`), and the `fp` functions feed it; `fpTycon` hashes a
definition with a hasher of its own. One trap:
- `fpEnv` works out its entries in descending order (`StringMap.foldri`) and
  writes them in ascending order.
- `tyconFps`, the memo of type names, makes the fingerprint of a recursive
  group of datatypes depend on which member is worked out first.
- So streaming in ascending order changes fingerprints. S0 walks each
  environment in the old order first, then feeds it.
- The same dependence causes spurious misses today: a unit that names an
  unchanged `A.u` is compiled again because another unit now names `u`
  before `t` (`results/E5/order`). S1 must give a recursive group one
  canonical value.

**F1** (`patches/E5-f1.patch`) changes bytes only in E9's edge case, whose
usage depends on the memo today. On MLton all 280 lookups of `binding` hit
the memo, and nothing changes. **F2** (`patches/E5-f2.patch`) passes
`export`'s identity to `load` (`Pipeline.unitThrough`).

**The gate held.** With the counters alone, with S0, S0 and F1, and S0, F1 and
F2:
- all 1,584 files of `--emit-units` (compared by sha256), and the program,
  are the same bytes;
- the cache after the four warm builds is the same 1,594 files;
- `make test-incremental` passes, 114 of 114.

| Instructions against the counters alone | S0 | S0 and F1 | S0, F1 and F2 |
|---|---:|---:|---:|
| MLton's build | -29.4% | -36.2% | -38.3% |
| Rune at tier 2 (against the base) | -17.9% | | -28.5% |

- **MLton's build:**
  - cycles go from 760G to 490G (the counters' run against S0, F1 and F2);
  - the bytes hashed go from 2,145.7 MB to 1,493.9 MB;
  - `unit-usages` goes from 105.5 s to 45.2 s after S0, and 48.2 s with F1
    and F2, now all `P.hash` at 29 MB/s.
- **Tier 2:** cycles go from 1,038G to 770G, and a build in units from 6.2 to
  4.6 times a whole compile's cycles.
- **Warm builds:** about 35% fewer instructions for the leaf and the functor's
  edit (`main.sml`'s usages from 58 s to 25 s); the build with no edit is
  unchanged.

**What is left at tier 2 after S0, F1 and F2:**
- `unit-usages`, 89 s: mostly `P.hash` over 1,248 MB of text, which it
  takes at 12.5 MB/s in E6's measure. That is for M1 and S1.
- `unit-export`, 74 s. On MLton's build, where `export` takes 83.7 s, 65 to
  75 s of it is not hashing, by the counters. It is not profiled.
  units-fixes.md found pickling itself about 1.4% of the cycles at
  `a6a024ab1`, so what it is remains open; G1 depends on it.
- elaboration, 43 s.

**What it predicts:**
- M2 can land with no output changed but issue 16's fix and F1's edge case.
  It is worth 38% of the instructions of MLton's build in units.
- M1 (division) and M4 (rx2f, S1 and S2) take the rest of the hashing.
- `export`'s pickling needs its own look before G1. M4 has it.

### E6. Hash functions for Rune's tier 2

**The owner's ruling (2026-10-21):** the hash is chosen for its speed and
correctness on Rune at tier 2, and on nothing else. SML/NJ, `smlnj32`
included, constrains nothing. The other compilers were measured too, but
for information only.

E6 ran in two rounds. The first, before the ruling, asked every candidate
to give the same value on every host, `smlnj32` included. That limited the
candidates to 30-bit lanes, with right shifts only of masked values. The
second, E6b (`results/E6b/README.md`), lifted that limit and designed for
Rune's own arithmetic.

**What Rune's arithmetic is** (`results/E6b/wordcheck.txt`):
- `Word` is 63 bits, and wraps mod 2^63. That holds on every engine of a
  build: the interpreter, tier 1, tier 2, the stack VM, the 32-bit VM, and
  aarch64 under qemu.
- The VM built with 64-bit integers (`runevm-int64`) has a 64-bit `Word`,
  whatever the bytecode says.
- `Word64` costs about twice `Word` per byte at tier 2. Its loops do not
  allocate, but its operations cost more.

**What a hash costs at tier 2 is reading the bytes.**
- `String.sub` is the only byte read every host has for the compiler's
  sources. A loop that only sums bytes takes 30 instructions a byte.
- Packing seven bytes into one 56-bit word adds 2.
- A 63-bit multiply-and-xorshift lane adds 4, and a second lane 4.4.
- So about 80% of a good hash is the read, and a second lane is cheap.
- Tier 2 checks the range of a constant shift and whether a global
  constant is initialised at every use, so constants are read into locals
  first (3 instructions a byte).
- A call costs about 250 instructions before the first byte.
- The packing is done in `Word`. In `Int`, it would raise `Overflow` on a
  host whose `Int` is 32 bits.

**The candidates** (`results/E6b/tables.md`), at tier 2, the harness
subtracted, best of three:

| | Instructions a byte | Cycles a byte | MB/s | A 16-byte text, instructions / ns | Combining, instructions / cycles a value |
|---|---:|---:|---:|---:|---:|
| polymod, today's `P.hash` | 178 | 171 | 13.1 | 2,926 / 943 | 778 / 781 |
| polymod, with E7's division | 158 | 50 | 64.4 | 2,596 / 296 | 693 / 205 |
| rh2: two multiply-xorshift lanes | 44.1 | 13.4 | 242.5 | 1,078 / 101 | 117 / 31 |
| **rx2f: two xxHash-style lanes** | **49.5** | **13.9** | **234.0** | **1,470 / 129** | **182 / 52** |
| xx63: one xxHash-style lane, 63 bits | 40.5 | 11.4 | 286 | 1,188 / 101 | 172 / 46 |
| mx2w64: rh2's design in `Word64` | 79.2 | 27.6 | 117 | 2,148 / 259 | 328 / 107 |
| xx64: xxHash64 itself, in `Word64` | 67.3 | 27.7 | 114 | 1,710 / 194 | |

The other candidates of both rounds -- the first round's masked 30-bit
lanes and mix30w, Murmur2, FNV at 63 bits, and one-lane and `Word64`
variants -- are in the same table of the drafts. None comes near rx2f at
tier 2.

**Correctness** (`results/E6b/check`, `quality`):
- **The SML is the function meant.** An independent model in C gives the
  same digests as the SML at tier 2 for all 14 candidates. It was checked on
  the 67 MB corpus of fingerprint texts, its 33,639 pieces, the small corpus
  and the streams of values combined. xx64 gives XXH64's published values.
  The compiler's prototype of `Pickle.hash` streaming rx2f, whole or fed in
  pieces of 1 to 13 bytes, matches the model.
- **Every engine of a build gives the same values:** the interpreter, tier
  1, tier 2, `--jit=all`, the stack VM, the 32-bit VM with and without the
  JIT, and aarch64 under qemu. Only the int64 VM differs, for every 63-bit
  design.
- **Quality:**
  - On the corpus, every candidate collides at the birthday bound, and no
    whole digest collides.
  - On structured inputs, rx2f is clean: sparse keys, runs of zeros, cyclic
    texts, one or two bytes changed anywhere, a million counters, and no
    Thue-Morse collision up to 2^16 bytes.
  - Its full bias matrix (inputs of 8 to 64 bytes, 10,000 samples) is ideal:
    no more than one cell beyond 4.5 standard deviations.
  - Combining, it is at the bound on chains of child hashes that differ in
    one lane, in one bit of two values, in small values, and on parents of
    hashed children.

**Weaknesses found in the obvious designs:**
- **Multiply-xorshift is weak when a whole 63-bit word goes in.** A
  difference in a value's top bits stays in the lane's top bits, and the next
  value can cancel it.
  - rh2's first lane collides about 48 times where 1.4 are expected.
  - The one-lane design has 46 collisions of the whole digest.
  - Text, packed seven bytes at a time, never reaches the top bits.
  - Child hashes, which a combine feeds, do. Hence rx2f's xxHash round:
    rh2 is safe for text and not for combining.
- **rx2f needs its full ending.** Without one, or with only a fold, the bias
  matrix is far off (the worst cell at 0.44); with one multiply, borderline.
- **FNV at 63 bits** collides on Thue-Morse strings from 4,096 bytes, and
  fails as a combine.
- **The first round's masked polynomial lanes** collide in all four lanes at
  once on Thue-Morse strings: masked polynomials from 64 bytes, multiply-add
  lanes from 256.

**The width.**
- One 63-bit lane puts an accidental collision among a million identities
  at about 5 × 10^-8.
- Two lanes, 126 bits, cost about 4 instructions a byte more (about 10%).
- The second lane also covers the structural collisions of a single lane.

**In the compiler.** `Pickle.hash` and S0's streaming hasher were switched
to rx2f on top of E5's S0, F1 and F2 (`patches/E6b-rx2f-only.patch`).
`make test-incremental` passes, 114 of 114. MLton's 606 files in units at
tier 2:

| | Instructions | Cycles | Seconds | `unit-usages` | `unit-export` |
|---|---:|---:|---:|---:|---:|
| base | 1,629G | 1,038G | 331.3 | 137.4 | 115.3 |
| S0, F1 and F2 (M2) | 1,165G | 770G | 235.4 | 89.1 | 73.8 |
| **and rx2f** | **1,030G** | **551G** | **177.8** | **39.8** | **64.3** |
| the whole compile | 303G | 167G | 60.9 | | |

- A build in units goes from 6.2 times the whole compile's cycles, to 4.6
  after M2, to 3.3 with rx2f.
- It still hashes 1,571 MB, more than M2's 1,494: a fingerprint that names a
  hash now names 32 digits. That is about 5 s of the 40 of `unit-usages`, at
  234 MB/s. The rest is presumably building the texts and walking the
  environments, for S1 and S2.

**The other hosts, and a probe in the cache** (E6c, `results/E6c/README.md`).
The owner accepted that the hash depends on the size of `Int` and `Word`,
for its speed. But the cache and the unit files must record that
dependence, so that compilers built by different hosts never mix entries.
The owner also asked whether MLton's build should use `-default-type int64
-default-type word64`.

- **Plain rx2f collapses on a narrow `Word`.**
  - It does not merely give other values. On MLton's default build, whose
    `Word` is 32 bits, the 33,639 pieces of the corpus get 32 distinct
    digests; on `smlnj32`, 16. A rotation by 31 or 32 keeps one bit or none.
  - Such a build of the compiler would take wrong entries from its own
    cache.
  - So the hash needs a path for a narrow `Word`.
- **rx2fw is rx2f with that path.**
  - Where `Word` is 63 bits or wider, the sum is masked to 63 bits before
    each rotation, and the lane before each shift of the ending.
  - Where `Word` is narrower, the same function runs in `Word64`, its
    constants built from 21-bit pieces and its digits written a nibble at a
    time.
  - Against the C model, over the corpus, its pieces, the small corpus and
    the combined streams:

| Build | Plain rx2f | Masked | rx2fw |
|---|---|---|---|
| Rune: interpreter, tiers 1 and 2, stack VM, 32-bit VM, aarch64 | agrees | agrees | agrees |
| Rune's int64 VM | differs | agrees | agrees |
| MLton, `-default-type int64 -default-type word64` | differs | agrees | agrees |
| MLton as built today (32-bit `Word`) | collapses | collapses | **agrees** |
| SML/NJ 64-bit, Poly/ML, MLKit | agrees | agrees | agrees |
| `smlnj32` | collapses (16 distinct) | collapses | differs, all distinct |

  `smlnj32`'s own `Word64` computes `fromInt`, shifts and `+` wrongly, so it
  can only have a hash of its own.
- **What the masks cost at tier 2** (best of five; cycles within the noise):

| | Instructions a byte | A 16-byte text | A value combined |
|---|---:|---:|---:|
| rx2f | 49.5 | 1,470 | 182 |
| masked | 51.4 (+3.8%) | 1,608 (+9%) | 205 (+13%) |
| rx2fw | 51.4 | 1,569 | |

  Tier 2 keeps every mask, although each is all ones on a 63-bit `Word`:
  six instructions each. The function does not change where `Word` is
  exactly 63 bits, so rx2fw can take the unmasked loop there. Rune then
  keeps rx2f's cost and every host's values agree (D11). That variant was
  not measured; it is rx2f's loop.
- **MLton's build with `-default-type int64 -default-type word64`** (D17):
  - It builds cleanly, with no warning, for rune, runedoc, runeopt and
    runeisa.
  - The runner's `check-cross` against `bin/rune-boot` passes, 586 of 586.
    That covers the compiler compiling itself, `rune-units` through a shared
    cache, runedoc, runeopt, `--basis all`, `tests/lang`, the examples, every
    Basis test, `@doc` and `@opt`.
  - Caches filled by Rune's compiler are taken whole by that build, and the
    other way round: 13 of 13 units of a project, 227 of 227 of the
    compiler's sources, the same bytes. The same holds for MLton's default
    build with rx2fw.
  - It costs MLton's build speed:
    - the bootstrap: 3.9% fewer instructions, 4.6% more cycles;
    - MLton's 606 files in units: the same instructions but 24% to 32% more
      cycles, 320 to 338 s against 259 s, with elaboration from 19 to 31 s.
    - Both runs reached the 7 GB heap cap; the larger objects of 64-bit
      integers are the suspicion, not profiled.

    MLton's default build with rx2fw, S0, F1 and F2 takes those files in 163
    s.
- **The probe.** `Pickle.probe` is one digest of a fixed text:
  - pieces of 0 to 15 bytes, which cover every number of pending bytes and
    every tail;
  - a piece of 1,000 bytes;
  - the bytes 0x80 to 0xFF;
  - seven bytes 0xFF, the largest word one step takes.

  Once S1 combines, values with bit 62 set and the largest values join it.
  - Rune, both MLton builds and the int64 VM give
    `07facb226fa4fa4c4e2ecbda1627d2a3` with E6c's constants, and
    `089e9c1f195c88743551d55e9a2eb6d5` with E6d's; `smlnj32` gives another.
  - It costs 45 to 48 µs at tier 2 once warm, 0.7 to 1 ms on its first call,
    and is worked out once a run.
  - **In the cache:** the cache's settings gain `("hash", probe)` beside
    `Config.identity`. A cache whose configuration differs only in its hash
    is reported once with `--explain-rebuild` ("the cache DIR holds entries
    made by a compiler whose hash differs (its X, this compiler's Y): none
    is taken"), and the frozen Basis likewise. The first entry of a
    configuration writes `units/about`, a line per setting.
  - **In the unit files:** a basis's header becomes "RBI", its version, the
    probe and its name. `loadAgainst` refuses another probe with "a basis
    made by a compiler whose hash differs": in the cache that is a miss, in
    the REPL's units an error.
  - `UnitBasis.version` goes from 7 to 8. `UnitCache`'s entries keep their
    format, and `UnitFile` is untouched.
  - **Without the probe,** no build took a wrong entry from another's cache,
    but only by accident: the cache's configuration is itself a hash. A
    foreign `.rbi` failed with "names a unit the session has not", and a
    foreign `.rbu` failed to link.
- **Tested.**
  - From Rune to `smlnj32`, and back, nothing is taken; everything is
    compiled again, and the build says why.
  - Between Rune and either MLton build, everything is taken.
  - `make test-incremental` passes with two new scenarios, 116 of 116:
    - **S70:** `plant.py --basis-probe` rewrites an entry's probe, which is
      then missed, with the message;
    - **S71:** a cache's configuration with another hash; everything is
      compiled again, and the build says why.
  - `tests/incremental/run.sh` passes with both MLton builds, 168 of 168.
- **`check-cross`'s `rune-units` needs `smlnj32` left out.** Rune's compiler
  sources include `lib/basis/runtime.sml`, so the compiler built in units
  keeps its units' identities. A host whose hash differs therefore builds
  other bytes. `smlnj32`'s whole programs still agree. The alternative is
  63-bit arithmetic in `Int` limbs for `smlnj32` alone.
- **Earlier, for information:**
  - `Random.hashString` (`lib/random`) gave other values on `smlnj32`.
  - SML/NJ 110.99.9 on amd64 crashes on some uses of a word constant of
    2^30 or more ("MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented";
    *Found while writing this roadmap*), so rx2fw's constants are built
    from 21-bit pieces at start-up, which costs Rune nothing.

**The constants** (E6d, `results/E6d/README.md`). E6b to E6c made 63-bit
constants of xxHash64's primes by shifting them, `(p >> 1) orb 1`. The owner
asked whether clearing bit 63 would not be better. It is the more principled
choice: mod 2^63 a prime and the prime with bit 63 cleared are the same
number, so every product is the low 63 bits of xxHash64's own, and the
primes, already odd, need no `orb 1`. Shifting replaces every low bit, which
are the bits that matter mod 2^k. The cleared P1 and P4 have sparse top bits
(`001` and `0000`), which was the risk. E6d ran the whole suite on both:
- **Agreement:** the cleared function matches its C model on the corpus,
  its pieces and the small corpus, on Rune's engines, the int64 VM and both
  MLton builds. The compiler's prototype passes `make test-incremental`, 116
  of 116.
- **Collisions per lane at 16, 20, 24 and 28 bits:** shifted 17,234, 1,041,
  60 and 3; cleared 17,178, 1,079, 60 and 2; the birthday bound 17,266,
  1,079, 67.4 and 4.2. No whole digest collides for either.
- **The bias matrix:** cells beyond 4.5 standard deviations, at 8, 16, 32 and
  64 bytes: 0, 0, 0 and 1 shifted; 0, 0, 1 and 0 cleared. The worst cell is
  0.0231 from a half shifted, 0.0251 cleared.
- **Structured inputs, Thue-Morse and the combine chains:** no whole
  collision for either; every lane count within the noise of the other's
  and of the bound.
- **Speed:** the same instructions, 51.4 a byte and 205.1 a value combined
  with the masks of E6c.

The cleared constants are as good on every test, and simpler to state.

**What it predicts (D11, D17):**
- rx2fw for text and for combining, 126 bits, with an unmasked loop where
  `Word` is 63 bits. It is better than today's hash at tier 2 on every
  measure, with M1's division or without.
- The probe, in the cache and in the unit files.
- `smlnj32` out of `check-cross`'s units comparison.
- MLton's build left as it is: it agrees without 64-bit defaults, which would
  cost it a quarter of its speed on large builds.

### E7. Tier 2 dividing by a constant, built

A prototype for x86-64, thrown away (`patches/E7-divconst.patch`: the
runtime only, 308 lines added in ten files). It has three parts.

**The encoders.** `x64_imul_r` and `x64_mul_r`, the one-operand forms
(REX.W F7 /5 and /4), give the high half of a product.

**A fact the emitter keeps.** Up to eight registers are remembered as
holding a constant within a run: set by `INT`, by a `CONST` of an
immediate, or by a `MOVE` from a known register. The fact is dropped at a
jump target, after any instruction that does not go on to the next, and
when the register is written. The plan had "the last `INT`", which was not
enough:
- at a join such as `if b then 3 else 5`, Lower moves each arm's constant
  into the register the `PRIM` reads;
- word literals, and ints that do not fit 32 bits, are always `CONST`
  (`regs.sml:187-190`).

**A plan per divisor** (`divplan.h`, new):
- 1, and a power of two, by shifts and masks.
- `div` and `mod` at `int` by a positive `c` as `s ^ floor((n ^ s) / c)`
  with `s = n >> 63`, by Granlund and Montgomery's unsigned magic number,
  which always fits 64 bits for a 63-bit dividend.
- `quot` and `rem`, and a negative `c`, by the signed magic number of
  *Hacker's Delight* and the remainder's fix-ups.
- `word` by the unsigned magic number (its 65-bit form under `RUNE_INT64`).
- 0, and -1 at `int`, keep today's path, so `Div` and `Overflow` are raised
  as before.

`x mod 16777213` becomes 15 instructions in a straight line with one `mul`
and no branch. Today it is two tests, a power-of-two test at run time, `cqo;
idiv` and a fix-up with branches.

**Correctness.**
- A C model of the exact steps emitted passed 111,274,842 checks at 63 and
  64 bits. Each of three mutations of the model was caught.
- An SML test checked every operation by 45 `int` and 30 `word` literal
  divisors against the same operation with the divisor read from a `ref`.
  - The divisors include 0, -1, `Pickle.hash`'s primes, values near 2^31,
    2^61 and 2^62, and the extremes.
  - The dividends are the edges, 40 multiples of the divisor either side of
    each edge, and 600 pseudo-random values.
  - It made 200,266 checks at 63 bits on the interpreter, tier 1, tier 2 and
    with tiering; and 201,146 on `runevm-int64` and `runevm-rawhomes` with
    `--int-bits=64`. All passed.
  - Each run gave the checksum `--jit=off` gives, that of the C primitives.
    Two mutant VMs were caught: a magic number off by one, and no reset at a
    jump target.
- 306 programs of `tests/lang` gave the same bytes on both VMs at `--jit=all
  --jit-tier=2`. So did the bootstrap's output and MLton's.

**Measures** (load about 1 unless said):

| | base | prototype |
|---|---:|---:|
| `Pickle.hash`, instructions per byte | 178.0 | 158.0 |
| `Pickle.hash`, cycles per byte | 181.9 | 46.6 |
| same at a load of 24 | 229.5 | 81.4 |
| bootstrap, instructions | 13,448.9M | 13,421.5M (-0.20%) |
| bootstrap, cycles (ten rounds) | | -1.2% mean, within the spread of ±3% |
| **MLton's 606 files in units at tier 2:** instructions | 1,629.0G | 1,584.2G (-2.7%) |
| cycles | 1,023.9G | 713.4G (-30.3%) |
| processor time | 357.5 s | 283.7 s |
| `unit-usages` | 146.9 s | 104.3 s |
| `unit-export` | 123.4 s | 100.9 s |

**What the bootstrap and MLton showed:**
- **The bootstrap divides by a constant 2,531,100 times, and by a variable
  8,450,735 times** (`--jit-stats` counts them now): 11.0M in all, against
  jit.md's 10.5M, 2.5M of them by constants.
- **The MLton build's savings are the hashing.** Its 44.8G fewer
  instructions are 20.0 instructions a byte over 2.24 × 10^9 bytes, which
  is units-fixes.md's 2,136 MB counted in MiB (E5 counted 2,145.7). Its 310G
  fewer cycles are within a few per cent of 135 cycles a byte over the same
  bytes (303G).

**The test case** is written down to be reproduced
(`results/E7/testcase.md`): the inputs, the command, the machine, and what
to compare.

**What it predicts:**
- **M1 takes 30% of the cycles out of MLton's build in units.** It takes
  0.2% of the bootstrap's instructions; the bootstrap's cycles moved within
  the noise.
- **Hashing would fall from about 40% to about 15% of that build's cycles.**
  This is an estimate from the micro-benchmark's rate, not a profile.
  units-fixes.md's aim, hashing under 5% of the cycles, still needs F1 to
  F3.
- **aarch64 needs a `umulh` encoder,** and both high-half operations as one
  instruction each. The rest is portable.
- **The prototype left three things for M1:** `Simplify`'s folding,
  division at `Int64` and `Word64`, and runeopt.

### E8. What an edit of a functor's body compiles again

`tests/incremental/mlton.sh` on MLton's 606 files (5fe943391), at tier 2,
through one cache:

| Build | Wall s | MLton units compiled |
|---|---:|---:|
| S44, cold | 461.3 | 606 |
| S44, warm, no edit | 106.2 | 0 |
| S45, a leaf (`main/main.sml`) | 298.9 | 1 |
| S46, a root (`Control`'s body) | 82.9 | 1 |
| S47, an interface (`CONTROL_FLAGS`) | 904.2 | 241 |
| S48, a functor's body (`ssa/profile.fun`) | 460.6 | 6 |
| from the warm cache, `--whole` | 217.5 | 0 |
| without the cache | 791.5 | 0 |

The last warm build is the bytes of the build without the cache.

**S48** adds a line to the body of `Profile`, applied in eight files. Six
units are compiled again:
- `ssa/profile.fun` itself;
- four, `ssa/simplify.fun`, `ssa/ssa.fun`, `main/compile.fun` and
  `main/main.fun`, because "its entries hold across a unit that changed,
  which a program that keeps its units' identities takes none across";
- `main/main.sml`, because "its entries used funat main/compile.fun@...,
  which is another now".

The chain starts with the body's hash, which is in `profile.fun`'s basis.
So its identity changes with any edit of the body (`funinfo`,
`unitbasis.sml:777-804`). MLton's compiler links `lib/basis/runtime.sml`,
so it is a program that keeps its units' identities (`main.sml:513-516`),
and it takes no entry across a unit that changed (issue 15). With D1 B no
body is in a basis, the identity stays, and S48 compiles `profile.fun`
alone.

**S45** shows what one unit full of applications costs. `main/main.sml`
alone took about 190 s more than the warm build with no edit. That is its
301 applications that make code, and their usages; it was 22.7 s of MLton's
151 s of elaboration in functors.md's E18. With D1 B they are calls.

**The warm build with no edit takes 106 s.** It loads 606 bases, checks
every usage's fingerprint, and links. E5 breaks it down.

**The compiler's own history.**
- The compiler's sources declare one functor, `OrdMapFn`, applied twice,
  in its own file. The Basis declares functors in 17 files.
- Of the 270 commits since 2026-09-01 (merges aside) that touched `src/`
  or `lib/basis`, 34 touched a file that declares a functor
  (`results/E8/history.md`).
- Such an edit recompiles every Basis unit that applies the functor, in
  every build that does not use the frozen Basis.

**HOL4** was not built for this, as E2's scan answered what a build
would.
- HOL4 declares 32 functors in 26 files, 23 of them in its parser and lexer
  generators.
- Its kernel declares none. Two of its neighbours apply Isabelle's `Table`:
  `KNametab` and `Termtab`.
- An edit of `Table`'s body recompiles those and what applies them.
- So the risk 3 that incremental-compilation.md saw in "HOL4's functorised
  kernel" is small.
- The functor-heavy code is MLton's and the Basis's.

**What it predicts:** assumption 3 holds where it matters most. Under D1 B,
an edit of a body that keeps its signature compiles one unit; today it
compiled six here, and on a program that does not keep identities it would
compile the declaring unit and every unit that applies the functor.

### E9. Whether fingerprints keep the equality of type variables

**They do not, and neither do they keep the arity or the equality of a
signature's local type names.** This is a hole in the cache at
`78192dfd9`. A warm build takes from the cache a unit whose program no
longer type-checks.

**The smallest case:**
- `a.sml` is `fun f (x : 'a) = 0`, and `b.sml` is `val y = f 1.5`.
- Build with `--units --cache-dir cache`.
- Change `a.sml` to `fun f x = if x = x then 0 else 1`, and build again.
- `b.sml` is taken "from the cache ..., across a.sml changed", and the build
  succeeds. `--no-cache`, and a whole compile, reject `b.sml`: "type real does
  not admit equality".
- With a closure in place of `1.5`, the program built from the cache runs `=`
  on a function value, and prints 0.

**Fourteen cases** (`results/E9/README.md`, made by `e9.sh`): a value, a value
in a structure, a value's specification and a type's in a signature, and a
functor's parameter and result. Each type changes in one direction; the
value also in the other (`valrev`).
- **Seven are holes.** The warm build accepts what `--no-cache` rejects:
  - `type t` made `eqtype t`, or `type 'a t`, in a signature that a structure
    is then ascribed to;
  - a functor's parameter edited where an application sits inside another
    functor's declaration;
  - and so on.
- **One rejects a valid program.** A unit taken from the cache with the old
  `''a` makes a later, changed client fail.
- **The other six recompile,** saved by another check:
  - for an application that makes code, by `funat`;
  - otherwise by "names a.sml@... no path reaches".

**Where it is:**
- `fpTy` (`unitbasis.sml:216-224`) writes `'i` for a type variable,
  whatever its `eq`.
- A name local to a signature is `"local" ^ i` (`:233`), without its arity
  or its equality. `fpSigma` (`:297-299`) and `fpFunctor` (`:320-331`) write
  only how many bound and generated names there are.

**The fix,** thrown away (`patches/E9-fix.patch`, four hunks):
- `''i` for an equality type variable;
- each bound and generated name's arity and `=`;
- `UnitBasis.version` 6 to 7.

With it, every case agrees with `--no-cache`. `tests/incremental/run.sh`
gives the same results with and without it: 155 checks pass, and the same
five fail in both -- in four REPL scenarios, S40, S53, S54 and S57 (twice)
-- because they need `bin/rune-repl` beside the compiler.

Two scenarios are proposed (`results/E9/scenario.sh`). The base fails both;
the fix passes both:
- **S68:** `A.same` goes from `'a -> int` to `''a -> int`, and `b.sml`
  applies it to `1.5`.
- **S69:** a signature's `type u` becomes `eqtype u`, and a structure realises
  it by `real`.

**A second inconsistency, not a hole** (`results/E5/f1-edge`):
- `fingerprint` reads `!Elaborate.sigs` and `!Elaborate.funs`
  (`unitbasis.sml:351-352`), which after a unit's elaboration hold the unit's
  own declarations.
- So a unit that uses an earlier unit's `F` and then declares its own `F`
  records the usage under the earlier unit's identity, with its own `F`'s
  fingerprint.
- It could not be made into a wrong hit: the entry names the earlier
  functor by its place, and a remap refuses it. It is a spurious miss.
- It is F1's edge case: F1 must take the fingerprint at the unit's start,
  as `broken` does.

**What it predicts:**
- This is build-cache-issues.md's issue 16, and the first correctness fix
  of this roadmap. It goes into M2 with S68 and S69 and the version bump,
  ahead of everything that changes fingerprints.
- It is why M4's soundness checker exists. A fingerprint must change with
  everything the elaborator's typing reads; D9's S2 hashes the data whole,
  equality flags and arities with it.

### E10. How much of units exists for functors, and what B adds

**What would go** (`results/E10/lines.md`, counted at `78192dfd9`): about 520
lines that exist only because applying units elaborate bodies again.
- **`unitbasis.sml`,** about 225:
  - the re-parse;
  - the binders of issue 1;
  - `funat`;
  - the body's hash, the declaration's environment as a delta and the
    helpers that make it (`envDelta` and the `same*` functions,
    `:698-755`);
  - the pickle prefix's source hash and mode;
  - most of `rfunref` and `rfuninfo`.
- **`elaborate.sml`,** about 200: `copied`, `signatureTyped` with its
  helpers (`:540-691`),
  the replay of counters, and `FunInfo`'s extra fields.
- **`ast.sml`,** 75: `copyStrexp`.
- **Elsewhere:**
  - the issue-9 paths in `unitcache.sml`, `main.sml` and `repl/session.sml`;
  - in `unitfile.sml`, `mapFiles` stays: it also moves a unit's own file
    (S29). `renameFile` is already unused.

**What it removes the causes of:** issues 1, 9 and 15's functor trigger.
E10 confirmed that functors caused all three.

**Scenarios whose expectations change** (`results/E10/scenarios.md`):
- S8, S65, and S66 after the body changes: `c.sml` alone.
- S48: `profile.fun` alone (E8 measured six units today).
- S49 to S51: `a.sml c.sml`.
- S61: probably `a.sml b.sml`.
- S21: probably `c2.sml`.
- S55: its planted entry moves to `c.sml`'s.
- S56 keeps its expectation, now met by moving a unit's own file. S67 keeps
  its expectation with the version numbers moved.

**What B adds** (`results/E10/estimate.md`): about 950 to 2,200 lines, or
1,050 to 2,450 with a record per structure at run time (D3). The ranges are
driven by:
- the expansion, 350 to 800;
- D4's descriptors, 300 to 700;
- the elaborator, 150 to 300;
- Translate, 80 to 180.

M5 alone, without the expansion, is about 600 to 1,000. The templates are
`StrDynamic`/`StrExport` (`elaborate.sml:1467-1590`, `translate.sml:550-615`),
the `top` flag for locals, and Simplify's `copy` and `inlined`.
- A parameter type of arity 1 or more is already an opaque `Ty.Con (stamp,
  name, args)` in Mid (`ty.sml:30`). With casts at the boundary, a build in
  units needs no new kind of type.
- The expansion needs a substitution of type *names*, which `Ty.subst`
  (`ty.sml:454`) does not do.

**What it predicts:** assumption 3 holds for units, the cache and pickling.
About 520 lines go, with the three issues' kinds of bug, and the scenarios'
expectations shrink to the declaring unit. It does not hold for the
compiler as a whole: B adds more than it removes, net 530 to 1,930 lines
with D3's records per structure (430 to 1,700 without), most of them in the
middle end.

### E11. The literature and other compilers

Read for this roadmap:
- the papers on separate compilation in Standard ML and on representations
  across modules, with every DOI checked against Crossref;
- the code of SML/NJ, Poly/ML, MLKit, MLton, OCaml, GHC, rustc and Go;
- the hash functions of build caches.

*What the literature says* and *What the implementations do* give what it
found. What it changed in this roadmap:
- **Poly/ML has D1 B already**, inside one session: a functor is compiled
  once and expanded by its ordinary simplifier, with no budget. No compiler
  has shown such a function specialised to the speed of copies *across a
  cache*. G2's threshold is therefore Rune's own, with nothing to borrow.
- **The expansion must run on typed Mid** and specialise again after
  substituting types. OCaml's inliners cannot, because their IRs are
  untyped, and they leave generic equality and array accesses behind
  (OCaml's code; Tokuda, Sumii and Abe).
- **Two other compilers sort tags by name**, SML/NJ and Poly/ML. In Rune's
  single sequence, sorting moves `list` and `order`; D4 takes it, and changes
  the VM's C.
- **Corner (b) has a published alternative:** Dreyer and Blume's generalised
  functor signatures (D8 C).
- **Every compiler studied hashes data, not text,** and all but OCaml make
  it canonical first. OCaml's `.cmi` digest covers stamps and locations, and
  cuts off poorly (D9).
- **GHC's #18733** is a check M4 must make for recursive groups.
- **120 bits** is Go's choice for its build IDs, and 128 bits most
  compilers'. Linear lanes need a non-linear mixer before their hashes are
  hashed again (Broder; D11).

## Constraints

- **Six compilers build the compiler.** MLton, SML/NJ 110.99.9, `smlnj32`
  (31-bit `Int` and `Word`), SML/NJ's development release, Poly/ML and MLKit
  build Rune, and Rune builds itself; `make check-cross` wants the same bytes
  from all of them for every program it compiles. So the compiler's own code
  must compile on every host, and must not raise there: `Int` arithmetic
  that overflows raises on a host whose `Int` is 32 bits, and SML/NJ
  110.99.9 crashes on some uses of a word constant of 2^30 or more.
- **The hash is chosen for Rune at tier 2** (the owner, 2026-10-21). Its
  speed and correctness there decide it. Whether another host's build of
  the compiler computes the same values is for information (E6, D11).
  - A build whose hash differs must never mix its entries with another's.
    The probe in the cache and in the unit files sees to that.
  - Its own hash must not collapse: a 63-bit hash run on a 32-bit `Word`
    needs a path of its own.
  - On Rune, `Word` is 63 bits on every engine but the int64 VM, and
    `Word64` costs about twice as much a byte.
  - `lib/digest` and `lib/random` are not in the compiler's build file.
- **S42.** A program compiled whole and the same program built from its
  units' Mid (`--units --whole`) are the same bytes (`check-units`,
  `check-cross`). Whatever makes whole programs' code from functors must make
  it the same way in both.
- **A build in units and a whole compile accept the same programs.** A
  program's types cannot depend on how it is built.
- **Reproducible builds** (incremental M11): a fresh build and one through the
  cache give the same unit files; two sessions that load the same units in
  two orders write the same bytes (issue 13).
- **The cache is trusted by content.** An identity is a hash of a basis; a
  usage holds by a fingerprint. Whatever changes a fingerprint's value bumps
  `UnitBasis.version` and `UnitCache.version`, so an old cache is a miss and
  not misread (as performance M3 did, S67).
- **Copies of `P.hash`.** `tests/incremental/plant.py` must follow any change
  to it. The instruction set's fingerprint (`src/isa/reggen.sml:44`,
  `isagen.sml:51`) reimplements its first lane; changing that changes every
  bytecode file's fingerprint.
- **The frozen Basis** (`lib/cache`) is built by `make` and read by every
  compile in units. Its Basis units apply the Basis's functors
  (`RuneWordNFn`, `RuneIntNFn`, `RuneMonoVectorFn`, the IO functors and
  others): whatever a build in units does with functors, every program built
  in units does with the Basis's.
- **The VM's datatypes.** The C of the VM makes and takes apart `::` as two
  fields with nil's and `::`'s tags, `bool`, and `order` (`set_order`,
  `emit.c:100`, used at `:355` and `:475`), by today's tags. A scheme that
  renumbers constructors changes that C with them (D4).
- **`make check` is green at every commit**, with `test-incremental` for
  anything that touches the cache.
- **Budgets.** `tests/perf/*.budget` count bytecode instructions and cannot
  see the JIT; what the JIT gains is measured in machine instructions and
  cycles (`scripts/perf-cycles.sh`, `perf stat`), on a machine other work
  shares.

## The architecture

What the roadmap builds, if gate G2 says go. Each part names the decision
that chooses it.

### Types: once, from the signature (D1, D8)

A functor's body is elaborated once, at its declaration, against its
parameter (rule 86), and its annotations are kept: they are what Translate
compiles. Every application is typed as `typed` types one today
(`elaborate.sml:1412-1419`): the summary, realised by the match, with fresh
names for the generated datatypes (rule 54). `copied`, `signatureTyped` and
`Ast.copyStrexp` go, and with them the four corners of *Where we are*: a
body's overloading is settled in the body, a functor without a summary is
refused at its declaration, one of the two answers rule 89 allows (D8), and
nothing an argument
realises reaches the result except through the signature.

This holds in every mode. A whole compile, a build in units and the REPL
type the same program the same way.

### Code: a functor is a function (D1, D3)

A functor declaration is compiled, once, in the unit that declares it, into
a function from its argument to its result:
- **A structure that reaches a functor is a record at run time:** a tuple
  of its slots by name, as a dynamic module's are (D17's ABI,
  `translate.sml:550-615`; `docs/units.md:449-451`). It holds a value, a
  constructor used as a value, an exception, and a descriptor for each
  datatype specification (below). Unlike D17's ABI, which flattens
  substructures into one tuple, a substructure is a record of its own.
  - The record is made once, where the structure is declared or first
    passed, and shared by every application that takes it.
  - MLton's parameters hold a median of 2,993 value specifications through
    their substructures, and up to 124,485 (E2). Flat tuples built at each
    application would copy them.
- **The argument** is the argument structure's record, thinned to the
  parameter's signature where the match drops or reorders components (the
  coercion of F-ing modules and of OCaml's `Tcoerce_structure`).
- **Dynamic modules** take the same nested records in M7 (D3), so that a
  structure has one representation at run time.
- **The result** is the body's record. An application `structure S = F (A)`
  binds `S` to it; a client selects from it.
- **The parameter's types** are abstract in the body's code. Mid already
  has them as opaque `Ty.Con (stamp, name, args)` (E10), and a slot whose value is
  polymorphic crosses by `unsafe_cast`, as `StrExport`'s do
  (`translate.sml:604-608`): Mid is rank 1, and 76% of MLton's functors have
  a polymorphic value specification (E2). The expansion substitutes the
  argument's types for the parameter's type names, which needs a
  substitution of names that `Ty.subst` (`ty.sml:454`) lacks (D3).
- **Generativity.** Each call runs the body: new exceptions (`NewExn`), new
  `ref`s (rule 154). Datatypes' generativity is static, in the elaborator's
  fresh names per application; at run time a datatype's tags are constants
  whichever instance a value is of.
- **Equality** at a parameter's type is the generic walk (`poly_eq`), as for
  any type the compiler cannot see (D6); where an argument is known, the
  expansion gives the specialised code back.

### Datatypes across the boundary (D4, D5)

Two things a body compiled once cannot know, because they are decided by
declarations it does not see (`src/backend/rep.sml`; tags in declaration
order, `elaborate.sml:1174-1185`, while matching compares constructors by
name, `sigmatch.sml:271`, `:301`):

1. **A datatype the parameter specifies** is the argument's datatype, with
   the argument's tags and the argument's layout. The spec may list its
   constructors in another order, and a constructor whose argument is a type
   the spec leaves abstract may be flat in the argument (a pair) and boxed by
   the spec's reading.
   - **Tags by sorted name (D4).** Every datatype numbers its constructors
     by their names in sorted order, so a specification and its argument
     agree on every tag. `list` becomes `::` = 0, `nil` = 1, and `order`
     `EQUAL`, `GREATER`, `LESS`; the VM's C changes with them.
   - **A descriptor where the layout is open (D4).** For each constructor
     whose argument names an abstract type of the parameter, the argument
     carries its field count. It is a constant, which the elaborator works
     out when it matches the argument, emitted in the applying unit. The
     body builds and takes apart such a constructor by it. Specifications
     without such a constructor have no descriptor.
   - The expansion folds a known descriptor to constants, which gives back
     today's code exactly.
   - E2 counted both cases. Constructors in another order: 170 of MLton's
     356 applications that match a datatype specification, and 10 in
     ML-Yacc. A flat layout where the spec's is boxed: 8, all in HaMLet's
     grammar functors.
2. **A datatype the body declares** over a parameter's type (`datatype d = D
   of X.t`) has one layout in the function: `X.t` is abstract there, so `D`
   boxes its argument. A client that builds `S.D (1, 2)` sees a realised
   type, and today's `Rep` would make it flat. So a layout is fixed where
   the datatype is made, and carried in Ty's datatype table and in the
   unit's basis (D5), rather than worked out again from the types at each
   use:
   - an instance the function makes, at a call, has the declaration's
     layout;
   - an instance an expansion makes has code of its own, and may be laid
     out from its realised types. That keeps today's flat layouts in whole
     programs and within a unit (D2), and the layout is recorded with the
     instance for its clients.

### Copies: an expansion in the middle end (D1, D2, D13)

Whole programs keep copies, as the brief asks, but the copies are made in
Mid, not by the elaborator:
- **Where:** in a whole compile right after `MidCanon`, and in `--units
  --whole` right after `MidCanon.concat` (`main.sml:929-941`): the same pass
  on the same Mid, so S42 holds by construction, and the cache's entries stay
  shared between `--units` and `--units --whole`.
- **What:** at an application whose functor function and argument are known,
  the function's body is copied, its type parameters and opaque stamps
  substituted by the argument's types, the casts that substitution makes
  trivial removed, the descriptors folded, and the body's datatypes
  registered again as the instances the elaborator named. Then Simplify sees
  what static interpretation gives today: known calls, ground types,
  `eqByType`, inlining.
- **In a build in units, only within a unit** (D2): an application of a
  functor declared in the same unit is expanded, which makes no unit depend
  on another's body; any other application is a call. A program of one file
  is one unit, so its own functors keep today's code (E4). Expanding across
  units would make the applying unit depend on the body again, which is what
  this roadmap removes.
- **A budget (D13):** past a size or depth budget, an application stays a
  call. That is what keeps nested functors from blowing up in a whole
  program: static interpretation's Σ M^k copies become at most the budget,
  and the rest are calls of one function.

### Units without bodies (D1)

A unit that declares a functor exports its signature (as since M3), the
layout of its argument (the descriptor's shape), and its function as an
ordinary export. Nothing of the body: no body hash, no declaration
environment, no `allowPrim`, no signatures and functors in scope, no re-parse
of the source on load, no binders of the declaring unit's usages, no
`funat` usage, no functor sources in a unit's code (issue 9).

A unit that applies a functor depends on the functor's signature (its
fingerprint, for types) and on the declaring unit's exports (for linking),
like any other use of a name. A change to a body that keeps the signature
recompiles the declaring unit alone: its basis, so its identity, does not
change, and the applying units' code still calls the same export.

### Fingerprints by structure (D9, D10)

In three steps, each gated:
- **S0, streaming.** `fpTy` to `fpFunctor` feed a hasher state (`P.hash`'s
  four lanes, fed piece by piece) instead of concatenating strings. Every
  fingerprint keeps its value, bit for bit; the text and its garbage go.
- **S1, hashes of hashes.** A structure's or signature's fingerprint is the
  hash of its entries' names and their fingerprints; a functor's, of its
  parameter's and result's. Each is memoised by the binder's identity and the
  path (D10), as a usage's key is, so no text is longer than one entry.
- **S2, structural tokens.** The pieces fed are tags and numbers rather than
  text: the data hashed directly, which is the brief's question.

What each step must preserve, so that a fingerprint decides what it decided
(and what the other compilers' fingerprints do, *What the implementations
do*):
type variables numbered per scheme by first occurrence, with their
equality (E9); a type abbreviation's parameters; local names by their place
among the bound and generated names; cycles broken through `inProgress` and
the current unit's names not memoised; constructor tags; the realisations of
opaque types; the `known` and `prim` facts of values; the anchors of values
on and off; the order of `StringMap`. And S2's tokens must be prefix-free --
a tag for each constructor, a length for each list and string -- with no
stamps or counters, and recursive groups (`datatype ... and ...`,
`withtype`) hashed as GHC hashes them since its #18733.

### The hash (D11)

rx2fw (E6). It is two lanes of 63 bits, and every operation is mod 2^63.
`rotl (x, r)` is `x << r` or-ed with `x >> (63 - r)`.
- **Constants:** xxHash64's primes with bit 63 cleared. Mod 2^63 they are
  the same numbers, so each product is the low 63 bits of xxHash64's (the
  owner's suggestion, checked by E6):
  - P1 = `0x1E3779B185EBCA87`;
  - P2 = `0x42B2AE3D27D4EB4F`;
  - P3 = `0x165667B19E3779F9`;
  - P4 = `0x05EBCA77C2B2AE63`.

  They are built from 21-bit pieces at start-up, since SML/NJ 110.99.9
  crashes on some uses of a word constant of 2^30 or more.
- **Rounds:**
  - `A (a, x) = rotl (a + x * P2, 31) * P1`;
  - `B (b, x) = rotl (b + x * P4, 27) * P3`.
- **The ending, of each lane:** `h := h xorb (h >> 33); h := h * P2; h := h
  xorb (h >> 29); h := h * P3; h := h xorb (h >> 32)`.
- **Text of `n` bytes:**
  1. Start with `a = P1` and `b = P3`.
  2. For each whole group of seven bytes, take `x` as its little-endian
     56-bit value, packed in `Word`: `a := A (a, x)` and `b := B (b, x)`.
  3. If one to six bytes are left, do the same with their value.
  4. Then `a := A (a, n)` and `b := B (b, n)`.
  5. The digest is the two endings, 126 bits, written as 32 hex digits.
- **Combining:** the same rounds, with each value as `x`. A child hash is two
  values. The number of values takes the place of `n`.
- **Streaming:** the hasher keeps `a`, `b`, up to six pending bytes and the
  length. S0 feeds it; S1 and S2 combine with it.
- **By `Word`'s width,** chosen once at start-up:
  - where it is 63 bits, the loop as written. That is every Rune engine but
    the int64 VM.
  - where it is wider, every sum is masked to 63 bits before a rotation and
    every lane before a shift of the ending;
  - where it is narrower, the same function in `Word64`, its digits written
    a nibble at a time. That is MLton's build.
- **The probe:** `Pickle.probe` is the digest of a fixed text worked out once
  a run. It is chosen to reach every tail, every byte value and the largest
  word a step takes, and later the largest combined values. It goes:
  - into the cache's settings beside `Config.identity`, so that a compiler
    whose hash differs has a configuration of its own, and is told so;
  - into a basis's header, so that a unit file made by such a compiler is
    refused, not misread.

The constants are read into locals before a loop. Tier 2 otherwise checks a
global's initialisation, and a constant shift's range, at every use.
`P.hash`'s old algorithm stays in two places: in the instruction set's
fingerprint, which keeps its own copy of the first lane, and in M1's
benchmark.

### Division by a constant (D12)

- **Tier 2's emitter keeps a fact per register:** that it holds a constant,
  set by `INT`, by a `CONST` of an immediate, or by a `MOVE` from a register
  that holds one. Each fact lives within a run, and is dropped at a target,
  after an instruction that does not go on to the next, and when the
  register is written.
- **A division whose divisor is such a constant,** other than 0 and -1 at
  `int`:
  - takes no test of the divisor;
  - a power of two goes by shifts and masks;
  - any other value goes by a multiply-high with a magic number, and the
    floor's or the truncation's fix-up (Granlund and Montgomery; *Hacker's
    Delight* ch. 10). It runs on the 63-bit payload, and on 64 bits under
    `--int-bits=64`.
  - `x mod 16777213` becomes 15 straight-line instructions with no branch
    (E7).
- **`Simplify` folds** a constant divided by a constant, except where the
  division raises.
- **The encoders** gain the one-operand `imul` and `mul` on x86-64, and
  `umulh` on aarch64.

## Decisions

Each decision gives the options, what favours each, and the recommendation it
was written with. The owner took every recommendation on 2026-10-21. D1 B
holds subject to gate G2, the owner's go or no-go after M5 and M6. On a no-go,
D8's and D13's fallbacks apply (M3 closes the corners one by one, and M8 is
D13 D).

| Decision | Decided (2026-10-21, as recommended) |
|---|---|
| D1. How a functor is compiled, in each mode | B: once, as a function, in every mode; whole programs' copies made by an expansion in the middle end |
| D2. Expansion in a build in units | A: only of a functor declared in the same unit |
| D3. The functor's run-time interface | A: a record per structure, made once and shared; parameter types opaque, polymorphic slots cast; dynamic modules on the same records in M7 |
| D4. Datatypes a parameter specifies | A and D, without exceptions (the owner's direction): tags by sorted name; a descriptor only where a layout is open; M5 measures every option |
| D5. Datatypes a body declares | A: a layout fixed where the datatype or instance is made, and carried |
| D6. Equality at a parameter's type | A: the generic walk; the expansion specialises |
| D7. MLton's typing as an option | A: no |
| D8. The four corners | A: tests now; (b) refused at the declaration after E2; (a), (c), (d) closed by D1 |
| D9. How far fingerprints go | C: S0, then S1, then S2, each gated |
| D10. Memo keys for structures and signatures | A: the binder's identity and the path |
| D11. The hash | B: rx2fw, two 63-bit xxHash-style lanes (126 bits), for text and combining, with a probe in the cache; in M4 |
| D12. Division by a constant | A: tier 2 on both targets, every division, and `Simplify` folding constants |
| D13. Nested functors in whole programs | A: an expansion budget, past which an application is a call |
| D14. S42 and the cache's configuration | A: S42 by construction; the configuration unchanged; M7 gated by budgets |
| D15. `--typecheck-only` and `--serve` | A: no copies, now |
| D16. How it lands | A: every mode switched by one change, behind one flag until M7 |
| D17. MLton's default types | A: as they are |

### D1. How a functor is compiled, in each mode

**Decided: B** (2026-10-21), as recommended.

The brief: "when doing separate/incremental compilation rune should elaborate
the body of the functor once. when doing whole program compilation [it]
continues to make copies".

- **A. As the brief says it: functions in units, copies by the elaborator in
  whole compiles.** A build in units compiles each functor once and calls it;
  a whole compile keeps today's `copied`.
  - S42 then asks `--units --whole`, which starts from the units' Mid where
    the functor is a function, to give the bytes of a whole compile, where
    the elaborator made copies: the same stamps, the same function names
    (from the structure's path, `translate.sml:92-98`), the same match
    compilation, from a function compiled against a specification's tags.
    That cannot be made to hold, so S42 would be given up, and with it the
    test that holds builds from the cache to the whole compiler's output.
  - The elaborator keeps `copied` and `signatureTyped`, and with them the four
    corners of leniency, in whole compiles only: a program would type one way
    whole and another in units (*Constraints*).
- **B. Once, as a function, in every mode; the copies made by the middle end.**
  The body is elaborated once everywhere. Whole compiles and `--units --whole`
  run one expansion over Mid (*The architecture*), which gives whole programs
  their copies back; a build in units calls. **Recommended**, if gate G2
  finds the expansion's code as good as today's.
  - S42 holds by construction: the same pass on the same Mid.
  - The elaborator loses `copied`, `signatureTyped` and `Ast.copyStrexp`.
  - The brief's "whole program continues to make copies" holds in what it
    asks for: whole programs are compiled from copies.
- **C. As now.** Copies everywhere; nothing here but F1-F4 and division.
  Units keep the machinery of *What functors cost units and the cache*, and
  nested functors keep blowing up.

### D2. Expansion in a build in units

**Decided: A** (2026-10-21), as recommended.

- **A. Only of a functor declared in the same unit.** An application whose
  functor the same unit declares is expanded; any other is a call.
  **Recommended.**
  - The unit depends only on its own body, so no dependence on another unit
    comes back.
  - A program of one file is one unit, and keeps its own functors' code as
    today. That is where E4 found the large exposure: `barnes-hut`, `simple`,
    `mlyacc`, `fxp` and `hamlet` spend 22% to 85% of their cycles in their own
    functors' bodies, and an instance B makes costs six times the
    instructions and five times the cycles of a known, inlined call per
    small operation.
- **B. Never.** A build in units calls every functor. Simplest; it puts those
  programs' own functors behind unknown calls.
- **C. A and the functors of stable units** (the frozen Basis, a library
  that changes only with the compiler) expanded across units. A dependence
  on their bodies costs no recompile in a user's build.
  - It would keep `Word8`, `Word32`, `Int32` and the IO stack as fast in
    units as now. In units, a call of `Word32.+` takes 39 instructions
    today and 60 as an instance (E4).
  - It would also keep HOL4's `Table`-made tables, if HOL's tools were
    marked stable.
  - It brings back the dependence on bodies, and issue 9's paths, for those
    units only. *Later*, if G2's measures of the Basis and of HOL ask for
    it.

### D3. The functor's run-time interface

**Decided: A, with dynamic modules on the same records in M7** (2026-10-21), as recommended.

- **A. A record per structure, made once and shared.**
  - A structure that reaches a functor is a tuple of its slots by name, as
    D17's ABI orders them (`StrDynamic`), but with substructures as records
    of their own where D17 flattens them.
  - The argument is that record, thinned where the match drops or reorders
    components. The result is the body's record.
  - Parameter types stay opaque `Ty.Con`s in Mid, and polymorphic slots
    cross by `unsafe_cast`.
  - **Recommended:** it reuses `StrDynamic`'s code. MLton's large parameters
    are passed by one pointer. The expansion undoes it.
  - **Dynamic modules follow, in M7.** `_dynamic` and `_export` drop their
    flattening for the same nested records, so that Rune has one
    representation of a structure at run time, one coercion and one
    fingerprint scheme. A module loaded by `_dynamic` can then be passed
    straight to a functor's function, and a functor's result exported, with
    no repacking.
    - The cost: the ABI's fingerprint changes, so a module compiled before
      fails to load with `Dynamic.Mismatch`, cleanly, and `tests/dynamic` is
      updated. Nothing else uses dynamic modules today.
    - It costs dynamic modules nothing at run time: `StrDynamic` copies the
      slots into globals at load, so access afterwards is as before.
    - Not before G2: on a no-go there are no functor records, and flattening
      is fine for a module loaded once.
    - `_export` stops renumbering its datatypes' tags to the signature's
      order: with D4's sorted numbering, a module and its signature number
      alike.
- **B. A flat tuple per application,** substructures flattened, as
  `_dynamic` does. MLton's parameters, a median of 2,993 value
  specifications through their substructures (E2), would be copied at every
  application.
- **C. Higher kinds and rank-2 fields in Mid.** Not recommended now;
  *Later* at most.
  - **What it would add.** Mid's types are System F at rank 1, and `Ty.Gen`
    takes no arguments: a type variable stands for a type, not for a type
    constructor. A body compiled once over a parameter `type 'a t` with `val
    map : ('a -> 'b) -> 'a t -> 'b t` has, honestly, a type like `∀(t : * →
    *). {map : ∀'a 'b. ...} → ...`. That needs type-constructor variables
    applied to arguments, and record fields that are themselves polymorphic
    (rank 2; 76% of MLton's functors have one, E2). F-ing modules notes that
    only the core language's type constructors call for higher kinds.
  - **What it buys.** A fully typed function, which MidLint checks with no
    hole at the boundary, and an expansion that is type application rather
    than substitution of stamps and cancellation of casts.
  - **What it does not buy:** speed. An abstract type is a uniform value
    (`RAny`) either way, and after the expansion both A and C are ground.
  - **What it costs.** Kinds, applied type variables and polymorphic fields
    in Ty, handled by every pass that reads Mid's types: `midcanon`, `lift`,
    `workers`, `simplify` (its `eqByType` and `specialise`), `refs`, Lower's
    `repOfTy`, Mid's text form and its pickling (`UnitMid`), and MidLint.
    It does not answer the size of the records either.
  - **A gets most of its safety for little.** A parameter type is already an
    opaque `Ty.Con (stamp, name, args)` (E10), so MidLint checks a body
    against those stamps. Casts sit only where a slot enters or leaves a
    record, as in `StrDynamic`. After an expansion everything is ground and
    checked, and M6 adds one rule: an `unsafe_cast` left between two
    different ground types after an expansion is a bug.
  - C comes back if the expansion's bugs show that the casts hide too much.

### D4. Datatypes a parameter specifies

**Decided: A and D together, without exceptions** (2026-10-21), as recommended.

A body compiled once sees a datatype its parameter specifies only through
the specification. Two things about the argument's datatype are decided by
its declaration, which the body does not see (*The architecture*):
- **its tags.** Rune numbers constructors in declaration order, in one
  sequence for nullary and non-nullary alike, and matching compares
  constructors by name (`sigmatch.sml:271`, `:301`). So a specification
  `datatype t = A | B of int * int` matched by `datatype t = B of int * int |
  A` has `A` at 0 by the specification and at 1 in the argument.
- **its layout.** A constructor whose argument is a tuple of two or more is
  flat, any other boxed, decided from the declared argument type
  (`rep.sml`). A specification `C of info`, with `info` abstract, reads as
  boxed. An argument with `type info = int * int` lays `C` out flat.

E2 counted both. Constructors in another order: 170 of MLton's 356
applications that match a datatype specification, and 10 in ML-Yacc. A flat
layout where the specification's is boxed: 8, all in HaMLet's grammar
functors.

- **A. A descriptor slot per datatype specification:** for each
  constructor in the specification's order, its tag in the argument, and its
  field count where the specification leaves the layout open. A constant,
  worked out by the elaborator when it matches the argument, emitted in the
  applying unit. A match on a parameter's datatype costs a load and a
  compare more, or one indexed load through the inverse table; the expansion
  folds it.
- **B. Constructor functions in the argument** (Poly/ML's way: a test, an
  injection and a projection for each constructor). General; every match on
  a parameter's datatype becomes calls.
- **C. Static interpretation for such functors.** Functors whose parameter
  specifies a datatype stay copies in every mode: 172 of MLton's 254. Keeps
  the machinery this roadmap removes, for the functors that need it most.
- **D. Tags by sorted name for every datatype** (SML/NJ's and Poly/ML's way).
  A specification and its argument have the same constructors' names, so
  the same tags. It solves the tag order, not the layout: alone, it is not
  enough.
- **E. Coercions at the boundary** (Shao's representation analysis): a value
  is converted between the argument's layout and the body's. Deep values
  make it a copy of the data.
- **A and D together, without exceptions. The owner's direction
  (2026-10-21); recommended.**
  - **Tags:** every datatype's constructors are numbered by their names in
    sorted order, in one sequence as now, with no exception: a body compiled
    once knows an argument's tags from the specification alone.
  - **The descriptor** holds field counts only, and only for the
    constructors whose layout the specification leaves open (an argument
    that names an abstract type of the parameter). A specification with none
    has no descriptor, and its matches cost what they cost today, in a build
    in units as in a whole program. In the corpora that leaves HaMLet's 8.
  - **The built-in datatypes:**
    - `list` becomes `::` = 0, `nil` = 1;
    - `order` becomes `EQUAL` = 0, `GREATER` = 1, `LESS` = 2;
    - `bool` (`false`, `true`) and `option` (`NONE`, `SOME`) keep theirs.

    The VM's C changes with them: its list operations (`vm_cons`,
    `list_head`, `list_tail`), the JIT's `set_order` (`emit.c:100`), and every
    place the runtime makes or reads a list or an `order`.
  - **What else follows:**
    - every compiled unit's constants change, so the version keys are bumped
      and the frozen Basis is rebuilt;
    - the instruction budgets are measured again;
    - `_export` no longer renumbers a module's tags to its signature's order
      (`exportTags`, `elaborate.sml:1174-1185`), since both sides number
      alike;
    - exhaustiveness and redundancy messages keep listing constructors in
      declaration order, which the elaborator still has.
  - **Cost:** a sort of each datatype's names when it is declared or
    specified. That is microseconds against seconds of elaboration, and the
    descriptors' work mostly goes. At run time a tag's number should not
    matter: a switch is a jump table in any order, `nil` is told apart as an
    immediate, and `set_order`'s new mapping takes about as many
    instructions. M5 measures it.

M5 measures every option, with and without D, together with orderings that
make exceptions:
- declaration order;
- sorted;
- sorted with exceptions decided by constructor names, such as `nil, ::`
  and `LESS, EQUAL, GREATER` for any datatype with exactly those names.

The measures are compile time, run time at tier 2, and the cost of matches
on parameter datatypes in builds in units. If an exceptional ordering
proves faster, the owner decides again. Any such exception must be a rule on
constructor names, never on a type's identity. An argument that replicates a
datatype (`datatype 'a t = datatype list`) would otherwise carry tags the
specification's reading does not predict.

### D5. Datatypes a body declares

**Decided: A** (2026-10-21), as recommended.

- **A. Fixed where it is made, and carried.** A layout is decided once, and
  recorded with the datatype in Ty and in the unit's basis, for every client
  to use:
  - A datatype declared in a body gets its layout from its declared types.
    A parameter's type is abstract there, so the layout is boxed. Every
    instance the function makes, at every call, uses it.
  - An instance made by an expansion -- in a whole program, or within a unit
    (D2 A) -- has code of its own. It may be laid out from its realised
    types, and that layout is recorded with the instance.

  **Recommended.**
- **B. Worked out from the types at each use**, as today: a client's
  realised types would give a layout the function does not use. Wrong.

### D6. Equality at a parameter's type

**Decided: A** (2026-10-21), as recommended.

- **A. The generic walk** in the function; ground equality after the
  expansion. **Recommended:** it is what an abstract type gets everywhere
  else.
- **B. An equality function in the argument for each `eqtype` spec.** Faster
  in units for types whose equality is not the walk's; a larger interface,
  and nothing a whole program needs.

### D7. MLton's typing as an option

**Decided: A** (2026-10-21), as recommended.

The brief allows "mlton's more leninet typing as an option", "if it is
possible to retain leniency when elaborating functors only once w/o
introducing new complexity".

- **A. No.** **Recommended.**
  - MLton's typing is the copy's typing. Elaborated once, a body has no
    argument to type against; only its signature.
  - Of what MLton accepts, one part could be put into a summary: "`d` admits
    equality if `t` does", an equality that depends on the argument. The
    overloading and polymorphism leniencies cannot: they need the copy.
  - Nothing relied on it: performance M3 compiled MLton's sources, HOL4,
    the xc2 configurations and every suite after closing it. E1 and E2
    found nothing that relies on the corners left: no functor without a
    summary in any corpus, and no copy whose overloading was settled
    otherwise than as its class's default.
  - Unlike `--flex-records`, which chooses among contexts the Definition
    does not fix, rule 54 leaves nothing to choose.
- **B. Equality only, through the summary.** A dependency of a generated
  datatype's equality on the parameter's, under a flag. Some complexity in
  every place a summary is realised, for one corner of MLton's.
- **C. MLton's typing in whole compiles only.** Possible while whole
  compiles copy; with D1 B, impossible. A program would type differently in
  units (`--flex-records=program` is the one precedent, *Constraints*).

### D8. The four corners

**Decided: A** (2026-10-21), as recommended.

- **A. Tests now; each closed where it is cheapest.** **Recommended.**
  - M3 adds a test for each, (a) to (d), holding today's behaviour and
    marked with what the Definition wants.
  - (b) is closed in M3 by refusing, at its declaration, a functor whose
    result keeps a free type variable. That is one of the two answers rule 89
    allows (the other gives the variable an arbitrary monotype), and
    HaMLet's and MLKit's. E2 counted what it refuses: no functor in MLton,
    the benchmarks, the Basis, the libraries or Rune's sources.
  - (a), (c) and (d) close by construction with D1 B. If gate G2 says no,
    M3 closes them one by one in `signatureTyped` instead.
- **B. Close all four now in `signatureTyped`,** and again by construction
  later: the work done twice.
- **C. For (b), Dreyer and Blume's generalised functor signatures**
  (*What the literature says*): the body's open type variables become type
  parameters of the functor, instantiated at each application. One typing and
  one function, with one more type parameter; it accepts what the Definition
  refuses and MLton accepts.

### D9. How far fingerprints go

**Decided: C** (2026-10-21), as recommended.

The brief: "i wonder if we can instead directly hash the underlying datatype
w/o going via a pretty print."

- **A. S0 only:** the text is fed to the hasher in pieces, never built. Every
  fingerprint keeps its value. E5 built it:
  - 29% fewer instructions on MLton's build in units, and 18% fewer at tier
    2;
  - every unit file the same bytes;
  - but only by keeping `fpEnv`'s order of evaluation, on which a recursive
    datatype group's fingerprint depends.
- **B. S0 and S1:** hashes of hashes, memoised per structure and signature.
  Values change; the version keys are bumped.
- **C. S0, S1 and S2:** the data itself hashed, with tags and numbers for
  text. **Recommended**, each step gated by M4's soundness checker.
  - S0 is proven (E5).
  - After S0, F1 and F2, the usages at tier 2 still hash 1,248 MB of text,
    every byte of it signatures' and functors' environments: S1 removes it.
  - S2 hashes the elaborator's data whole, so a type variable's equality and
    a local name's arity are in by construction (E9's issue 16 was their
    absence).
  - S2 also gives a recursive group of datatypes one canonical value, where
    today's depends on which member is worked out first and costs spurious
    misses (E5).
  - Every compiler studied hashes data, not text, and all but OCaml make it
    canonical first (*What the implementations do*).

### D10. Memo keys for structures and signatures

**Decided: A** (2026-10-21), as recommended.

- **A. The binder's identity and the path,** as a usage's key already is
  (`fingerprintAt`, `unitbasis.sml:398-404`). **Recommended.** Stable across
  the units of a session and across sessions.
- **B. A stamp on every structure and signature.** The elaborator's `Env.Env`
  and `SigMatch.sigma` gain one, kept through realisation and pickling. More
  change for the same keys; rustc's `DefPathHash` is the same idea as A.

### D11. The hash

**Decided: B, rx2fw with its probe** (2026-10-21), as recommended.

The brief: "you should also look at faster hash functions". The owner ruled
on 2026-10-21 that speed and correctness on Rune at tier 2 decide it, that
the other compilers are for information, and that a hash whose values depend
on the size of `Int` and `Word` is acceptable if the cache records that
dependence (*The request*). E6 measured the candidates in three rounds; E7
measured today's hash with division by a constant.

- **A. Keep `P.hash`,** made faster by M1: 50 cycles a byte at tier 2, from
  171. No identity changes for it. Combining costs 693 instructions a value.
- **B. rx2fw: two 63-bit xxHash-style lanes, 126 bits, for text and for
  combining, with a probe of it in the cache; in M4** (*The architecture*).
  **Recommended.**
  - **Speed:** 13.9 cycles a byte and 52 a value combined at tier 2. That is
    3.6 times as fast as A with M1 by the byte, and 4 times by the value.
  - **The loop by `Word`'s width:**
    - unmasked where `Word` is 63 bits, as on every Rune engine but one, so
      tier 2 keeps rx2f's 49.5 instructions a byte;
    - masked to 63 bits where `Word` is wider, which is Rune's int64 VM;
    - in `Word64` where `Word` is narrower, as on MLton's build. There plain
      rx2f would collapse (E6).
  - **Correctness:** it passed every check of E6. A model in C agrees; every
    engine and every host but `smlnj32` agrees; it is clean on the corpus
    and on structured inputs, with an ideal bias matrix.
  - **In the compiler,** on top of M2, it takes MLton's build in units from
    770G to 551G cycles.
  - **The probe** (`Pickle.probe`, one digest of a fixed text worked out once
    a run, 45 µs) is put into the cache's configuration and into a basis's
    header. A compiler whose hash differs never takes another's entries,
    and says why.
  - M4 changes every fingerprint anyway, so the change costs no extra
    invalidation.
- **C. rx2f without the width paths,** relying on the probe alone. Rune's
  cost is the same, but MLton's build of the compiler would collapse its own
  hashes and take wrong entries from its own cache. Rejected.
- **D. rh2, two multiply-xorshift lanes.** About 11% cheaper a byte than B,
  and fine for text, but its lanes collide when whole 63-bit child hashes
  are combined (E6). It could hash text while B's round combines, which
  makes two functions for 11% of a cost that is no longer the larger part.
- **E. The first round's four 30-bit lanes** (mix30w), 120 bits, the same
  value on every host, `smlnj32` included. About 4 times B's cost a byte at
  tier 2. It was recommended before the owner's ruling, which removes its
  reason.
- **F. SHA-256** from `lib/digest`, 256 bits: strong against an adversary
  (issue 7), at 6.9 MB/s at tier 2. It is for a cache shared between people
  who do not trust each other, which Rune's is not. *Later*.

The width: two lanes cost about 10% more than one, cover each other's
structural collisions, and put an accidental collision among a million
identities far below anything measurable. One lane, 63 bits, would be about 5
× 10^-8.

What B costs beyond its code:
- `UnitBasis.version` bumped (the probe in a basis's header), and
  `UnitCache.version` and `UnitMid.version` with the new hash. Not
  `UnitFile.version`, whose format does not change; bumping it makes the
  runtime refuse the REPL's units.
- `tests/incremental/plant.py`'s copy of the hash rewritten, about 30 lines
  of Python, with `--basis-probe` for S70.
- The instruction set's fingerprint keeps its own copy of today's first lane
  (`isagen.sml:51`, `reggen.sml:44`).
- **`smlnj32`** gets a hash of its own: its `Word64` is wrong. The probe
  keeps its cache apart from everyone else's, so nothing is mixed.
  - Rune's compiler sources include `lib/basis/runtime.sml`, so the compiler
    built in units keeps its units' identities. `check-cross`'s `rune-units`
    would differ for `smlnj32`, and leaves it out (E6's runner patch).
  - `smlnj32`'s whole programs still agree.
  - The alternative is 63-bit arithmetic in `Int` limbs for `smlnj32` alone.
    That is the kind of compromise the ruling rejects.

### D12. Division by a constant

**Decided: A** (2026-10-21), as recommended.

- **A. Tier 2 on x86-64 and aarch64, for every division by a constant, and
  `Simplify` folding a constant divided by a constant.** `div`, `mod`,
  `quot` and `rem` at `int` and at `word`; no test of the divisor when it is
  a constant other than 0 (and, at `int`, -1); a power of two by shifts and
  masks; any other by a multiplication and a shift. **Recommended.** E7's
  prototype took 30% of the cycles out of MLton's build in units and 0.2% of
  the bootstrap's instructions, and passed 200,000 checks against the C
  primitives. The fact that a register holds a constant must follow `MOVE`
  and `CONST`, not only `INT`.
- **B. x86-64 only.** aarch64 has `smulh` already and needs only `umulh`,
  so doing both costs little more than the emitter's code.
- **C. In the middle end**, as a multiplication by a magic number in the
  bytecode. The bytecode has no multiply-high, and the interpreter would pay
  more for three operations than for one.

### D13. Nested functors in whole programs

**Decided: A** (2026-10-21), as recommended.

- **A. An expansion budget.** An application is expanded while the copies
  made below it stay within a budget of Mid nodes (and a depth); past it, it
  calls the function. With a default measured by M8 and a flag to change
  it. **Recommended:** linear in every mode, the Σ M^k copies bounded.
- **B. Expand everything,** as static interpretation does now: the code of a
  whole program grows as Σ M^k (E3).
- **C. Memoise applications to the same argument.** Two applications of `F`
  to the same `A` would share their code; rule 154 still wants new
  exceptions and `ref`s for each, so they share functions but not their
  state. A refinement of A, later.
- **D. If G2 says no:** M5's functions kept for the applications past the
  budget alone, static interpretation below it. Without functions, nothing
  can bound static interpretation's Σ M^k copies. It keeps the machinery of
  both, for the programs that nest deepest; the brief's "Rune should not blow
  up either" then costs that.

**The budget, measured (M8, 2026-10-25).** The default stays 1,000,000 Mid
nodes for a top-level application and the applications in its copies,
counted as the sizes of the functions copied: about twice the largest that
a program known needs, measured whole with `--pass-stats=expand` at M7's
tip. MLton's 606 files need 508,928 (`structure Main = Main (...)`, 400
applications expanded), the benchmark set 29,322 (`fxp`), the bootstrap
1,405; none of them has an application past the budget, so the default
changes nothing they compile. The reading of "linear": within the budget a
compile is linear in the copies it makes, and past it the budget bounds the
copies, so that a compile grows no faster than the applications static
interpretation would elaborate (Σ M^k), which is also the number of
structures in the program's environment. On `funnest` (functors nested `D`
deep, each body applying the one below `M` times, 8 bindings a body):
at `M` = 2 every application is copied up to `D` = 12 (8,191 applications,
507,839 nodes), the compile growing with the applications as
applications^1.07 whole and ^1.05 in units and in `--units --whole` from
`D` = 8 to 12; at 13 the copies stop at the budget (16,128 of 16,383
expanded, 999,936 nodes), and from 13 to 14 the compile grows as
applications^0.67. At `M` = 1, from `D` = 8 to 16, applications^1.09 whole,
^1.22 in units and ^1.24 in `--units --whole`: the copies are linear (31
nodes a level), but the program's interface is not. `F`k's result holds
`N1`, `F`(k-1)'s, so its signature is k levels deep, and the functors'
signatures together, as the REPL would print them, are 1 + 2 + ... + D: a
compile grows with D^2 however it is made. Measured at every depth from 8
to 16 and at 24, 32 and 48: a whole compile adds 0.79M instructions a
level from 8 to 16, 1.29M from 16 to 32 and 1.97M from 32 to 48; the
elaboration of `F`k is 63k + 42 nodes (`--pass-stats=elab`), its
application `N1 = F`(k-1)`(X)` realising the k-1 levels of the summary;
the unit's basis is 23,477, 73,088, 252,568 and 551,055 bytes at D = 8, 16,
32 and 48 while its code grows by 2,722 bytes a level; and a compile in
units costs about 300 instructions a byte of basis throughout (E3 found the
same, x 1.10 a level at `D` = 16). It is the size of what the units of such
a program say, not noise; a basis that names a signature written before,
and an instantiation that shares what it does not rename, would make it
linear in the applications. `funapp` (one functor applied 80 to 320 times)
grows as applications^1.01 to ^1.02. `tests/perf/compile-funnest*` and
`compile-funapp*` hold these as budgets with `scale` lines (M8).

### D14. S42 and the cache's configuration

**Decided: A** (2026-10-21), as recommended.

- **A. S42 by construction; the configuration unchanged; M7 gated by budgets.**
  With D1 B, a whole compile and `--units --whole` run the same expansion on
  the same Mid. M7 cannot keep performance M3's gate that the whole
  program's output is the base's bytes, since the code is made another way:
  it is held to pre-registered budgets of instructions and of run time
  instead (G2, M7). **Recommended.**
- **B. `--whole` in the configuration**, entries no longer shared. Needed only
  with D1 A.

### D15. `--typecheck-only` and `--serve`

**Decided: A** (2026-10-21), as recommended.

- **A. No copies, now.** Typing comes from the summary; a copy only feeds code,
  which these modes do not make. `apply` takes `typed` whenever no code is
  wanted, where a summary exists. **Recommended**, early, in M3: the IDE's
  checks stop elaborating bodies again.
  For MLton's sources, that is the 23.9 s of 41.8 s of elaboration that the
  copies take (E3).
  - Until (a), (c) and (d) close, `--typecheck-only` then follows the
    Definition in those corners while a compile does not. E1's programs
    would be refused by the check and accepted by the build.
  - That disagreement is a temporary exception to *Constraints*' rule that
    every mode accepts the same programs, until M7 (or M3, on a no-go)
    closes the corners. It is written down with the corners' tests, which
    pin each mode's behaviour in the meantime. It touches only the corners'
    programs: on MLton's sources, the copies' overloading settles where the
    body's own defaulting does (E2).
- **B. Wait for M7.**

### D16. How it lands

**Decided: A** (2026-10-21), as recommended.

- **A. One change, behind one flag until M7.** M5's and M6's prototypes run
  behind `--functors=functions`, which switches whole compiles, builds in
  units and `--units --whole` together; M7 makes it the only way and removes
  the flag. **Recommended:** a flag per mode would break S42 between them.
- **B. Units first, whole programs later.** S42 broken in between.

### D17. MLton's default types

**Decided: A** (2026-10-21), as recommended.

The owner asked whether MLton's build should use `-default-type int64
-default-type word64` anyway (E6).

- **A. Leave MLton's build as it is.** **Recommended.**
  - With D11 B, its hash agrees with Rune's already, and its caches are
    shared.
  - It compiles every program of `check-cross` to Rune's bytes today.
  - 64-bit defaults would cost it 24% to 32% of its cycles on MLton's 606
    files in units, by more elaboration and a full 7 GB heap.
- **B. Build it with `-default-type int64 -default-type word64`.**
  - Its `Int` and `Word` would then be closer to Rune's 63 bits than to 32,
    so an `Overflow` that Rune does not raise is less likely in MLton's
    build. None has been found.
  - It builds cleanly. `check-cross` passes, 586 of 586, and caches are
    shared both ways.
  - The cost is the 24% to 32% above, for nothing measured.
  - It is the four MLton lines of the Makefile (rune, runedoc, runeopt,
    runeisa), through an `MLTONFLAGS`, and a line in `docs/building.md`.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check`
green. A milestone that touches the compiler's sources also passes the host
builds and `make check-cross`; one that touches the cache, the units or the
fingerprints passes `make test-incremental` and MLton's S44 to S48
(`tests/incremental/mlton.sh`); one that touches the JIT passes
`make test-register-jit` (whose `jit` oracle compares the tiers) and the
aarch64 build under qemu.

The milestones form three tracks. None waits for another, except where a
milestone says so:
- **H, hashing:** M1, M2, M4.
- **T, typing:** M3.
- **F, functors:** M5, M6, gate G2, M7, M8.

M9 closes all three. The sizes are lines of code and tests.

### M1. Tier 2 divides by a constant (H; M, about 400 C and 200 SML of tests)

* **What:**
  - an encoder of the one-operand `imul` (and `mul`) on x86-64, with its
    tests in `tests/register/x64_test.c` (against the manual's encodings),
    and `umulh` on
    aarch64, where `smulh` exists;
  - a fact in the emitter that a register holds a constant, put there by
    `INT`, by a `CONST` of an immediate or by a `MOVE` from a register that
    holds one, kept within a run and dropped at a target or another write
    (the flags peephole of `compile.c` is the pattern; E7 found the `MOVE`
    and the `CONST` needed);
  - for `int_div`, `int_mod`, `int_quot`, `int_rem`, `word_div` and
    `word_mod` by a known constant other than 0 and -1: no test of the
    divisor; a power of two by shifts and masks with the floor's fix-up; any
    other by a multiplication by a magic number and shifts (Granlund and
    Montgomery), with the floor's or the truncation's fix-up, on the 63-bit
    payload, and on `--int-bits=64`;
  - `Simplify.fold` folds a constant divided by a constant, raising nothing
    where the division would raise;
  - tests: every operation by a table of constant divisors, on edge and
    random dividends, against the same operation through a divisor the
    compiler cannot see, at every `--jit` and on both targets;
  - **the test case kept:** a program that runs `Pickle.hash`'s algorithm over
    a large string, in the cycles benchmarks (`scripts/perf-cycles.sh`) with
    a row of `docs/performance.md`, so that it outlives F1 to F3.
* **Why first:** the brief's reason. The test case is MLton's 606 files built
  in units, where `P.hash` was 36% of the cycles at performance M10's tip.
  M2 and M4 take that away, and M4's rx2fw takes the division out of hashing
  altogether. M1 is measured on the test case before M2 lands. It keeps its
  value for every other division by a constant: 2.5M in the bootstrap
  (E7).
* **Done when:**
  - E7's measures hold or are beaten: MLton's 606 files in units at tier 2
    in at most 0.72 times the base's cycles, and `Pickle.hash` in at most 50
    cycles a byte, at a low load;
  - the tests pass on x86-64 and aarch64;
  - the bootstrap's machine instructions do not rise.
* **Touches:** `runtime/register/jit/` (`emit.c`, `compile.c`, `asm*.c`,
  `x64.h`), `src/core/simplify.sml`, jit.md's *Left by the performance plan*.

### M2. Units that cost less, with no output changed (H; S, about 300)

* **What:**
  - **issue 16 first** (E9), a correctness fix:
    - `fpTy` writes a type variable's equality;
    - `fpSigma` and `fpFunctor` write each bound and generated name's arity
      and equality;
    - scenarios S68 and S69;
    - `UnitBasis.version` bumped.
  - counters of the bytes hashed, by phase and call site, behind
    `--pass-stats` (E5's patch made permanent);
  - S0: the fingerprints fed to a hasher state, never built as text
    (*The architecture*);
  - F1: `export`'s `binding` through `fingerprintAt`, with a test of the edge
    case E5 found (*E9*): the fingerprints of `sig` and `fun` usages are taken
    at the unit's start, as those of values already are (`position` keeps
    the start's signatures and functors as it keeps `Env.session`), so that
    usage and binding agree. F1 is then byte for byte a no-op wherever
    nothing is declared again;
  - F2: the identity `export` works out given to `load`, and its twin in the
    cache: an entry keeps its basis's identity, so that a warm build does not
    hash each basis twice (481.5 MB with no edit, E5);
  - the link made linear (E3's patch): `keyId` without `StringMap.numItems`,
    and each unit's exports and globals sorted once;
* **Why now:** no output changes, so each is held to the strongest gate there
  is, and the counters measure everything after.
* **Done when:** unit files byte for byte the same as before, but for issue
  16's fix and the edge case; cache entries the same but for the identity
  they now keep (`UnitCache.version` bumped); MLton's build in units as
  E5 predicts: 38% fewer instructions with MLton's build of Rune, and 28%
  fewer at tier 2, against the base.
* **Touches:** `src/util/pickle.sml`, `src/driver/unitbasis.sml`,
  `src/driver/unitcache.sml`, `src/driver/pipeline.sml`,
  `src/backend/link.sml`, `src/util/pass.sml`, `tests/incremental`.

### M3. Typing that follows the Definition (T; S, about 300)

* **What:**
  - `docs/language.md:28` and `:154` made true: what Rune does since
    performance M3, and the four corners as known deviations until they close;
  - D15: `--typecheck-only` and `--serve` make no copies;
  - tests for (a) to (d), each with what the Definition requires
    (`tests/errors` for what it rejects). Until the corners close, each test
    pins what each mode does: a compile keeps today's behaviour, marked as a
    deviation, and `--typecheck-only` follows the Definition (D15). So the
    change is visible when a corner closes;
  - (b) closed: a functor declaration whose result keeps a free type
    variable is refused, one of the two answers rule 89 allows (D8); E2
    found none in any corpus;
  - the `_int64` in messages printed as `Int64.int`;
  - an entry in [sml97-extensions.md](sml97-extensions.md) for MLton's typing
    of functor applications: what it accepts, what Rune does, and D7.
* **Done when:** the tests pass; MLton's sources, HOL4, the xc2
  configurations and every suite still compile, or what (b) refuses is listed
  and accepted by the owner.
* **Touches:** `src/elab/elaborate.sml`, `docs/language.md`,
  `tests/errors`, `tests/lang`.

### M4. Fingerprints by structure (H; M, about 600)

* **What:**
  - S1, then S2 (*The architecture*, D9), memoised by the binder's identity
    and path (D10);
  - first, the hash of D11, rx2fw, with its probe (E6's patches):
    - three loops chosen once at start-up by `Word.wordSize`, not E6's two:
      - exactly 63 bits (Rune): the loop without masks. The masks are all
        ones there, so the function is the same, but tier 2 keeps them, at
        3.8% a byte and 13% a value combined (E6). E6's prototype masked on
        Rune too;
      - wider (Rune's int64 VM, MLton with `-default-type word64`): masked
        to 63 bits before each right shift;
      - narrower (MLton's default build): the same function in `Word64`;
    - the narrow path for combining as well as for text. E6's prototype has
      `Word64` only for text, so S1 and S2's combining needs it before they
      land. Without it, MLton's default build would give other values, or
      collapse as plain rx2f does on a narrow `Word`. A test compares the
      combine digests of MLton's default build with Rune's;
    - the probe in the cache's settings and in a basis's header, with
      `--explain-rebuild`'s message for a cache made by a compiler whose
      hash differs;
    - `tests/incremental/plant.py` following the hash, with
      `--basis-probe`, and scenarios S70 and S71;
    - `check-cross`'s `rune-units` without `smlnj32` (E6's runner patch);
    - the instruction set's fingerprint left as it is;
    - `UnitBasis`, `UnitCache` and `UnitMid`'s versions bumped, not
      `UnitFile`'s.

    On top of M2, rx2f took MLton's build in units at tier 2 from 770G to
    551G cycles, and `unit-usages` from 89 s to 40 s;
  - a recursive group of datatypes (`datatype ... and ...`, `withtype`) given
    one canonical value, whichever member is worked out first (E5; GHC's
    #18733);
  - a look at `export` beyond hashing. After S0, F1 and F2, 65 to 75 s of it
    on MLton's build is not hashing, presumably pickling 220 MB of bases
    (E5);
  - `UnitBasis.version` and `UnitCache.version` bumped, and a scenario that an
    old cache is a miss (as S67);
  - **a soundness checker,** kept as a tool (`tests/incremental/`): over
    `mutate.py`'s edits and the scenarios, for every usage key, a change of
    the old fingerprint must be a change of the new one; the refinements
    intended (a recursive group's canonical value, which removes spurious
    misses) are listed; the checker itself is tested by plugging in a
    deliberately weak hash, which it must catch, and by undoing issue 16's
    fix, which it must find.
* **Done when:**
  - `unit-usages` and `unit-export` together under 30 s on MLton's 606 files
    at tier 2. They were 174 s and 148 s at performance M10's tip. E5 at
    `78192dfd9` found 137.4 s and 115.3 s, and 89 s and 74 s after S0, F1
    and F2;
  - hashing under 5% of that build's cycles;
  - the incremental scenarios unchanged in what they compile again and what
    they take from the cache;
  - **gate G1:** MLton's 606 files compiled in units within 1.5 times their
    whole compile, units-fixes.md's measure; or the gap that remains
    attributed, with what would close it.
* **Touches:** `src/driver/unitbasis.sml`, `src/util/pickle.sml`,
  `tests/incremental`.

### M5. Prototype: functors compiled once (F; L, about 1,000)

* **What:** behind `--functors=functions` (D16), in every mode:
  - the body elaborated once and its annotations kept; every application
    typed by `typed`;
  - the functor compiled to a function with D3's interface, D4's tags by
    sorted name and descriptors, and D5's layouts;
  - D4's numbering behind its own flag: declaration order, sorted, and
    sorted with exceptions decided by constructor names (`nil, ::` and
    `LESS, EQUAL, GREATER`), with the VM's C for `list` and `order`
    following the numbering chosen;
  - applications as calls; no expansion yet, so a whole compile calls too;
  - units that declare a functor export its function and no body; units
    that apply one depend on its signature;
  - `repOfTy` keys `array`, `vector` and `ref` by stamp, not by name, since
    abstract parameter types now reach Lower.
* **Measures** (the evidence G2 rests on):
  - compile time and memory: MLton's 606 files, whole and in units, cold and
    warm; the bootstrap; E3's generated programs;
  - what an edit of a body compiles again: S48 and E8's replay;
  - the run-time cost of calling: the compiler built in units, MLton's
    benchmark set, E4's Word benchmark, and HOL4's kernel work built in units
    as HOL4 on Rune builds it (its `Table`s), against today's units;
  - **every option of D4:**
    - A alone, A and D, and D's three orderings;
    - for each: compile time (MLton's files, whole and in units, and the
      bootstrap);
    - run time at tier 2 (the bootstrap, MLton's benchmark set, HOL4's
      kernel work);
    - the cost of matches on parameter datatypes in builds in units
      (MLton's AST functors);
    - for the orderings, whether `list`'s and `order`'s numbering moves
      anything. If an exceptional ordering is faster, the owner decides
      D4's numbering again;
  - the lines it adds, and the lines M7 would remove.
* **Done when:** the measures are written down; `make check` passes with the
  flag off, and the suites pass with it on except where the expansion is
  needed for speed.

### M6. Prototype: the expansion (F; M, about 800)

* **What:** the pass of *The architecture*, behind the same flag:
  - on Mid after `MidCanon`, after `MidCanon.concat`, and, in a build in
    units, on a unit's own applications of its own functors (D2 A);
  - type and stamp substitution;
  - casts made trivial removed;
  - descriptors folded;
  - datatype instances registered again and laid out from their realised
    types (D5);
  - D13's budget;
  - a rule for MidLint after the expansion: no `unsafe_cast` left between two
    different ground types (D3).
* **Measures:** with the flag on and every application expanded, against
  today's static interpretation, machine and bytecode instructions of the
  bootstrap, HOL4's kernel work, MLton's benchmark set, the examples and E4's
  Word benchmark; the code's size; S42.
* **Done when:** the numbers are written down for G2.

### Gate G2: go or no-go (the owner's)

Pre-registered, from M5 and M6:
- the expansion's code within 1% of today's whole-program instructions on
  the bootstrap, HOL4's kernel work and MLton's benchmark set (geometric mean),
  and no program of the set worse by more than 5%;
- S42 holds with the flag on;
- a build in units at least as fast as today's, cold and warm, on MLton's
  606 files;
- an edit of a body that keeps its signature compiles the declaring unit
  alone;
- the run-time cost of a build in units against today's units, written
  down, for the owner to weigh. E4 bounds it:
  - the compiler built in units, about 3% more cycles;
  - the Basis's functors called across units, 54% more instructions a
    call;
  - HOL4's kernel work as HOL builds it in units, through its `Table`s, to
    be measured by M5;
- a program's own functors within one unit as fast as today (D2 A);
- the lines M7 removes against the lines M5 and M6 add.

If G2 says no, M3 closes (a), (c) and (d) one by one (D8), and the flag is
removed.

**The evidence (2026-10-25).** M5 and M6 were built behind
`--functors=functions` (with `--datatype-tags=sorted-x` and
`--functor-budget`, default 1,000,000 Mid nodes). *Today* is this branch's
tip with the flag off; *M6* the prototype with it on. Instruction counts
are the claims; cycles were taken beside other sessions' work.

| Criterion | Measured | Holds? |
|---|---|---|
| Whole-program instructions within 1%: the bootstrap | 15.575G against 15.580G (1.000); bytecode 1,493.4M against 1,493.6M | yes |
| ... HOL4's kernel work | not measured: HOL4 builds through the REPL and `Compiler.compile`, which the prototype does not switch; a functor-heavy stand-in (`OrdMap`'s functor applied to a key) runs 1.000 | not measured |
| ... MLton's benchmark set, geometric mean | 0.984 (bytecode 0.997), 35 programs | yes |
| No program of the set worse by more than 5% | the worst is `simple`, 1.014 | yes |
| S42 with the flag on | 354 of 354 programs of `tests/lang` and `tests/perf`, the compiler, and MLton's 606 files: `--units --whole` is the whole compile's bytes | yes |
| A build in units at least as fast as today's, MLton's 606 files at tier 2 | `--no-cache` 0.953 of today's instructions; cold 0.970; warm 0.966; peak 3.56 GB against 3.61 | yes |
| An edit of a body that keeps its signature compiles the declaring unit alone | S48: 1 unit and 105.4G instructions, against 6 and 315.7G; S8, S65, S66 the declaring unit alone; S45, a leaf, 105.0G against 304.4G | yes |
| The run-time cost of a build in units against today's units | the compiler built in units 1.018 (bytecode 1.031); the Basis's functors called across units: E4's Word benchmark 1.96, `wordcount` 1.045, the benchmark set's I/O programs up to 1.46 (`checksum`); HOL4 not measured (the stand-in 1.77) | written down |
| A program's own functors within one unit as fast as today | the benchmark set in units: geometric mean 0.9996; the programs that are mostly their own functors as fast or faster (`mlyacc` 0.82, `tyan` 0.72); the seven over 5% slower are slow in the Basis's functors across units (`checksum`'s profile) | yes for a program's own; the Basis's across units cost up to 1.46 |
| Lines M7 removes against lines M5 and M6 add | M5 and M6 add 2,248 and remove 184 (the expansion, `expand.sml`, 938); M7 would remove about 520 and the flag's branches, about 60; the expansion stays | written down |

What the prototypes found against the roadmap:
- **Whole compiles are not faster.** E3 expected half of MLton's
  elaboration to go; it went 7%. MLton's whole compile runs 0.968 of the
  instructions, but the collector takes 5 s more: the records and the
  expansion's markers allocate 7% more. The gain is in builds in units:
  S45 and S48 cost a third of today's.
- **D2 A leaves the Basis's functors slow across units**: `Word8Array`,
  `PackWord32Little` and their like are made by functors of other Basis
  units and called through records, where today's copies are inlined
  (the Word benchmark 1.96, M5 found 1.98, E4 had predicted +54%). D2 C,
  expanding the stable Basis's functors across units, answers it; it is
  under *Later*.
- **Simplify's inlining of functions called once** pulled every functor's
  function back into its one call, with no budget; the prototype never
  inlines one, and the expansion does it within D13's budget.
- **D5's layouts** had to be carried through `MidCanon` and a unit's Mid
  too, not only Ty's table and the basis: a datatype entered again there
  was laid out anew, which miscompiled until fixed.
- **D4's sorted-with-exceptions numbering is not needed**: plain sorted
  costs nothing measurable (the compiler 0.15% slower, the benchmark set
  equal), and renumbering `list` and `order` moves nothing.
- E2 counted the shapes the expansion meets but not its corners: a typed
  pattern's lambda bound to a polymorphic value, applications inside a
  `local` block, and an open constructor bound to a polymorphic variable.
  Each is in `tests/lang/mod.functor.functions_expand`.

**Inline functors (the owner's ruling, 2026-10-25).** In place of D2 C, the
owner asked for a way to mark functors to be copied in every unit that
applies them -- the Basis's, and HOL4's `Table` -- measured with and
without, and ruled: go at G2 if that brings performance back to today's.
Built, behind the same flag: `inline functor F ... end` in a library's
build file (all 19 of the Basis's functors are marked in
`lib/basis/library.build`) and `--inline-functor=F` for a program; a marked
functor is still compiled once to a function, its Mid goes into its unit's
basis, and every unit that applies it expands it, recording a usage `inl F`
that holds by the body and what it relies on. The REPL and `Compiler.compile`
honour the flag, so HOL4 was built under it. Ratios to today in the same
mode, bytecode instructions [machine instructions]:

| | flag, units | flag and marks, units | flag and marks, whole |
|---|---:|---:|---:|
| E4's Word benchmark | 1.459 [1.963] | 0.977 [0.966] | 0.970 [0.952] |
| `checksum` | 1.148 [1.462] | 0.920 [0.865] | 0.892 [0.782] |
| `fxp` | 1.094 [1.210] | 0.998 [1.017] | 1.000 [0.992] |
| `wc-input1`, `wc-scanStream` | 1.181, 1.190 | 0.982 [0.973], 1.000 [1.002] | 1.000 |
| `hamlet` | 0.989 [1.012] | 0.989 [1.014] | 1.000 [0.968] |
| `ray`, `peek` | 1.080, 1.015 | 0.994 [0.990], 1.000 [1.000] | 1.000 |
| `wordcount` | 1.006 [1.041] | 0.998 [1.079] | 1.000 [0.999] |
| the `Table` stand-in (`--inline-functor=OrdMapFn`) | 1.477 [1.773] | 1.000 [1.000] | 1.000 |
| the benchmark set (35), geometric mean | 1.004 [0.994] | 0.981 [0.961] | 0.997 [0.983] |
| HOL4's kernel work (machine; `--inline-functor=Table`) | 0.976 | 0.976 | |
| HOL4 built to `hol.state` (all processes) | 1.000 | 0.999 | |

- What is left above today is in machine instructions in units only:
  `fxp` 1.017, `hamlet` 1.014 (the collector's minor pass, the flag's and
  not the marks'), and `wordcount` 1.079 on an empty input: a unit of a
  marked functor keeps its function beside the copies, and the set's units
  are 1.29 times today's bytes, which a short run pays to load.
- What the marks cost to compile: the benchmark set in units 1.090 cold and
  1.073 warm; MLton's 606 files in units still 0.963 (`--no-cache`), 0.969
  cold, 0.967 warm, and an edit of a leaf or of a functor's body 0.345 and
  0.331.
- Fixed on the way: an expansion copied a hidden datatype of a recursive
  group once per application where the group's visible type was one
  instance, so code built and matched two copies (`fxp` under `--lint`);
  each is now copied once for what the application makes of the names it
  reaches (`tests/lang/mod.functor.functions_expand`).
- Found in today's REPL:
  - **through the cache, with the flag off:** after `use` of two files
    and an edit of the body of a functor one applies, using both again
    printed the old value (45 where 135 is right): the entry of the
    applying file was taken although the body it copied changed, since
    its usage of the functor held by the signature's fingerprint and the
    unit of the old body, which a REPL keeps, was still there. The same
    took a cached unit across a file used again, edited or not, and linked
    it to the first file's globals. Fixed: a usage holds by its
    fingerprint only where the unit that bound the name is gone
    (docs/units.md, *Fingerprints*; S75; build-cache issues 21 and 23);
  - **with or without the cache, with or without the flag:** `use
    "counter.sml"; structure Old = Counter; use "counter.sml"; Old.n :=
    10` set the second `Counter.n` too (`!Counter.n` was 10 where 0 is
    right): the same text against the same units has the same identity,
    and a later unit named a global of the first load by the key the
    second load had too. Fixed: a unit loaded again is loaded and linked
    under an identity of its own (`identity~2`, docs/units.md; S38 and
    S74; build-cache issue 22). It was not functors'.

The prototypes are on this branch, behind the flag; with it off the
compiler's output is the same bytes, but compiling the compiler itself
compiles their sources too: the bootstrap's budgets were re-based for
1,494.1M bytecode instructions, from 1,407.2M (+6.2%). The full tables, scripts and raw
results are in the campaign's drafts (`impl/fu-m5/g2.md`,
`impl/fu-m5/measures.md`).

**The four checks before M7 (the owner, 2026-10-25), and the ruling.**
Four corner-case bugs of the expansion had been found only by compiling
large programs, so before M7 made it the only way the owner asked for
four checks, after which G2 is go:
1. **every corpus linted under the flag** (`--functors=functions
   --datatype-tags=sorted-x --lint`, whole and in units, with the Basis's
   marks): `tests/lang` and `tests/errors` in five modes (906 pass; 6 are
   M3's corners, 5 skipped), `check-levels` (361), S42 (361 and the
   compiler, whose bootstrap under the flag reaches its fixpoint), the
   Basis Library suite (240), the examples, HaMLet's corpus, SML/NJ's
   regression suite (813), the benchmark catalogue (509 of 515: the six
   `pidigits` were IntInf's SML arithmetic, wrong with the flag off too,
   and fixed), MLton's 606 files whole and in units, and HOL4 to
   `hol.state` (346 s): clean;
2. **every program's output compared with the flag on and off**, in the
   same runs: the same, but for traces (below), the collector's numbers
   in units, and SML/NJ's tests that print timings or the image's name;
3. **a generator of functor programs** (`tests/runner/functorgen.sml`,
   `functors/@generated` in `make check`): 6,688 programs of the module
   language's hard shapes, each in up to seven modes. It found three
   failures of `--lint` in programs that printed right: a functor applied
   to an earlier unit's structure in units, a datatype over a sealed
   structure copied once for two applications, and -- not functors' --
   Lower's results giving a global two constructors share the first one's
   representation;
4. **an independent review of `expand.sml`**: seven findings, two of them
   miscompiles no lint saw (a program's `if n = 0` folded as a
   descriptor's test; a descriptor worked out apart from the layout the
   expansion gave the instance), a lint failure of `fxp`'s kind, traces
   that differed between -O0 and -O2, a crash on a marker recognised by
   its type's shape, MidLint's cast rule, and two of no effect.

Every one is fixed with a test (build-cache-issues.md, *Found on the
way*): the casts, markers, open constructors' tests and descriptors are
primitives of their own (`functor_cast`, `functor_marker`, `open_boxed`,
`open_layout`, Lower working out the descriptor from the layout it gives
the datatype), and each copy of a body has the instances its applications
make. Since 13829a969 every compile a test makes is linted (`RUNE_LINT`),
which found four more bugs outside the prototype, fixed too.

**G2: go** (the owner, 2026-10-25), and M7 follows. One decision of M6c
departs from M7's text below, and the owner kept it (2026-10-25): a copy
is named in traces by the functor (`F.boom`), as the functor's function is
at -O0, where nothing is expanded, so that traces are the same at every
level (`check-levels`), where Rune's copies were named by the structure
(`A.boom`). SML/NJ, Poly/ML, MLton and OCaml name by the functor too;
what naming the instance would take is in [functors.md](functors.md),
*Names in traces*.

### M7. Functors compiled once (F; M, about 300 added and 520 removed)

* **What:** the flag's way becomes the only way, in every mode (D16):
  - removed from the elaborator: `copied`, `signatureTyped`,
    `Ast.copyStrexp`, `FunInfo`'s `body`, `defEnv`, `defSigs`, `defFuns`,
    `allowPrim` and `origin`;
  - removed from units: the re-parse of bodies, issue 1's binders, `funat`,
    issue 9's paths of functor sources, the source hash and mode in the
    pickle's prefix (E10 counted about 520 lines with the elaborator's);
  - dynamic modules on the same nested records (D3): `_dynamic`, `_export`,
    the ABI's fingerprint, `docs/units.md`'s *Dynamic modules*,
    `tests/dynamic`;
  - D4's numbering landed for every datatype, the VM's C for `list` and
    `order` with it, and `_export`'s renumbering of tags (`exportTags`)
    removed;
  - the version keys bumped;
  - the scenarios' expectations changed: S8, S21, S48 to S51, S55, S61, S65
    and S66 (E10 says what each becomes);
  - function names in traces and profiles: a call of a functor's function is
    named by the functor, and so, since M6c, is an expanded copy, for
    `check-levels` (*Gate G2*, the ruling);
  - (a), (c) and (d) closed by construction, their tests turned around.
* **Done when:** G2's budgets hold on the merged code; `make check`;
  MLton's S44 to S48; HOL4 built through the cache with `RUNE_VERIFY_CACHE=1`.

### M8. Nested functors that do not blow up (F; S, about 200)

* **What:** D13's budget tuned and documented; `compile-funnest` given `scale`
  lines from depth 8 to 12 at two applications a body (E3 ran them; depth 16
  would be 131,071 copies) and to 16 at one, in whole compiles, in units and
  in `--units --whole`; E3's programs as budgets.
* **Depends on G2.** On a go, the budget bounds the expansion. On a no-go,
  nothing bounds static interpretation but functions: D13 D keeps M5's
  functions for applications past the budget alone, and M8 is that.
* **Done when:** the generated programs grow no faster than linearly with
  the number of applications in every mode, and the code made before `shake`
  stays within the budget. E3 found the front end linear today; Σ M^k is
  the code.
* **Done (2026-10-25).** The budget stays 1,000,000 (D13, *The budget,
  measured*): twice MLton's largest application (508,928 nodes), the
  bootstrap's 1,405. Nine budgets hold E3's programs in the three modes,
  each with a `scale` line by the applications static interpretation makes
  (`scale KIND ARGS... EXPONENT`, the generator writing the count on the
  program's first line): `compile-funnest`, `-units`, `-unitswhole` (`D`
  8 to 12 at `M` = 2: applications^1.07, 1.05, 1.05), `compile-funnest1*`
  (`D` 8 to 16 at `M` = 1: 1.09, 1.22, 1.24) and `compile-funapp*` (80 to
  320 applications: 1.01, 1.02, 1.02). The copies stay within the budget
  by construction (`Expand`: an application is copied only while its
  function's size fits what the top-level application has left), which
  `tests/runner/tools.sml` (`compiler`, *budgets: functors*) holds: 127
  applications all copied at the default, at most 500 nodes at
  `--functor-budget=500`, none at 0.
* **What a compile reads (2026-10-25).** M7's 0.39M instructions more a
  compile (`compile-hello` 2.03M at e6accb2c0, 2.42M at M7) were the Basis
  Library's MANIFEST read a second time, a line at a time, for its
  `# inline:` line, not the marked functors' Mid: a whole compile loads no
  basis. The `# inline:` and `# library:` lines are read from the header
  alone now, and `compile-hello` is 2.08M (1.023 of e6accb2c0's). In a
  compile in units of a program that loads the I/O stack, decoding the
  marked functors' Mid costs about 2.5M instructions (1 to 2.6% of a warm
  build: `wordcount`, `mlyacc`, `hamlet`) and hashing it 0.9M; the hash is
  worked out when an `inl F` usage asks for it, and the decoding stays,
  since skipping it would need a basis whose Mid says its length. What is
  left:
  - At `M` = 1 the growth is above linear (D13): the program's interface
    is quadratic in `D` (each functor's result holds every level below
    it), and the front end and a unit's basis write the summaries whole.
    Sharing them (a basis that names a signature written before, an
    instantiation that keeps what it does not rename) would make it
    linear; it is not done.
  - A limit of the program, not of the copies: past the budget its
    environment still grows as Σ M^k, since `R` of `funnest` holds a
    structure for every application static interpretation would make.
    At `D` = 16, `M` = 2 that is 131,071 structures: a whole compile
    elaborates for 58 s and translates 5,901,284 nodes, binding every
    value of `R`'s substructures to a global of its own, and runs out of
    memory under 6 GB, whatever the budget. At `D` = 14 (32,767
    structures) every mode compiles: whole 8.7G instructions, in units
    22.3G (a unit of 27.6 MB of code), `--units --whole` 27.2G.
  - Found on the way and fixed: at `D` = 14 `--units --whole` stopped with
    an uncaught `Size`, `Pickle.writer` doubling its buffer past
    `CharArray.maxLen` (100,000,000 on Rune) from 67,108,864. The buffer now
    grows to the host's longest array at most, and a unit whose basis, Mid
    or cache entry needs more is an error of the unit's
    (`Pipeline.keeping`), not an uncaught exception.

### M9. Retire (S)

* The final measurements, against E3, E5, E7 and E8.
* The documents: [incremental-compilation.md](incremental-compilation.md)'s D1
  ("for now to keep strict SML'97 semantics") and risk 3;
  [units.md](../units.md) at `:82-85`, `:115-126`, `:270-274` and `:296-309`;
  [build-cache-issues.md](build-cache-issues.md),
  issues 1, 9 and 15; [units-fixes.md](units-fixes.md), retired into this
  roadmap; [jit.md](jit.md)'s division by a constant; `docs/language.md`;
  [functors.md](functors.md)'s B, built.
* A section *At the close*, after *Status*, as utf8.md has: what was found,
  what is left.

### Later

- **Compiling against a functor's signature alone** (SMLSC's functor
  specifications; incremental-compilation.md's *Ready for, not built*): with
  functors as functions, a client can be compiled against `functor F (X : S)
  : T` before `F` exists, as M9 of that roadmap does for structures.
- **Memoised applications** (D13 C).
- **Equality functions in the argument** (D6 B), if a build in units shows
  the walk.
- **The functors of stable units expanded across units** (D2 C), if G2's
  measures of the Basis and HOL4 ask for it.
- **A cache shared between people who do not trust each other** (issue 7):
  SHA-256 for identities (D11 D).
- **Inlining small functions across units** (incremental-compilation.md,
  *Ready for, not built*): builds in units run 17% more instructions and 23%
  more cycles than whole on MLton's benchmark set today, mostly from small
  Basis functions
  called across units, functors or not (E4).

### Why this order

- Issue 16's fix first of all, as M2's first item: it is a hole in the cache
  that makes wrong builds today.
- M1 first among the milestones, for the brief's reason: its test case
  disappears with M2 and M4.
- M2 before M4: what changes no output goes first, under the strictest gate,
  and its counters measure M4.
- M3 early: the tests make every later change of typing visible, and D15
  helps the IDE at once.
- M5 and M6 can start on the first day: they are prototypes behind a flag.
  G2 decides before anything is removed.
- M4 does not wait for M7: fingerprints of functors' signatures stay in every
  design, and MLton's build in units pays for them today.

## Prerequisites and flags

- **`--functors=functions`** (M5 to M7, D16): functors compiled once in every
  mode; removed by M7, which makes it the only way.
- **`--functor-budget=N`** (M8, D13): the expansion's budget in Mid nodes; 0
  expands nothing, so that a whole compile calls every functor as a build in
  units does.
- **`--pass-stats`** gains the bytes hashed by phase and call site (M2).
- No other option changes. `--flex-records` and `--default-type` keep their
  meanings; `--default-type` stops reaching a library's functors (corner
  (d)).
- **Version keys** bumped by M2 (`UnitBasis.version` for issue 16's fix,
  `UnitCache.version` for the identity an entry keeps), M4 and M7.

## Relation to the other plans

- **[functors.md](functors.md)** is where B, "functors as functions: to
  revisit", was left. This roadmap revisits it: *Before revisiting B*'s three
  measurements are E2 and E8 (HOL4's recompiles: few, since its functors are
  in its tools), E4 and M5 (B's run-time cost) and M6 (what the expansion
  recovers).
- **[units-fixes.md](units-fixes.md)**: F1 and F2 are M2, F3 is M4, F4 is M1
  and D11. It is retired into this roadmap by M9.
- **[build-cache-issues.md](build-cache-issues.md)**: E9 adds issue 16, fixed
  by M2; M7 removes the causes of issues 1, 9 and 15.
- **[incremental-compilation.md](incremental-compilation.md)**: its D1 chose
  static interpretation "for now to keep strict SML'97 semantics"; its *Ready
  for, not built*'s "SC against a functor signature" is answered in *Later*.
  Its risk 3 saw "functor bodies in the basis are large and change often",
  with HOL4, "whose kernel is functorised", the case to measure. HOL4's
  kernel declares no functor; two of its neighbours, `KNametab` and
  `Termtab`, apply Isabelle's `Table`, and 23 of its 32 functors are in its
  parser and lexer generators (E2). So an edit of a body recompiles little
  in HOL4, and its exposure is the other way: under D2, those tables become
  calls (G2 measures it). The functor-heavy code is MLton's and the
  Basis's.
- **[jit.md](jit.md)**, *Left by the performance plan*: division by a constant
  is M1; constant operands in tier 2's body generally (folding an `INT` into
  the instruction that reads it) is the same fact M1 records, used for one
  operation.
- **[middle-end.md](middle-end.md)**: its M10 (specialisation) and M12
  (monomorphisation, not built) are the neighbours of M6's expansion; the
  expansion is specialisation of one kind of function, functors', on known
  arguments.
- **[sml97-extensions.md](sml97-extensions.md)**: M3 adds MLton's typing of
  functors.
- **[performance.md](performance.md)**, retired: its M3 is this roadmap's
  starting point.

## Risks

- **The expansion does not reach today's code** (G2 fails). Then the brief's
  first assumption holds in the strong form -- copies are faster and a
  middle-end copy is not the same thing -- and this roadmap ends after M1 to
  M4, with M3 closing the corners one by one, and M8 as D13 D: functions
  only past the budget, so that nested functors still do not blow up. The
  prototype milestones exist so that this is found before anything is
  removed.
- **Renumbering every datatype** (D4) changes every compiled constant and
  the VM's C for `list` and `order`; a place in the C that assumed today's
  tags and is missed would be a wrong result. M5 runs every suite under each
  numbering, which finds such a place where a test exercises it. The
  descriptors that remain are for HaMLet's 8 constructors, so their cost is
  no longer a risk.
- **Run time in units** (X2). The Basis's functors and HOL4's `Table` are
  called across units. If G2 finds that cost too high, D2 C (stable units'
  functors expanded across units) comes back.
- **Refusing (b)** may refuse programs other compilers accept (E1); M3 lists
  them before it lands.
- **The soundness of the cache** with fingerprints by structure (M4): the
  checker is the guard, and is itself tested.
- **The scenarios' expectations** change in M7, and with them the meaning of
  the tests that found issues 1, 9 and 15. Each changed expectation says why.
- **Shared machine.** Every number here was taken on a machine other
  sessions shared, at loads from about 1 to 25, each stated with its
  experiment; claims rest on instruction counts, cycles are indications
  (*Measuring*).

## Testing

- **Typing:** a test per corner (a) to (d) and per E1 program, in whole
  compiles, in units and with `--typecheck-only`: accepted or rejected as
  the Definition says from M7 on, and as M3 pins each mode until then.
- **Functors compiled once:** every suite with `--functors=functions`; the
  descriptor's cases (tags in another order, a flat constructor the spec
  leaves open), body datatypes built by a client, exceptions per call, `ref`s
  per call (rule 154), nested and repeated applications.
- **The expansion:** S42 with the flag on; instruction budgets for the
  bootstrap and the generated programs; `scale` lines for nested functors.
- **The cache:** the scenarios, with the changed expectations of M7;
  `mutate.py` with its history replay; the soundness checker of M4; MLton's
  S44 to S48; HOL4 with `RUNE_VERIFY_CACHE=1`.
- **Hashing:**
  - the hash's values against a model outside SML on a fixed corpus, on every
    engine of a build: the interpreter, tiers 1 and 2, the stack VM, the
    32-bit VM, aarch64 and the int64 VM;
  - the probe's value pinned;
  - S70 and S71, for a basis and a cache made by a compiler whose hash
    differs;
  - the hosts' values reported, for information;
  - the bytes hashed by call site, against E5's.
- **Division:** M1's table of divisors on both targets, every `--jit`, both
  integer widths.

## Measuring

- **MLton's 606 files** (`scripts/setup-mlton.sh` at 5fe943391, then
  `--units --no-cache --pass-stats --type-work=1000000000` over
  `mlton-rune.txt`): Rune at tier 2 (`--heap-limit 8589934592`) and MLton's
  build of Rune; whole for the ratio; warm builds through `--cache-dir`.
  This is also F4's test case until M2: E7's `results/E7/testcase.md` says
  how to reproduce it.
- **Instruction counts** (`runevm --count`, `perf stat -e instructions:u`) for
  claims; cycles as the best of three or more, pinned to a CPU, with the load
  stated.
- **The generated programs** of `tests/perf/gen.py` (`funapp`, `funnest`).
- **The bytes hashed** by call site: M2's counters.

## References

Every DOI was checked against Crossref on 2026-10-21 (E11's
`lit/doi-check.sh`; the Definition's and Granlund and Montgomery's by the
lead). After each work, how much of it was read: [whole], [in part], or
[record] for its record or abstract only.

**Standard ML and its separate compilation**
- R. Milner, M. Tofte, R. Harper, D. MacQueen. *The Definition of Standard
  ML (Revised)*. MIT Press, 1997. 10.7551/mitpress/2319.001.0001 [in part:
  the static semantics of modules, Appendix E]
- D. Swasey, T. Murphy VII, K. Crary, R. Harper. A separate compilation
  extension to Standard ML. *ML '06*, 32-42. 10.1145/1159876.1159883 [whole;
  the working draft CMU-CS-06-104 in part]
- A. W. Appel, D. B. MacQueen. Separate compilation for Standard ML. *PLDI
  '94*, 13-23. 10.1145/178243.178245 [record; its technical report whole]
- M. Blume, A. W. Appel. Hierarchical modularity. *TOPLAS* 21(4), 1999,
  813-847. 10.1145/325478.325518 [record; its technical report in part]
- M. Blume. Dependency analysis for Standard ML. *TOPLAS* 21(4), 1999,
  790-812. 10.1145/325478.325481 [record]
- M. Blume. *Hierarchical Modularity and Intermodule Optimization.* PhD
  thesis, Princeton University, 1997. [in part]
- Z. Shao, A. W. Appel. Smartest recompilation. *POPL '93*, 439-450.
  10.1145/158511.158702 [record; its technical report in part]
- M. Elsman. Static interpretation of modules. *ICFP '99*, 208-219.
  10.1145/317636.317800 [in part]
- M. Elsman. *Program Modules, Separate Compilation, and Intermodule
  Optimisation.* PhD thesis, DIKU, University of Copenhagen, 1999. [in part]
- N. Benton, A. Kennedy, C. Russo. Adventures in interoperability: the SML.NET
  experience. *PPDP '04*, 215-226. 10.1145/1013963.1013987 [in part]

**Modules**
- D. B. MacQueen, M. Tofte. A semantics for higher-order functors. *ESOP
  '94*, LNCS, 409-423. 10.1007/3-540-57880-3_27 [record]
- G. Kuan, D. MacQueen. Engineering higher-order modules in SML/NJ. *IFL
  2009*, LNCS, 2010, 218-235. 10.1007/978-3-642-16478-1_13 [record; Kuan's
  dissertation proposal of 2009 in part]
- A. Rossberg, C. Russo, D. Dreyer. F-ing modules. *JFP* 24(5), 2014,
  529-607. 10.1017/S0956796814000264 [in part]
- R. Harper, C. Stone. A type-theoretic interpretation of Standard ML. In
  *Proof, Language, and Interaction*, MIT Press, 2000, 341-388.
  10.7551/mitpress/5641.003.0019 [in part]
- D. Dreyer, M. Blume. Principal type schemes for modular programs. *ESOP
  2007*, LNCS, 441-457. 10.1007/978-3-540-71316-6_30 [in part]

**Representations**
- X. Leroy. Unboxed objects and polymorphic typing. *POPL '92*, 177-188.
  10.1145/143165.143205 [in part]
- Z. Shao, A. W. Appel. A type-based compiler for Standard ML. *PLDI '95*,
  116-129. 10.1145/207110.207123 [in part]
- Z. Shao. Flexible representation analysis. *ICFP '97*, 85-98.
  10.1145/258948.258958 [in part]
- Z. Shao. Typed cross-module compilation. *ICFP '98*, 141-152.
  10.1145/289423.289436 [in part]
- Z. Shao. An overview of the FLINT/ML compiler. *Types in Compilation
  (TIC '97)*, 1997. [in part]
- A. W. Appel. A critique of Standard ML. *JFP* 3(4), 1993, 391-429.
  10.1017/s0956796800000836 [in part, its technical report]
- M. Tokuda, E. Sumii, A. Abe. Specialization of generic array accesses
  after inlining. *EPTCS* 241, 2017, 45-53. 10.4204/EPTCS.241.4 [in part]

**Division**
- T. Granlund, P. L. Montgomery. Division by invariant integers using
  multiplication. *PLDI '94*, 61-72. 10.1145/178243.178249 [record]
- H. S. Warren, Jr. *Hacker's Delight*, 2nd ed., chapter 10. Addison-Wesley,
  2012. [in part]

**Hashing and build systems**
- A. Z. Broder. Some applications of Rabin's fingerprinting method. In
  *Sequences II*, 1993, 143-152. 10.1007/978-1-4613-9323-8_11 [whole]
- J. L. Carter, M. N. Wegman. Universal classes of hash functions. *JCSS*
  18(2), 1979, 143-154. 10.1016/0022-0000(79)90044-8 [record]
- M. N. Wegman, J. L. Carter. New hash functions and their use in
  authentication and set equality. *JCSS* 22(3), 1981, 265-279.
  10.1016/0022-0000(81)90033-7 [record]
- R. M. Karp, M. O. Rabin. Efficient randomized pattern-matching algorithms.
  *IBM J. R&D* 31(2), 1987, 249-260. 10.1147/rd.312.0249 [record]
- J.-P. Aumasson, D. J. Bernstein. SipHash: a fast short-input PRF.
  *INDOCRYPT 2012*, LNCS, 489-508. 10.1007/978-3-642-34931-7_28 [record]
- J.-P. Aumasson, D. J. Bernstein, M. Boßlet. Hash-flooding DoS reloaded:
  attacks and defenses. Talk at 29C3, 2012. [through a summary]
- J. Pachocki, J. Radoszewski. Where to use and how not to use polynomial
  string hashing. *Olympiads in Informatics* 7, 2013. [in part]

**Code read** (E11; the versions in `~/reference`): SML/NJ 2026.2 and
110.99.9, Poly/ML 5.9.2, MLKit, MLton, OCaml 5.5.1 and 4.14.4, GHC, rustc
1.98.1, Go 1.27.1. The notes, with every file and line, are with the drafts
(`lit/`).
