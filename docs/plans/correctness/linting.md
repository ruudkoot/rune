# Roadmap: checking what the compiler makes, from the syntax to the bytecode

**Today the compiler lints three of its representations**, Lambda, Mid
and Low, behind one switch that every test compile turns on. It checks
neither the syntax the elaborator typed nor the bytecode it writes.
- **The syntax:** what the elaborator decides is checked only through
  what it hands on. A program the Definition rejects but the elaborator
  accepts is well typed below, and passes everything.
- **The bytecode:** the register code is trusted by tier 2 of the JIT
  without tests, and the VM's loader checks only part of it. So a mistake
  of the code generator runs, and can read outside an object or jump
  anywhere.
- **The cost:** the lints add from 16% to 148% of a compile, so none can
  be on for a user. Lint never runs at all in some places: the link, the
  cache, the frozen Basis, the register target in `check-levels`.

This roadmap plans five things:
- **Lint in the right places, at a cost that allows levels.**
  - Two fixes cut the lints to 35-60% of their cost with the same rules.
  - Four levels run from always on to deep.
  - Lint runs where it never did.
- **The IR lints' missing rules:**
  - exceptions' payloads, primitives' signatures and constants;
  - casts by origin;
  - Mid held to System F;
  - shapes and layouts across functions in Low;
  - a negative test for every rule.
- **Types for the register code, and a verifier of it in the compiler,**
  run before the code is written. Its rules are generated from the
  instruction set's description, and it checks interfaces at the link.
- **Types on the syntax, and AstLint:** an independent checker of the
  elaborator's derivations, following the Definition, and types for the
  editor at every node. The groundwork for error messages comes with it.
- **Two choices the Definition leaves open, as options of the language:**
  overloading's context and free type variables at top level, as
  `--flex-records` is for flexible records (the owner's direction).

Writing it found two bugs:
- **Rune rejects a valid program** (the value restriction misses
  `(conexp : ty)`, E6);
- **a check changes the output** (`--mid-roundtrip` under `--units`, E9).

It also found that Mid is not well scoped in its type variables (E10), and
a `.rbc` that the loader accepts and tier 2 runs into a segfault (E7).

It was written on 2026-10-25 against functors-units `d551f19dd`, which the
owner means to merge into master before it is implemented. It lives in a
worktree, on branch `linting`.

What it rests on:
- **The code:** a reading of the lints and the pipeline, the elaborator's
  annotations, the module language, the back end, the loader and what
  tier 2 trusts (*Where we are*).
- **Fourteen experiments** (*The experiments*):
  - what each lint costs (E1), and cheaper levels (E2);
  - which check catches which bug, by mutants of the compiler (E3), and
    the history of the compiler's bugs (E4);
  - what types on every node cost (E5), an AstLint of the Core (E6), and
    what the editor gains (E12);
  - a verifier of the register code (E7), shapes and tier 2 trusting less
    (E7b), and runeopt's check of the stack code (E8);
  - lint where it does not run (E9), and the IR lints' missing rules
    (E10);
  - the literature, and eighteen other systems' checks, all but Lua's read
    in their sources (E11);
  - overloading's context and free type variables at top level, in eight
    compilers (E13).
- **Throwaway prototypes:**
  - an instrument for the lints' cost, and the lints in new places;
  - `SourceTy` and the tables of types on the syntax;
  - AstLint of the Core (1,159 lines);
  - `RegVerify` (929 lines);
  - shapes in Low;
  - the IR lints' missing rules;
  - a hook that injects faults;
  - `RbcCheck` in the compiler.

  They are kept as patches in the drafts.

## Status

| Milestone | What | Track | State |
|---|---|---|---|
| M0 | This roadmap | | done (2026-10-25) |
| M1 | The fixes found, and the guards that cost nothing | P | done (2026-10-26) |
| M2 | Lints that cost less, with the same rules | P | done (2026-10-26) |
| M3 | Levels | P | done (2026-10-26) |
| M4 | The missing rules of LambdaLint and MidLint, a negative test for every rule | I | not started |
| M5 | Mid is System F | I | not started |
| M6 | Shapes and layouts in LowLint | I | not started |
| M7 | The instruction sets described for checking | B | done (2026-10-26) |
| M8 | A verifier of the register code | B | done (2026-10-26); its level comes with M3 |
| M9 | Units and the link | B | not started |
| M10 | The stack code's check, in the compiler | B | not started |
| M11 | Node ids, witnesses and `SourceTy` | A | not started |
| M12 | AstLint of the Core | A | not started |
| G1 | How AstLint goes on (the owner's) | A | |
| M13 | AstLint of the module language | A | not started |
| M14 | The editor's types | A | not started |
| M15 | Overloading's context and free type variables, as options | A | done (2026-10-26) |
| M16 | Retire | | not started |

The owner took every recommendation, D1 to D19, on 2026-10-26
(*Decisions*). Two calls stay the owner's:
- gate G1, after M12;
- the move of `--overloading`'s default, once M15 has counted what it
  breaks (D18).

The tracks do not wait for each other, after M1:
- **P, placement and cost,** puts lint where it does not run and makes it
  cheap enough to have levels.
- **I, the IR lints,** adds the rules E10 found missing, and holds Mid to
  System F and Low to its shapes.
- **B, the bytecode,** describes the register code's instructions for
  checking, verifies the code in the compiler, and checks units'
  interfaces at the link.
- **A, the syntax,** gives every node an id, records the elaborator's
  witnesses in a type language of the source, checks them with AstLint,
  and gives the editor a type at every node. It also makes overloading's
  context and the treatment of free type variables options (M15). Gate
  G1, after AstLint of the Core, is the owner's.

## The implementation so far

The owner took every decision as recommended and asked for every milestone
(2026-10-26). Each milestone is merged into `linting` after `make check`
passes on its exact commit.

- **M1** (`78e29e130`, `1835c1da7`, `6e09be6bc`, `eb976d841`, `903e3dc82`,
  merged `71bad1be4`; `make check` 21,307 of 21,307).
  - **The two bugs, fixed:**
    - the value restriction takes `(conexp : ty) atexp`, with a test in
      `tests/lang` and one that `ref`'s stays expansive;
    - `--mid-roundtrip` reads Mid back with counters of its own.
  - **No check may move the compiler's counters:** `Pass.checkAt` refuses
    one that moves the counters of stamps, type names, type variables,
    records, functions, labels or private names.
  - **Each check is counted at every depth** in `--pass-stats`. HaMLet in
    units: the old `checks` line said 0.005 s; the checks take 2.2 s.
  - **The invariant of `results` is always on:** 0.14% of HaMLet, 0.53% of
    the bootstrap.
  - **`check-levels`** compiles both targets and a true `--units` build
    (UL). The register target is compared lint on against lint off, and
    runs at tier 2 with `--checked`. Its CPU is about 2.3 to 2.75 times
    what it was (more builds and runs per program); M3 weighs cuts against
    "make check does not grow".
  - **`lib/cache` is built with `--lint`:** all 768 entries are the same
    bytes.
  - **A departure:** the Mid round trip gives its type names stamps from a
    range below every stamp the compiler makes, never reused, because
    `Ty.con` hash-conses by stamp and keeps the first name it saw.
- **M2** (`54a2d65c4`, `8aeee5c0e`, merged `6a02ec637`; `make check`
  21,307 of 21,307).
  - **What changed:**
    - MidLint keeps imperative tables, with one scope table entered and
      left;
    - LowLint checks availability by dominance over the blocks;
    - `midcanon` is checked as a renaming of its input (`midconcat` keys
      the lint of units' Mid joined under `--units --whole`).

    The rules and the messages are the same.
  - **What `--lint` costs now:**
    - HaMLet -O1: +31.5% (+83.4% before);
    - the bootstrap -O1: +60.1% (+148.3%);
    - MLton whole: +14.1% (+39.5%);
    - MLton `--units --whole`: +7.2% (+16.3%).

    LambdaLint is now the largest single check.
  - **A departure:** LowLint's walk up the dominator tree is not strictly
    linear (5.8 steps a use on HaMLet, 1.8 on the bootstrap).

- **M3** (`caa0330a8`, `242ab89a1`, `387974796` with two merges of
  `linting`; merged `6a7cf3315`; `make check` 21,648 of 21,648).
  - **The switches:** `--lint=off|0|1|2|3` and `RUNE_LINT=LEVEL`. A bare
    `--lint` is 2, and `bin/rune-test` sets `RUNE_LINT=2`.
  - **The defaults:** 0 for `rune`, 1 for the REPL and the compiler
    library.
  - **What runs at each level:**
    - 0: `results` and the functor bodies decoded;
    - 1: the boundaries, with `regverify` and `regverify-link`;
    - 2: every pass, with MidLint per definition inside `simplify` and
      the code's round trip;
    - 3: the Mid round trip after every stage (`make test-ir`).
  - **Diagnosis:** a breach at level 1 compiles again at level 2, in a
    fresh session, to name the pass.
  - **What each level costs** (HaMLet -O1 / the bootstrap -O1):

    | Level | Cost |
    |---|---|
    | 0 | +0.14% / +0.52% |
    | 1 | +16.4% / +32.8% |
    | 2 | +35.4% / +70.7% |

  - **`check-levels`** costs 1.92 times its CPU before M1 (2.27 at M2).
    The stack target builds no UL, and the register target is compared
    with a build at level 0 only at -O2 and in UL.
  - **Departures:**
    - A breach at level 0 is not compiled again: the seal it needs costs
      about 305,000 instructions on every compile and would put two
      budgets over. Its message names `--lint=2` instead.
    - Level 0 moved no budget past its limit; none was re-based.

- **M7** (`ac2e7e2ad`, merged `efa5148f1`; `make check` 21,251 of 21,251).
  - **The register instructions are described for checking in
    `src/isa/regs.sml`:**
    - each operand's role and the value it holds;
    - the implicit traffic of `PRIM`, `PRIMPUSH`, `CALL`, `RESULT` and
      `CATCH`;
    - "followed by" (`RESULT`, `SWITCH`'s table, `CATCH` at a handler);
    - which primitives each instruction may name;
    - the closures' and known calls' facts that E7's rules need.
  - **RegGen writes the tables into `regcodes.sml`**, and
    `Regs.imagePrims` is generated. `RegIsa.check` holds a description
    together, and `runeisa --test` refuses 43 wrong ones (in
    `make check-isa`).
  - **Primitives' types are parsed** by a real parser (`Isa.parseTy`; all
    414 parse) into `PrimTys`, and `Prims.repsOf` comes from them. This
    moved here from M4, which needs it later.
  - **The fingerprint and the output are unchanged.** The loader's
    `prim_result` keeps the old reading, so the C does not change.
  - **Found:** with the parse, the primitives without a result rep are 8,
    not 28. The split on `*` misread 20, among them `rt_debug_hook` and
    `repl_printer_add`.
  - **Cost:** start-up +0.44% of `compile-hello` (the tables are built at
    start).

- **M15, the options** (`32bb74cb3`, `80e4fe4db`, `b1bc26e9b`, merged
  `f7eb8c8cd`; `make check` 21,580 of 21,580).
  - **What landed:**
    - `--overloading=binding|declaration|toplevel|topdec` and
      `--free-tyvars=refuse|monotype|dummy|later|later-monotype`, in the
      cache's configuration, the REPL, the compiler library, the help, the
      man page and `docs/language.md`;
    - the check of rules 87-89, moved out of `--flex-records`;
    - `tests/overloading`, E13's programs under every mode;
    - two declarations of `RuneForeign` written so that the Basis
      elaborates in every mode.
  - **The count under `declaration`:** nothing breaks in Rune's sources,
    the Basis, the benchmarks, MLton's 606 files or HaMLet. One SML/NJ
    regression program breaks, which SML/NJ and MLKit refuse too. HOL4
    breaks at 7 sites in 3 files: integer constants that a later
    declaration or the signature makes `IntInf.int`, one annotation each.
  - **The owner's call (2026-10-26):** the default moves to
    `declaration`, and HOL4 builds with `--overloading=toplevel` until the
    annotations land in the HOL4 tree.
  - **The move** (`bff52625b`, merged `a1121a6b2`; `make check` 21,626 of
    21,626).
    - It needed seven more annotations in the repository that the count
      had missed: string sorts whose `<` would now default to `int`
      (`tests/runner/sh.sml`, `basis.sml`, `laws.sml`,
      `tools/builder/common.sml`), `tools/measure/jit-dump.sml`,
      `tests/ffi/performance-model.sml`, and
      `lib/ffi/win32/model/model.sml`.
    - `docs/plans/hol4.md` says how HOL4 builds with
      `--overloading=toplevel`, and `hol4-overloading-declaration.patch`
      beside it holds the seven annotations for the HOL4 tree.
  - **Where the implementations are less tidy than D18 and D19 say:**
    - MLton's `topdec` context also ends at a functor or signature
      declaration, and Poly/ML lets an application settle a functor body's
      overloading. Rune settles a functor body where it ends.
    - HaMLet, under `refuse`, runs E13's functor program; Rune refuses it
      at the functor.
    - SML/NJ makes dummy types at structure level only, not "at any
      depth".
    - MLton accepts two applications of a functor at two types, against
      rule 54. Rune's `later-monotype` does not.
  - **In the REPL,** `later*` treats the end of an input as the end of the
    program: no weak variables across inputs (`src/repl/repl.sml`).

- **M8** (`969420178`, merged `0a0e2855e`; `make check` 21,263 of 21,263).
  - **`RegVerify`** (`backend/regverify.sml`) checks the register code in
    one forward pass, after `registers` and on every program
    `Link.program` makes.
    - Its per-instruction rules come from M7's tables. The order of reps,
      "unset", the meets, the handlers' depths and the tag facts are
      written by hand.
    - Lower declares each function's result rep and captures, and each
      global's rep. They are carried in `Code` and, for cached units, in
      the unit file (version 3). The `.rbc` format is unchanged.
  - **What it found:** no breach on `tests/lang` (every level, units,
    debug information), `tests/basis` (all 240, both levels), the 510
    benchmark programs, the bootstrap (whole, in units, cold, warm, from
    `.rbu` files) or MLton, whole and in 791 units.
  - **What it catches:** E7's eleven corruptions, injected by
    `RUNE_REGVERIFY_INJECT` (`tests/register/regverify.sml`), and E3's
    mutants R02, R03, R06, L09, K01 and K02.
  - **What it costs:** +0.8% (small), +1.6% (HaMLet), +4.4% (the
    bootstrap), +0.8% (MLton), about half the prototype's. It is over
    D13's threshold, so it goes to level 1 (M3). A REPL line takes about
    0.03 ms.
  - **Departures:**
    - D9 said the VM would not change, but the VM's own unit loader
      (`runtime/loader.c`) had to accept the unit file's version 3.
    - The link still verifies the whole program (+10-19% on cached
      builds) until M9 cuts it to interfaces.
  - **The handover:** `docs/plans/correctness/vm-verifier.md` holds the
    segfault's recipe, E7b's measures and the tables a C verifier could
    be generated from.
  - **Found on the way:** the REPL dies printing the results of
    `tests/lang/mod.functor.functions_review.sml` ("fatal error …
    expected tuple"), with or without the lint, and in the main tree's
    `rune-repl` too. It is not this roadmap's.

## Found while writing this roadmap

Each finding is answered by a milestone, unless it is said to be outside
this roadmap.

**In Rune:**
- **A valid program rejected: the value restriction misses
  `(conexp : ty) atexp`** (E6).
  - **The program:**
    `val x = (SOME : 'a list -> 'a list option) nil`, used at two types.
  - **Why:** `nonexpansive` takes a constructor's application only when
    the constructor is a bare identifier. The binding is not generalised,
    and the explicit `'a` cannot be.
  - **Others:** HaMLet, MLton, Poly/ML and MLKit accept the program
    (*Outside this roadmap*, below, for SML/NJ and Moscow ML).

  M1.
- **A check that changes the output: `--mid-roundtrip` under `--units`**
  (E9). It takes fresh stamps from the elaborator for every name it reads
  back, so a unit's basis changes, and the cache, which does not record the
  flag, gives builds without it entries made with it. M1.
- **Lift leaves type variables unbound in Mid** (E10). It gives a lifted
  function the variables its inner polymorphic functions bind, and passes
  them where nothing binds them. Nothing is miscompiled today, since every
  id is unique, but a substitution through such Mid can capture. M5.
- **ToMid's output is not well scoped in its type variables either** (E10):
  - ungeneralised values keep their generics;
  - a functor body's function is aliased by a generalised `Let`;
  - patterns bind a variable twice.

  D17, M5.
- **`MkExn`'s payload is never checked after the first pass that copies
  code** (E10). Copies get stamps that `Ty.exnArgs` does not know, so
  type-checker.md's open case is not answered but unexamined. M4.
- **A `.rbc` that the loader accepts and tier 2 runs into a segfault**
  (E7): a `SWITCH` with its first jump dropped. The loader catches one of
  E7's eleven corruptions. M8 hands the reproducer to the VM roadmap.
- **`--pass-stats` does not show lint apart under `--units`** (E1): it
  sums check time into `checks` at depth 0 only, and a build in units runs
  every check deeper, inside `unit-passes`'s own time. M1.
- **`check-levels` compares only the stack target**, so `Regs` and `Link`
  are compared by nothing at its levels (E9: the register target is clean
  when run). M1.
- **The frozen Basis cache has never been linted** (E9: built with lint,
  all 768 entries are clean and the same bytes). M1.
- **runeopt's `RbcCheck` is superlinear** (E8): 12.6 s on MLton's stack
  code. M10.
- **A check that moves the compiler's counters hides bugs** (E3). E9's
  prototype round trip after `midcanon` (today's flag runs after `mid`
  only) takes fresh stamps, which moved the counter past a collision a
  seeded bug made. The bug, which today's lint catches,
  then vanished. M1's fix of `--mid-roundtrip` restores the counter, and
  every check is held to touching none.
- **The fast corpus exercises no dynamic module and no inlined functor of
  an earlier unit** (E3). Three real fixes reverted as seeded bugs
  changed no byte of it. The harness the roadmap keeps adds
  programs for both (M4).
- **The optimiser leaves branches that cannot run** (E3, E7):
  - redundant tag tests, 18 to 25 in the bootstrap, that an earlier test
    already answered;
  - code after a call that always raises;
  - the `SOME` branch of a global only ever set to `NONE`.

  They are not bugs, but a verifier must not refuse them. That is why it
  takes declared reps rather than reps derived from stores (D9).

- **Rune's overloading is settled in a larger context than Appendix E
  allows** (E13): a whole structure or `local`, where the bound is the
  smallest enclosing structure-level declaration. `docs/language.md` lists
  it as a deviation. Its three contexts are not one:
  - overloading per declaration at top level;
  - flexible records and free type variables per topdec, to
    `;`.

  D18, D19, M15.

**Outside this roadmap:**
- **SML/NJ rejects `(conexp : ty)` too.** SML/NJ 110.79, 110.99.9 and
  2026.2 reject E6's program. Moscow ML 2.10.1 accepts the declaration but
  does not generalise it. Neither is reported.
- **One abort of `runevm` while it ran a compiler** (E3): glibc's check of
  the C heap ("malloc(): mismatching next->prev_size"), once in some 25,000
  compiles, on a loaded machine. It did not come back in 46 more runs.
  Nothing in the compiler's SML can corrupt the C heap, so it is the VM's.
  It is worth a run under ASan. Not this roadmap's.
- **MLKit 4.7.25 fails with an internal error** (E13) on a functor whose
  result keeps a free type variable:
  `functor F () = struct val id = (fn x => x) (fn x => x) end`, then
  `structure A = F ()` ("Impossible: IntModules.reelaborate.ParseElab.FAILURE").
- **SML/NJ gives a dummy type at each value declaration** (E13). It
  rejects programs the Definition accepts: `val r = ref []` determined by a
  later declaration of the same topdec, or inside a
  structure. Not reported.

## The request

The owner's brief, as written. It is the top of
`docs/plans/correctness/linting.md` in the main tree, which this roadmap
replaces on its branch:

> - this is a draft roadmap to improve linting of the intermediate representations in the compiler
> - below the line is a review by another agent with useful things to improve
> - i'm interested in having types in the ast. this should serve AstLint (an independent sml 97 type checker - not type inferencer - following the sml 97 defintion to verify the results of the type inferencer), better error messages (groundwork for a roadmap to be done later) and extra type information the LSP can use.
> - types and verification of the bytecodes (in sml as part of the output process - doing verification in the vm will be part of a future roadmap for a vm that can safely load untrusted code)
> - applying the lint in the right places in the compiler (e.g. between optimization passes and after linking)
> - if performance is costly then we make it contingent on the --lint flag. but if some of the lint passes can be made so cheap that they can be always on that is good too as --lint is typically only on during make check
> - useful things to research in addition to the academic literature are:
>   - ghc for typed intermediate representations (this compiler i know of doing something similar - maybe you know of other examples)
>   - java for bytecode verification
>   - source code available under /home/ruud/reference

Below its line, the brief carried a review of the lints, which Claude
wrote on 2026-10-25 during the functors-units roadmap. Its list of ways to
go further is traced in the second table below. Its findings are in
*Where we are*, corrected where functors-units M7 made them stale (*What
the brief gets wrong*, W1).

**The owner's answers while this was written (2026-10-25):**
- **The premise:** functors-units is merged into master before this
  roadmap's implementation starts. So it is written against functors-units
  `d551f19dd`.
- **Where:** on a new branch `linting` from that commit, in the worktree
  `.worktrees/linting`, committed as M0 and not pushed.
- **What it rests on:** a hybrid of measurements, bugs seeded into the
  compiler, throwaway prototypes and the reference compilers' sources
  (*The experiments*). The prototypes are of an AstLint of the Core and a
  verifier of the register code.
- **Form:** that of `docs/plans/functors-units.md`.
- **The threshold for a check that is always on** is the roadmap's to
  measure and propose (D13).
- **Trimming:** cut only what is fluff, not to a length.

**The owner's direction after M0 was first written (2026-10-26):** the
owner asked what other compilers do about two places where the Definition
leaves the choice to the implementation:
- the context that resolves overloading (Appendix E);
- what becomes of free type variables at top level (rules 87-89, Appendix
  G.8).

On the answer (E13) the owner directed: "like flex-records i want to make
this a language options". The modes and defaults are this roadmap's
proposal (D18, D19), and M15 builds them.

**The decisions (2026-10-26):** the owner took every recommendation, D1 to
D19. **And:** "rebase on functors-units and implement all milestones".

| The brief asks | Answered in |
|---|---|
| a roadmap to improve linting of the intermediate representations | this document |
| the review's things to improve | *Where we are*; *What the brief gets wrong*; M1 to M14 |
| types in the AST | *What the Definition says*; D1, D2; *The architecture*; M11 |
| AstLint, an independent SML '97 type checker, not an inferencer, following the Definition | *What the Definition says*; D3, D4, D5; E6; M12, G1, M13 |
| to verify the type inferencer's results | E6 (five mutants of the elaborator, three silent today); E3; M12 |
| better error messages, as groundwork | D6; M11; *Later* |
| more type information for the LSP | D7; E12; M14 |
| types and verification of the bytecode, in SML, as part of the output | D8 to D11; E7, E7b, E8; M7 to M10 |
| the VM's verification left to a later roadmap | *Constraints*; D8 C; M8's handover; *Later* |
| the lint in the right places: between optimisation passes | D12; E9; M1, M3 |
| and after linking | D15; E7; M9 |
| costly checks behind `--lint` | E1, E2; D13; M2, M3 |
| cheap ones always on; `--lint` is on mostly in `make check` | D13 and its threshold; E1, E2, E7 |
| the academic literature | *What the literature says* (E11) |
| GHC's typed intermediate representations, and other examples | *What the implementations do* (E11) |
| Java's bytecode verification | *What the literature says*; *What the implementations do* |
| the sources in `/home/ruud/reference` | *What the implementations do* |

| The review's list | Answered in |
|---|---|
| a lint of the instruction lists | E7, E8; D8 to D11; M7, M8, M10 |
| type variables in scope in Mid | E10; D17; M5 |
| casts | E10; M4 |
| representations across functions | E7b; D14; M6 |
| the elaborated program checked again | as AstLint, above |
| a cheaper lint | E1, E2; D13; M2, M3 |
| lint at the boundary of units | E7, E9; D15; M9 |

| The owner's direction (2026-10-26) | Answered in |
|---|---|
| what other compilers do about overloading's context and free type variables at top level | E13; *What the Definition says* |
| both as options of the language, as `--flex-records` is | D18, D19; M15 |

## What the brief gets wrong, leaves open, or makes dangerous

The items are grouped as in functors-units.md, each with the decision or
milestone that answers it. The review below the brief's line is part of
what the owner handed over, so its claims are held to the code too.

### Wrong, or out of date

- **W1. The review was written before functors-units M7, and parts of it
  are stale:**
  - `Elaborate.lintSummaries`, which held each functor's copy to its
    summary under `--lint`, went with the copies (`eb918dfce`). `--lint`
    checks nothing in the elaborator now;
  - `StrApp` has no slot for a copy;
  - the rule for casts is on `functor_cast`, not `unsafe_cast`. It already
    refuses a cast between two types neither of which is `unit`, and
    `unsafe_cast` itself is not checked at all;
  - `--functors=functions` is gone;
  - overloading is settled at the end of each top-level declaration, not
    by `finish`.

  The review's other claim about casts, that the rule "refuses a valid cast
  through `unit`", could not be shown: it refuses only a cast back from
  `unit` to another ground type than the one cast from. *Where we are*.
- **W2. "That is for memory safety, since a `.rbc` is untrusted input."**
  Not under tier 2 of the JIT, which trusts reps that the loader checks
  only on some writes and on no read (*Where we are*). E7's segfault is
  the reproducer. D8, M8's handover to the VM roadmap.
- **W3. LowLint checks "that representations agree".** Its `agree` is
  symmetric and lets `any` match every rep (`lowlint.sml:181-184`), so it
  takes a downcast for an agreement. M6.
- **W4. "`make check-levels` (every program of `tests/lang` and
  `tests/perf` at `-O0` and `-O2`)".** With the stack target only: neither
  `Regs` nor `Link` goes through it. E9 ran its programs on the register
  target, and a true `--units` build, clean. M1.
- **W5. "Ways to go further" expects lint in new places to catch bugs.**
  E9 put every lint in every place it did not run, `lib/cache`
  included, and found none. The finds came from new rules (E10) and new
  checkers (E6, E7). Placement is a guard against regressions.

### Contradictory

- **C1. "An independent sml 97 type checker", and types in the AST, which
  the inferencer puts there.** The Definition's rules leave choices open,
  so a checker must be handed the choices made, and only the elaborator
  has them (*What the Definition says*). The independence the brief asks
  for is of the algorithm, not of the data: AstLint reads the witnesses
  and works out everything else without the elaborator's code. D4.
- **C2. "So cheap that they can be always on", and the lints as they
  are.** Today's lints cost 16% to 148% of a compile (E1), and the
  cheapest single one, MidLint before Lower, 4.6% of HaMLet and 13.1% of
  the bootstrap (E2). Cheapness has to be earned, by M2's two fixes, and measured
  against a threshold (D13). And an always-on check that fires stops a
  correct user's compile.

### Ambiguous

- **A1. "Types in the ast."** On every node, or on the nodes where the
  Definition leaves a choice? And in which type language: the IR's `Ty.ty`
  erases labels, abstraction and equality. Witnesses always, every node's
  type when asked, in a type language of the source's own (D1, D2, D7).
- **A2. "Following the sml 97 defintion."** The Definition has defects
  (Kahrs, Rossberg), and Rune has documented deviations and extensions. A
  checker that follows it has to say how it reads each of them: by
  runespec's names for the readings (D3).
- **A3. "Types … of the bytecodes."** ML types, or representations; the
  register code, or the stack code too. Representations, with shapes one
  level up in Low (D8). The register code, which tier 2 trusts (D11).
- **A4. "After linking."** The compiler's static link happens at two
  sites, reached three ways (a build in units, `.rbu` files on disk, the
  compiler library), all this roadmap's. `Runtime.load` in the VM is the VM roadmap's.
  And it is a choice between checking the linked program and checking
  interfaces (D15).
- **A5. "The right places."** After every pass, inside `simplify`'s
  interleaved rounds, or at the representations' boundaries. All of them,
  at different levels (D12, D13).

### Dangerous

- **X1. A verifier taken for protection.** Lua removed its bytecode
  verifier as unsound, and any verifier's bug "can potentially enable a
  security attack" (Leroy). The compiler's verifier finds the compiler's
  bugs; it must not be described as making `.rbc` files safe. D8, M8.
- **X2. A false alarm in a user's compile.** A check that is always on and
  wrong stops a correct program. The threshold of D13 requires no alarm on
  any corpus and an escape (`--lint=off`), and the message says whose
  fault it is. M3.
- **X3. Types on every node, kept always.** The prototype's zonk made the
  front end 41-52% dearer, and the editor holds every unit (E5). Witnesses
  only, zonked when read (D2).
- **X4. A checker that shares the checked code** finds that code's bugs
  never. AstLint calls nothing of `Unify`, `SigMatch` or `Types`, and
  `RegVerify`'s rules come from `src/isa`, not `Regs` (D4, D10).
- **X5. A check that is off rots.** GHC's STG Lint's typing and SML/NJ's
  FLINT check did (E11). Every check this roadmap adds runs in every test
  compile, at level 2 (D13).
- **X6. A check that changes the output.** `--mid-roundtrip` did (E9). M1
  tests the property for every check.
- **X7. Recording more in the elaborator** could change what it accepts,
  or what Translate makes. M11's gate is Mid byte for byte the same, and
  AstLint's own test is the same bytes with it on.
- **X8. Checks constrain the passes.** A pass must keep the invariants the
  checks hold: declared reps, shapes, type variables in scope. Lift does
  not today (E10). Erlang's validator limited its optimisers (E11). The
  rules must say what each phase keeps.

### Where this roadmap recommends otherwise than the brief

- **The AST holds the witnesses, not a type on every node** (D2). Every
  node can still have its type, worked out when the editor asks (D7), so
  the brief's three uses are all served.
- **AstLint is not always on.** It costs about elaboration again (E6). It
  runs in every test compile (D13).
- **The bytecode is typed by representations, not by ML types** (D8), and
  only the register code is verified (D11).
- **The lint's placement is not where the bugs are** (W5). The roadmap
  still places checks everywhere, at levels, as guards.

## Where we are

At functors-units `d551f19dd`, the tree this roadmap assumes merged into
master. Paths are relative to the root; line numbers are of that commit.

### The lints and how they run

There is one switch. `--lint` sets `Pass.lint`, and `Pass.linting ()` is
true with it or with `RUNE_LINT` set and not empty (`util/pass.sml:20-25`;
the paths of this section are under `lib/compiler/`).
- **`Pass.stage`** (`:94-125`) runs a pass, prints its `--pass-stats` line,
  and then, when linting, the stage's `check`. A breach raises
  `Error.Bug`, which the stage names: "lint after *pass*: …". The driver
  prints it and fails (`src/driver/main.sml:1226`).
- **Cost accounting:** lint time, with the dumps', is summed into one
  line, `checks`, and only for stages at depth 0 (`:117-122`). Under
  `--units` every stage runs inside `unit-passes`, so there its lint time
  is not shown apart: it is counted in `unit-passes`'s own time.
- **`--mid-roundtrip`** prints Mid and reads it back in the `mid` stage's
  check only (`driver/pipeline.sml:10`). It does nothing without lint, and
  nothing after any later pass.

The checks:

| Representation | Lint | Runs after | What it checks |
|---|---|---|---|
| the syntax | none | -- | -- (`Elaborate.lintSummaries`, which held each functor copy to its summary, went with the copies in functors-units M7, `eb918dfce`) |
| Lambda | `LambdaLint` (`core/lambdalint.sml`, 211 lines) | `translate` | scope; a stamp bound once; `Fail` and `Jump` only in tail position of their scope; a letrec of functions; types, *inferred* bottom-up from the parts |
| Mid | `MidLint` (`core/midlint.sml`, 268) | `mid`, `midcanon`, `expand`, `shake`, `lift`, `workers`, `simplify`, `refs`, the second `shake` | scope; a stamp bound once; globals defined once; instances' arity; jumps to join points in scope; workers' arity; constructors against their declared argument; types *checked* against what each context wants; casts of `functor_cast` |
| Low | `LowLint` (`backend/lowlint.sml`, 296) | `lower` | SSA; blocks and their jumps; handlers' depth; known calls' arity; closures; representations agreeing with the operations, primitives and fields made in the same function |
| registers, stack | none | -- | the stages' check is `fn _ => ()` (`driver/pipeline.sml:72,75`) |
| a linked program | none | -- | `Link.program` resolves names and nothing more (`backend/link.sml:173,183-184`) |
| a `.rbc` | the VM's loader, always | loading | opcodes, operands' ranges, jumps and entries on instruction boundaries, the stack's height (*The instruction lists*, below) |

Without the switch, nothing checks a representation. What runs on every
compile is:
- the passes' own assertions, such as ToMid's "not in scope" and Lower's
  "a known call of no function" (`lower.sml:1291`);
- the link's resolution of names;
- the decoders of cached units, where a bad entry is a miss
  (`main.sml:739-742`);
- the VM's loader.

### Where lint runs, and where it does not

**Whole programs**, in order (`main.sml:1088-1196`, `pipeline.sml:25-76`):

| Stage | -O0 | -O1 | -O2 | Lint after it |
|---|---|---|---|---|
| lex, parse, elaborate | ✓ | ✓ | ✓ | none: elaboration is a `frontStage`, a `Pass.stage` whose check is `fn _ => ()` (`main.sml:1088-1091,1150`; units `:785`) |
| `translate` (with `trees` at -O1 and up, `matchcomp.sml:652`) | ✓ | ✓ | ✓ | LambdaLint |
| `mid`, `midcanon` | ✓ | ✓ | ✓ | MidLint |
| `expand`, `shake`, `lift`, `workers`, `simplify`, `refs`, `shake` | | ✓ | ✓ | MidLint after each |
| inside `simplify`: `inline`, `specialise`; `equality` at -O2 | | ✓ | ✓ | none of their own: they run interleaved in one traversal of three rounds (`simplify.sml:1994-2051`) |
| `lower` (with `results` inside it from -O1, whole programs only, `lower.sml:804,833`) | ✓ | ✓ | ✓ | LowLint; `results` is an analysis inside Lower, with no output of its own |
| `registers` or `stack` | ✓ | ✓ | ✓ | none |
| `emit` | ✓ | ✓ | ✓ | none |

**`--units`** compiles each unit through the same stages, without
`midcanon` and `shake` (`pipeline.sml:84-128`).
- A unit's imported globals are typed by `ToMid.globalScheme`, from
  `Ty.binders` as the exporting unit's basis loaded them
  (`MidLint.importedScheme`, set in `UnitBasis.startSession`,
  `unitbasis.sml:120`; `tomid.sml:33-44`), not by the scheme the exporting
  unit's Mid gave its definition.
- LowLint skips calls of imported functions (`lowlint.sml:240-243`).

**The cache.**
- A hit reads only the unit's code (`UnitFile.read`, which re-makes the
  labels from the jump targets and the meta, `unitfile.sml:233-262`); its
  Mid is not read (`main.sml:710,728-731`).
- Under `--units --whole`, the cached Mid is decoded (`UnitMid.read`) and
  first linted once `MidCanon.concat` has joined the units
  (`main.sml:983`), then after every pass of `lowOfMid`, `midcanon` again
  included. No unit's decoded Mid is linted on its own.
- The compiler library's decoded Mid goes straight into `lowOfMid` and is
  not linted at -O0 (`api/session.sml:110-121`).
- The functor bodies `MidCodec.read` decodes are linted only once `expand`
  has put them into a unit.
- The frozen Basis cache, `lib/cache`, is built without `--lint`
  (`Makefile:461-463`), and the cache's configuration does not record lint
  (`unitcache.sml:104-110`). So a linted compile on a warm cache lints none
  of the units it takes from it, the Basis included: the Basis's units have
  never been linted.

**Linking** happens at two sites, reached three ways:
- `linkUnits` (`main.sml:996-1000`), after a build in units (`:992`) and
  from `.rbu` files on disk (`linkUnitFiles`, `:1038-1063`);
- the compiler library (`api/session.sml:364-368`).

None checks its result. An imported function is an index at or above the
unit's own count, with no code or meta (`link.sml:176-185`), so a unit's
calls into another are checked by nothing, before the link or after it.

### What runs with lint today

`bin/rune-test` sets `RUNE_LINT=1` unless it is set (`Makefile:1911`), so
every compile a test makes is linted, since 2026-10-25.
- **`check-levels`** builds every program of `tests/lang` and `tests/perf`
  at O0, O2, U0 and U2 (`--units --whole`), each with
  `--lint --mid-roundtrip` (`tests/runner/oracles.sml:81-95`). It compiles
  with `bin/rune-stack` (`Makefile:95-96`), so neither the register target
  nor the link of a build in units goes through it.
- **Also linted:**
  - `check-units` (`oracles.sml:458`);
  - `test-ir` (`tests/runner/tools.sml:38`);
  - the bootstrap, `bin/rune.rbc` and `bin/rune.stack.rbc`
    (`Makefile:1780-1786`);
  - the benchmarks' measurement builds (`Makefile:2082-2111`);
  - the functor generator (`tests/runner/functorgen.sml:1103-1111`).
- **Cleared:** the budgets (`tests/runner/budgets.sml:28-31`), which count
  the compiler as shipped, and the IntInf hardening fixtures, which call
  primitives at wrong types on purpose (`tests/runner/intinfhardening.sml:48-51`).
- **Negative tests:** three, all of MidLint (`tests/ir/mid-lint-{tyargs,type,jump}.mid`).
  Only Mid has a reader (`--read-mid`). `Low.show` loses information, and
  Lambda has no text form that can be read back.

### What the lints miss

- **LambdaLint** infers bottom-up, with `Never` for code that does not
  return (`:23`).
  - Lambda's binders carry no type variables, so an `Inst` may instantiate
    a `Gen` that an enclosing scope fixes (`:66-70`).
  - An exception's payload is not checked against the exception's
    argument (`MkExn`, `:174-177`); `ExnArg`'s type is trusted (`:179`).
  - Nothing checks a primitive's signature or a constant's kind (`:71`);
    `Prim (p, NONE, …)` is allowed for three primitives (`:195-205`).
- **MidLint** checks each expression against the type its binder or
  context declares (`:223`); a step's type is computed from its atoms, and
  no type variable is inferred.
  - There is no environment of type variables. `Ty.equal` compares the
    ids of hash-consed nodes (`ty.sml:509`), so a variable that nothing
    abstracts over is a type of its own, equal only to itself, and one left
    free by a substitution goes through.
  - `MkExn` (`:212`) and `ExnArg` (`:214`) are unchecked, as in Lambda.
  - A `Prim`'s signature is unchecked (`:174-187`), so a primitive at a
    wrong type is caught only by LowLint's representations, if at all.
    `Const` is trusted (`:141`).
  - `SetGlobal` accepts any defined global, and a `Do`'s list of globals is
    not compared with what it sets (`:215-218, 264`). The `_dynamic` bug of
    2026-10-25, slots set but missing from `Do`, was of this kind.
  - **Casts.** The rule is on `functor_cast` (`:72-110`, `:175`), which only
    `Translate.toUnit` and `fromUnit` make (`translate.sml:671-672`).
    - It refuses a cast neither side of which is `unit` (`:91-96`), and a
      cast back from `unit` to another ground type than the variable was
      cast from (`:97-110`).
    - The second rule skips type variables (`ground`, `:74-81`).
    - It follows only a variable bound directly to a cast, not an alias or
      a join's parameter (`:228, 262`).

    `unsafe_cast` is not checked at all. Translate makes it for open
    constructors (`:818`) and dynamic modules' slots (`:591-648`), and the
    Basis's `Compiler` structure uses it (`lib/basis/compiler.sml:290`).
- **LowLint**
  - `agree` lets `RAny` match anything and is symmetric (`:181-184`): it
    takes `con` for `ptr`, `con` for `con0`, and `any` for a typed rep.
  - A constructor's or a tuple's fields are held only to a `Con` or
    `Tuple` made in the same function (`made`, `:231, 261-265`).
  - Low's `Con`, `Field` and `Decon` carry no datatype (`low.sml:56-60`),
    so nothing can check a layout made in one function and taken apart in
    another.
  - In a unit, unknown functions' arity and reps are skipped (`:45-54,
    240-243`).
- **The lints check shape and types, not meaning.** The independent
  review's two worst findings of functors-units M6c passed them, being
  well typed: a program's own `if n = 0` folded as though it were a
  descriptor's test, and a constructor built boxed in one function and
  taken apart flat in another. What found those was comparison: -O0
  against -O2, a flag on against off, the hosts' builds against each other,
  a whole compile against units (S42), and generated programs run every
  way.

### What the lints cost

E1 measures it. No lint memoises anything: `MidLint.check` builds fresh tables on
every call (`midlint.sml:38-73`), and the only sharing is `Ty`'s
hash-consing.

### The syntax and what the elaborator leaves on it

There is one `Ast` datatype (`frontend/ast.sml`): 73 constructors and 8
records.
- **Two parsers make it:**
  - the batch front end (`frontend/`), for the driver, the REPL, the
    compiler library and `CompilerQuery`;
  - the editor's incremental one (`syntax/`), a fork of the batch parser.
    `SyntaxAst` opens the same `Ast`, and its `copy` makes every node
    afresh and resets every slot at the bridge (`syntax/ast.sml:1-8,139-143`;
    `syntax/incremental.sml:156`).
- **Every constructor has a span** (`ast.sml:161-232`). Match rules,
  clauses and record labels have none.
- **Spans are not unique:**
  - an infix application and its argument tuple share one
    (`parser.sml:478`);
  - `val … and rec` desugars into a `DLocal`, `DValRec` and `DVal` that
    share one, and the re-exported variables share their binder's
    (`:630-643`).

**The slots.** Thirteen constructors carry a mutable slot, and so do
`fundef.info`, `ExnDecl` and `ExnRepl`:

| Node | Slot | What it holds |
|---|---|---|
| `EVar` | `varinfo option ref` | what the identifier is, and its instance at this use (`VLocal`, `VGlobal`, `VCon`, `VExn`, `VBuiltin`, …; `ast.sml:27-34`) |
| `EScon`, `PScon` | `Types.ty option ref` | an overload variable, defaulted later |
| `EList`, `EFn`, `EPrim` | `Types.ty option ref` | the list's, the function's, the primitive's type |
| `ESelect` | `Types.ty option ref` | the record's type (not the selector's) |
| `PRecord` | `Types.ty option ref` | filled only for a flexible record |
| `PVar`, `PApp`, `PLayered`, `fundef.info`, the exception bindings | `patinfo option ref` | the binder's or constructor's identity, with no type |
| `StrDynamic`, `StrExport` | `dynamic option ref` | the dynamic module's record |

**No type is kept** for:
- applications, tuples, records;
- `if`, `case`, `let`, `handle`, `raise`, `while`, `andalso`, `orelse`,
  sequences, a typed expression;
- a constructor's instance in a pattern, a list pattern's element, a
  variable pattern (its scheme is in `Ty.binders` by stamp, but not its
  type at the binding), a wildcard;
- the type a `: ty` elaborated to, or any type expression.

**Nothing of the module language is kept** on the syntax since the copies
went in M7:
- `StrApp` is `StrApp of string * strexp * span` (`ast.sml:118`);
- an application's data lives in `Elaborate.calls` and `bodies`, by span,
  and only when code is made (`elaborate.sml:765-772`).

**The tables by stamp** (`core/ty.sml:186-235`):
- `binders`, every variable's type or scheme;
- `exnArgs`;
- `datatypes`, each datatype's parameters and constructors;
- `realizations`, what each opaque name stands for.

They hold the elaborator's types (`Types.ty`; `Types.tyfcn` for
realisations; Mid's text may enter a datatype as `Ty.ty`,
`ty.sml:191-194`). `Ty.datatypes` keeps a datatype as
it was first entered, with `eq=true` from before the equality fixpoint
settles it (`elaborate.sml:1456,1498` against `:1524-1529`).
`UnitBasis.undo` takes a unit's entries out of them once it is compiled:
`binders`, `exnArgs` and `realizations` by range of stamps, `datatypes`
by restoring the elaborator's snapshot (`unitbasis.sml:734-752`;
`elaborate.sml:2085-2087`).

**How the elaborator decides what a checker would check:**
- **Generalisation** is done in place: a generic variable is one whose
  level is `genericLevel` (`types.sml:35-38`; `unify.sml:224-240`). A
  binder's scheme and the types inside its body share cells, and nested
  binders cannot be told apart by level. Translate relies on this
  (`translate.sml:133-148`).
- **The value restriction:** `nonexpansive` (`elaborate.sml:1170-1186`).
  It takes `(e : ty)` and a constructor applied to a non-expansive
  argument, but not a constructor *expression* in parentheses with a type,
  `(conexp : ty) atexp`, which 4.7 includes (E6).
- **Explicit type variables:**
  - `unguardedValDec` collects them (`:356-425`);
  - `valScope` binds them as rigid variables (`:429-438`);
  - `checkGeneralised` checks they were generalised (`:444-453`).

  The set scoped at each `val` is not recorded.
- **Equality:**
  - flags on type variables and type names, enforced by `makeEq`
    (`unify.sml:70-97`);
  - datatypes by a greatest fixed point (`elaborate.sml:1504-1527`);
  - an abstype keeps its stamps with `eq=false` (`:1543-1549`) where the
    Definition makes new names;
  - `ref` and `array` admit equality whatever their argument.
- **Overloading:** a variable of kind `KOverload`, settled by
  `resolvePending` at the end of each declaration at top level (`:2138`) and
  of each functor body (`:1708`). `finish` (`:261-270`) settles the
  flexible records of `program` mode and runs the deferred exhaustiveness
  checks.
- **Flexible records:** a variable of kind `KFlex`, settled per
  `--flex-records` mode:
  - at the binding (`:291-296`);
  - after each `val` or `fun`;
  - at the end of the topdec, which is the default (`Parser.endsTopdec`,
    `:2137-2147`);
  - at the end of the topdec, unless generalised at its binding
    (`topdec-monomorphic`, `:297`);
  - at the program's end.

  A topdec is not a declaration at top level: it runs to `;` or the end of
  the file.
- **Closure (rules 87-89):** `checkClosed` and `pendingClosed`
  (`:2054-2065, 2137-2146`).

**The module language** (`elab/env.sml`, `elab/sigmatch.sml`):
- A signature is `sigma = {bound, env, origin}` (`sigmatch.sml:9`). A
  functor is `FunInfo {param, paramSig, summary, binding, code}`
  (`elaborate.sml:28-32`), and every application is typed by the summary
  (rule 54; `:1775-1838`).
- `SigMatch.match` builds φ by looking up the signature's paths, then
  calls `checkEnrich` (`:286-326, 360-389`). That skolemises and unifies
  (`:190-261`), which for enrichment amounts to a one-way match.
- After elaboration nothing of a match is kept but `Ty.realizations` for
  opaque names and an application's `calls.bound`. The actual environment,
  the instance of the signature, φ, the thinning and the fresh names are
  dropped.

**Errors** are strings: `CompileError of span * string`
(`util/error.sml:7-9`). A mismatch is formatted by `unifyAt` as "*context*:
type mismatch between *A* and *B* (*reason*)" (`elaborate.sml:125-134`).
- `Diagnostic` renders a level, a span and a message; it has no datatype
  of errors (`util/diagnostic.sml:83-209`).
- Recovery is per declaration at top level: a snapshot is restored and the
  error reported (`elaborate.sml:2075-2158`). A declaration that fails
  leaves its names unbound, so
  `fun f (x, y) = if x then y + 1 else "no"  val z = f (true, 2)`
  reports the mismatch, then "unbound variable or constructor: f".
- The analysis engine does not recover (`analysis-engine.sml:73`): the
  LSP gets the first error of a unit and no facts for it.

**The LSP's types** are facts collected per unit after elaboration
(`api/facts.sml:9-63`), stored as printed strings
(`analysis-engine.sml:171-187`).
- **What they cover:**
  - constants, a variable's instance, lists, `fn`, `_prim`;
  - a flexible record pattern;
  - binders' schemes from `Ty.binders`;
  - records through `#lab` (field completion).
- **Hover:** a position goes to the smallest fact span around it, by a
  linear scan (`analysis.sml:99-119`). Hover over an application, a `case`
  or a tuple has no type of its own: it answers the smallest enclosing
  fact's, or nothing. Over a type, a structure or a functor
  only its kind and name (`src/lsp/worker-analysis.sml:651-664`).
- **Inlay hints** cover unannotated variable patterns
  (`analysis.sml:120-174`).
- Each fact is printed with a fresh printer, so a type variable may be
  `'a` in one hover and `'b` in the next (`analysis-engine.sml:172`).

### Lambda and Mid's types

- **`Ty.ty`** is the type of both. It is hash-consed since performance M4
  (`ty.sml:24-67`): a node has an id, a hash, a size and its free
  generics. Its forms:
  - `Gen`, a generic variable by the elaborator's id;
  - `Var`, an unresolved one, equal only to itself;
  - `Con (stamp, name, args)`;
  - `Tuple`;
  - `Arrow`;
  - `ExnCon`.
- **What `Ty.fromTypes` erases** of the elaborator's types (`:355-372`):
  - **labels:** records become tuples in label order (`:370`);
  - **abstraction:** opaque names are replaced by their realisations
    (`:360-362`);
  - **arity:** a datatype declared in a function gets the function's type
    variables as extra parameters (`:364-369`, `Ty.extrasOf`);
  - **equality:** no variable or name carries it.

  This is right for the IRs and wrong for a checker of the source.
- **Mid's binders** say their types (`core/mid.sml:26-78`):
  - a `Let`, a `Val` and a `Do` carry a scheme;
  - a function carries its type variables, typed parameters and result
    type;
  - join points are monomorphic;
  - a use is `Var` or `Global (x, tyargs)`.

  ToMid gives a binder the generics of its type that no enclosing binder
  abstracts over (`tomid.sml:56-61`).
- **Lambda's `Inst (Var|Global, t)`** gives the instance type, which ToMid
  turns into type arguments by matching (`tomid.sml:124-139`).

### Low and its representations

- **`Low.rep`** is one of `RAny`, `RInt`, `RWord`, `RReal`, `RChar`,
  `RCon0`, `RPtr`, `RCon`, `RUnit`, `RInt64` and `RWord64`, with codes
  0-10 (`low.sml:27-35`).
- **It comes from Mid's types** in `Lower.repOfTy` (`lower.sml:351-388`).
  - A type variable gives `RAny`, and a global or a captured value read
    where it is used has none (`lower.sml:900, 910`). So a polymorphic
    callee's result, a
    field of a polymorphic tuple, a captured value, a global and an
    exception's argument are read as `RAny` and then used at a typed rep.
    These are downcasts, justified only by ML typing.
  - The globals in which `results` returns a datatype's fields, one set
    per datatype and shared by its constructors, are read as `RAny`
    (`defAny`, `lower.sml:403-407, 1083-1085`). The slots of a tuple
    result, shared by width, are read at their fields' reps (`:976-986`).
- **A constructor's layout** is fixed per datatype from its declared
  argument (`backend/rep.sml:29-35`, from `Ty.layoutOf`). Lower consults
  it (`lower.sml:944-1111`); Low's nodes do not carry it.

### The instruction lists

- **What both targets share** (`backend/code.sml:13-41`):
  - instructions as `Op`, `Ops`, `OpLab`, `OpLabImm`, labels and
    positions;
  - per function `{id, nlocals, code, name, meta}`;
  - per program the constants, the number of globals, the functions and
    the debug information.

  No handler table exists: handlers are `PUSHHANDLER` and `POPHANDLER`.
  Nothing records a closure's size, a function's result rep or the reps of
  globals.
- **The stack code** (`backend/stack.sml`, 387 lines):
  - keeps single-use values on the stack as trees;
  - shares locals by linear scan *whatever their reps* (`:151-188`), so a
    local's type changes along a function;
  - has `meta = NONE`.

  Nothing trusts its types: the stack VM and runeopt test or use values
  by kind. runeopt has an untyped dataflow check of it in SML
  (`src/opt/rbccheck.sml`): the stack's height and the handlers' depth
  agree on every path, no jump leaves a function, no `RET` or `TAILCALL`
  with a handler set, one arity per function.
- **The register code** (`backend/regs.sml`, 348 lines):
  - shares a register only between variables of the same rep
    (`:126-130`), so every register but one has a single rep per function;
  - the exception is a scratch register of rep `RAny`. It takes unused
    results (`:156`), holds unit for `CLOSURE` (`:219`), and holds a value
    while a cycle of parallel moves is broken, from which a typed register
    is then written (`:236-239`);
  - a function with no parameters gets an unused `RAny` register 0
    (`:103`).

  `meta` carries:
  - the arity;
  - each register's rep;
  - each block's label and parameter registers;
  - the loop heads (`:321-334`).

  The JIT never reads the blocks; it uses the loops only to weight the
  choice of homes (`runtime/register/jit/compile.c:494-512`).
- **Encoding and decoding.** `Emit` writes `.rbc` (`backend/emit.sml`),
  `UnitFile` writes and reads `.rbu`, and `Link.program` renumbers
  (`backend/link.sml:186-199`).
- **The instruction sets are described in `src/isa`:**
  - `isa.sml`, the language, and `stack.sml`, the stack's instructions
    in it: operand kinds, pops, pushes, flow, handlers, raises;
  - `regs.sml` for the registers: operand kinds, flow, handlers, raises,
    but no pops or pushes, `:63-76`.

  `IsaGen` and `RegGen` generate `opcodes.sml` and `regcodes.sml`, which
  the compiler includes. They carry each opcode's number of operands, its
  operand kinds and how it is relocated, and no more.
- **What `src/isa` leaves out:**
  - which register an instruction writes (RegGen takes the operand named
    `d`, `reggen.sml:125-135`);
  - the implicit traffic of `PRIM` (its arguments pushed), `RESULT` and
    `CATCH`, which exists only in the instructions' C (the interpreter's
    bodies, as strings in `src/isa/regs.sml`; the JIT's, by hand) and in
    comments;
  - any value type.
- **Primitives:**
  - each primitive's type is a string of SML (`isa.sml:109-115`);
  - `Prims.repsOf` is generated from it by IsaGen's heuristic split on `*`
    (`isagen.sml:213-240`);
  - 28 of the 414 have no result rep;
  - `Regs.imagePrims`, the primitives that must be `PRIMPUSH`, is a list
    written by hand (`regs.sml:38`).

### The VM's loader, and what tier 2 trusts

**The loader** (`runtime/register/isa_regs.c:55-193`, and
`runtime/stack/isa_stack.c:124-209`, with `stack_heights` at `:23-106`,
for the stack VM) runs on every load
of a program or a unit. It checks:
- the opcodes, and each operand against its kind's range;
- that jumps land on instruction starts, and for the register VM within
  their function;
- the function entries, and the block and loop entries of the meta;
- the stack's height on every path (stack VM);
- `CALLK`'s count against the callee's `nlocals`;
- for the register VM, the rep a write gets where the instruction itself
  fixes it: `INT`, `CONTAG`, `UNIT`, `CON0`, the allocations, `SELF`,
  `EXNCON`, `CONST` by the constant's kind, and `PRIM` by the primitive's
  result.

It does not check:
- `MOVE`, `RESULT`, `CATCH`, `GLOBAL`, `ENV`, `SELECT`, `DECON`, `FIELD` or
  `EXNARG`;
- any read;
- that `CALL`, `CALLK` and `PRIMPUSH` are followed by `RESULT`;
- that a handler's block starts with `CATCH`.

`runevm --checked` adds a test of the tag where `DECON` and `FIELD` take a
constructor apart (`runtime/register/reg_cases.h:316,584`; the JIT's `checked_tag`,
`emit.c:927-937`).

**Tier 2 of the JIT trusts the reps** (enabled at `compile.c:1130-1135`):

| Rep | Trusted as | Where |
|---|---|---|
| `REAL` | an XMM home; the slot decoded with no test of its kind | `compile.c:541`; `masm.c:221-247, 321-327` |
| `INT`, `WORD`, `INT64`, `WORD64` | raw homes; arithmetic and comparison without tests | `compile.c:538`; `masm.c:283-300, 576-578, 1246-1255`; `emit.c:274-295` |
| `INT`, `WORD`, `CHAR`, `CON0` | equal by word | `masm.c:1237-1245` |
| `PTR`, and `CON` as a constructor | dereferenced with no test of immediate or kind, *for every kind of object* | `ms_trusts`, `masm.c:1256-1274` |
| `CON0` | the tag is the word shifted | `masm.c:1414` |

So:
- `SELECT` and `FIELD` on a trusted `PTR` skip the length check
  (`emit.c:912-916, 1058-1061`);
- `CALL` skips the range check of the function index (`emit.c:1402-1407`);
- tier 2 puts no unit into a callee's registers. Those past a known
  call's arguments hold what the stack's clean part holds, unit or a value
  written since the last collection (`compile.c:1117-1121`), while the
  loader only bounds `CALLK`'s count.

A wrong rep in a register, a tuple of the wrong arity or a tag never tested
therefore reads outside an object or jumps to an arbitrary function, in
silence. The interpreter and tier 1 test kinds and stop with a fatal
error. The VM's liveness, from which the collector takes its roots, is
computed from the code (`runtime/register/live.c`). It over-approximates:
- registers past the 64th count as live (`:6-7`);
- the live-ins of every handler are added at every instruction that can
  raise (`:104-110`).

So a typed register may hold unit before it is first written, which the
JIT tolerates only when it loads homes (`masm.c:228,282`).

### Existing machinery to build on

- **`tools/mutate/mutate.sml`, `tests/runner/mutants.sml` and
  `make test-mutants`** (`Makefile:1950`), the mutation tests of the
  libraries. A supervisor and limits come with them, and the rule that an
  error of the controller never counts as a mutant killed.
- **The functor generator** (`tests/runner/functorgen.sml`), a generator
  of programs run every way.
- **runespec** (branch `runespec`, not merged): a rule interpreter of the
  Definition in SML (15.6k lines in `src/spec`), with the Definition
  transcribed in its own notation (`spec/sml97/core.rs`, `modules.rs`,
  `programs.rs`: all 189 rules). It searches for derivations by
  unification and backtracking (`engine.sml:1-15`), and passes 297 of
  `tests/lang` (no expected failure, 41 skipped). Rune's deviations are a
  layer of eleven readings (`spec/rune/rune.rs`), each with a name. It is
  an oracle, not a checker for every compile: `lib/basis` takes 37 s
  through its rules.

## What the Definition says

The brief asks for "an independent sml 97 type checker - not type
inferencer - following the sml 97 defintion". The Definition of Standard
ML (Revised, 1997) gives its static semantics as inference rules. Chapter 4
covers the Core: rules 1-49. Chapter 5 covers the modules: rules 50-89. The
rules relate a context to a phrase and to what the phrase elaborates to:
`C ⊢ exp ⇒ τ`, `B ⊢ strexp ⇒ E`.

The rules are declarative. They say what a well-typed program is, not how to
find its types, and in several places they leave a choice open. An
*inferencer* makes those choices itself, by unification. A *checker* is
handed them, and verifies that a derivation exists with exactly those
choices. The rest of this section lists the choices, since they are what
the syntax must record for a checker to exist (*The architecture*, D1).
Rule numbers are the book's, as runespec transcribes them
(`spec/sml97/core.rs`, `modules.rs`, `programs.rs` on branch `runespec`).

### The choices a checker is handed

In the Core, every type follows from the types of the leaves and the
binders, by rules that only compare types for equality. The open choices
are:
- **an instance at every use of a value identifier** (rule 2, and rules
  35 and 41 for constructors in patterns: `σ ≻ τ`). `EVar`'s `varinfo`
  records it in expressions today; nothing records it in patterns;
- **the type of every variable pattern and wildcard** (rules 32 and 34).
  The pattern `x` in `fn x => e` may have any type; nothing in the syntax
  says which;
- **the record a wildcard row `...` stands for** (rule 38): the labels and
  types it hides;
- **the type a special constant is given** (rules 1 and 33, and Appendix E
  where the constant is overloaded);
- **the type of a `raise`** (rule 11), where the context does not fix it;
- **the type names a declaration creates** (rule 17, a datatype; rule 19,
  an abstype). They must be new, `t ∉ T of C`. The names are the
  elaborator's stamps.

Given these *witnesses*, checking the Core is deterministic:
- each node's type is worked out from its children's;
- an application checks that the function's domain equals the argument's
  type (rule 8);
- a `case` checks that every rule's pattern and body agree (rules 13, 14);
- a typed expression checks that the annotation's type equals the
  expression's (rule 9).

No unification is needed, only equality of types, which hash-consing
makes a comparison of identities. This is how GHC's Core Lint and MLton's
type checks work, on languages whose binders carry their types (*What the
literature says*).

Two parts of the Core are computations, not choices, and a checker
recomputes them:
- **Closure** (4.8, rule 15). `Clos_{C,valbind} VE` generalises the type
  variables of `VE` that are not free in `C`. The binding is elaborated in
  `C + U` but closed in `C`, so the explicit type variables `U` are
  generalised with the rest. For a binding that is not non-expansive it
  generalises none.
  A checker needs `tyvars C`, which only its own environment can give,
  because the elaborator generalises in place and shares cells between a
  scheme and the body it was made from (*Where we are*).
- **Non-expansiveness** (4.7) is syntactic:

  ```
  nexp    ::= scon | <op> longvid | { <nexprow> } | ( nexp )
            | conexp nexp | nexp : ty | fn match
  conexp  ::= ( conexp <: ty> ) | <op> longvid
              (longvid not ref, and of constructor or exception status in C)
  ```

  This is the grammar from runespec's `core.rs:254-257`. The derived forms
  are first replaced by their equivalent forms.

The parts that are not syntax-directed in the Definition are left to the
implementation, and must therefore be read in Rune's terms:
- **Explicit type variables** (4.6). A type variable that occurs
  unguarded in a `val` and in no larger one is implicitly scoped at that
  `val`. The scoping is a pass over the syntax before elaboration, so a
  checker recomputes it from the syntax, as Rune's `unguardedValDec` does.
  Rule 15 then requires `U ∩ tyvars VE' = ∅`.
- **Overloading** (Appendix E). The type of an overloaded identifier or
  constant must be determined "by the surrounding text", with defaults
  (`int`, `word`, `real`, `string`, `char`) otherwise. The surrounding text
  is "no larger than the smallest enclosing structure-level declaration",
  and an implementation may require a smaller one.
  - Rune today settles it at the end of each declaration at top level, a
    whole structure or `local`, and after each functor body
    (`resolvePending`). That is larger than the bound: a documented
    deviation, runespec's `E.topdec`.
  - E13 found four choices among eight compilers; D18 makes the context an
    option.

  A checker can verify that each choice belongs to its class. That the
  choice equals the default where nothing determined it can be checked
  only against a record of the choice, since both choices type-check.
- **Flexible records** (4.11, item 1). A pattern row with `...` must be
  determined by the program context; "context" is again the
  implementation's (`--flex-records`, five modes in Rune). A checker can
  verify the record the row became, but not the policy that chose when.
- **Free type variables at top level** (rules 87 and 89, Appendix G.8):
  `tyvars B'' = ∅`. Implementations may refuse such a program or replace
  the variables by monotypes; runespec's reading is named `87.free`. E13
  found five behaviours, two of them outside G.8. D19 makes the choice an
  option.
- **Further restrictions** (4.11, items 2 and 3): matches that are not
  exhaustive and redundant rules are warnings, not part of typing.
- **Equality.** Datatypes admit equality by the greatest fixed point (4.9,
  "maximise equality"). An abstype's type names do not admit equality
  outside it (rule 19, `Abs`). A type variable `''a` ranges over equality
  types; so `=` at `''a * ''a -> bool` requires its instance to admit
  equality (rule 2, with the instance relation of 4.5).

### The module language

A signature `Σ = (T)E` binds the names `T`. Matching a structure `E'`
against `Σ` (5.6) asks for a realisation `φ` of `T` such that `φ(E)` is
enriched (5.5) by `E'`: the same type functions, with schemes that `E'` makes
more general, and the constructors and exception status agreed. The open
choices are:
- **the realisation φ.** It is determined, given `E'`, by looking up each
  of `T`'s paths in `E'`: Rune's `SigMatch.match` does that, linearly
  (`sigmatch.sml:360-389`);
- **the names the module language binds or creates:** a signature
  expression's bound names (rule 65's `T`) and the representatives of
  sharing classes (rule 78), the fresh names of an opaque ascription
  (rule 53's `T'`) and of a functor application (rule 54's `T'`), and the
  names a functor binding abstracts over (rule 86). A checker is
  handed the names chosen, and verifies they are fresh and used
  consistently.

Enrichment of schemes is a one-way match of the structure's scheme against
the signature's: no unification. With `φ` recomputed and the fresh names
handed over, the module language is checkable deterministically too
(*Decisions*, D5).

### The derived forms

Rune's syntax keeps the Core's derived forms (Appendix A) as nodes of
their own: `if`, `andalso`, `orelse`, `case`, `while`, tuples, `#lab`,
lists, sequences, a `fun`'s clauses, `withtype`, and tuple and list
patterns. A checker
following the Definition checks each as its equivalent form would be
checked. For example, `if e1 then e2 else e3` is
`case e1 of true => e2 | false => e3`, so `e1 : bool` and `e2`, `e3` of
one type. The checker must also use the equivalent form for
non-expansiveness. The parser's own rewrites -- infixes, `val … and rec`
-- happen before anything is checked, and a checker of the syntax trusts
them.

### What this means for AstLint

- **The witnesses the syntax must hold:**
  - an instance at each use (held for expressions, not for patterns);
  - a type at each `raise` (not held);
  - a type at each variable pattern, wildcard and wildcard row (not held);
  - a type at each special constant (held as an overload variable);
  - the names each declaration created (stamps, held in tables);
  - for the module language, the names rules 53, 54, 65, 78 and 86 bind
    or create (not held).

  Types on every other node are a convenience: for the LSP, and for
  telling *which* node the elaborator got wrong. They are not a necessity.
- **What AstLint recomputes on its own:**
  - `tyvars C`, with Clos;
  - non-expansiveness;
  - the scope of explicit type variables;
  - equality;
  - φ.
- **What it can check only against a record:**
  - the defaults chosen;
  - when a flexible record was settled.
- **What it trusts:** the parser's rewrites.

This is the brief's "checker, not inferencer" made exact (C1, D4).

## What the literature says

E11 read the papers below. Every DOI was checked against Crossref on
2026-10-25; quotations come from the authors' texts. The notes, with every
quotation, are in the drafts (`results/E11/`).

### Typed intermediate languages pay for themselves

- **TIL** (Tarditi et al., PLDI 1996) typed every intermediate language of
  an SML compiler. "[T]ype-checking the output of each optimization or
  transformation helps us identify and eliminate bugs in the compiler."
  It also took about eight times as long to compile as SML/NJ.
- **FLINT** (Shao, League and Monnier, ICFP 1998) hash-consed its types.
  With that, "complete type-checking of the intermediate code after every
  phase does not incur noticeable overhead". Typed compilers without such
  sharing had "reported extremely slow compilation times". Rune's IR types
  are hash-consed since performance M4, for the same reason (type-checker.md).
- **GHC.** Peyton Jones, in his report from the trenches (ESOP 1996, §8),
  calls Core Lint after every pass "an outstandingly good way to detect
  incorrect transformations", and adds: "One of the dumbest things we did
  was to delay writing Core Lint."
- **Down to the machine.** Typed assembly language (Morrisett, Walker,
  Crary and Glew, TOPLAS 1999) and typed closure conversion (Minamide,
  Morrisett and Harper, POPL 1996) carry source types to assembly. The
  price is existential types for closures, and more. The roadmap's
  bytecode is typed by representations, not by ML types (D8), as GHC's
  STG, MLton's RSSA and Machine, Cranelift and WebAssembly are.

### Checking needs evidence, and is then simple

- **System FC** (Sulzmann, Chakravarty, Peyton Jones and Donnelly, TLDI
  2007): "every term encodes its own typing derivation … type checking is
  simple, syntax-directed, and decidable"; drop the evidence and type
  checking "would render … undecidable". This is the argument of *What the
  Definition says*: AstLint checks because the elaborator hands it the
  witnesses it chose.
- **The JVM moved from inference to checking.**
  - The old verifier inferred a type for every local and stack slot at
    every instruction, by a fixpoint.
  - JSR 202 (final 2006) added StackMapTable frames at the starts of basic
    blocks, so that verification is one linear pass (JVMS §4.10.1).
  - Leroy's survey (JAR 2003, §7) finds checking better in simplicity and
    memory, more than in speed.
  - Rose's certificates (JAR 2003) cost about half the code's size.
- **One type per register** is the closest precedent for Rune's register
  code. Leroy, for Java smart cards (SPE 2002, §3.1), requires two things:
  - each register has one type throughout a method (R2);
  - the stack is empty at branches (R1).

  Then one stack type and one register array suffice for the whole method.
  Code meets R2 after registers are allocated again per type. The cost in
  code size was -0.1% in all and +2.3% at worst (Table 1).

  Leroy still infers each register's single type, at 1.6 visits per
  instruction. Rune's register code *declares* it (`meta`'s reps), so
  one forward pass checks it. This last step is an inference from §3.2,
  not something the paper measures.
- **The CLI** (ECMA-335, III.1.7.5, III.3.43) declares locals in the
  method's header and infers only the evaluation stack, in one forward
  pass. That needs a known stack state after an unconditional branch.
- **WebAssembly** (Haas et al., PLDI 2017) validates in one pass over a
  stack of values and a stack of control frames. Structured control and a
  bottom type for unreachable code make that possible. It runs at 75-150
  MiB/s.

### Trust the checker, not the producer, and keep the checker small

- **The model:**
  - proof-carrying code (Necula, POPL 1997);
  - translation validation (Pnueli, Siegel and Singerman, TACAS 1998;
    Necula, PLDI 2000);
  - CompCert's verified validators (Tristan and Leroy, POPL 2008; Rideau
    and Leroy, CC 2010);
  - verified bytecode verifiers (Klein and Nipkow, TCS 2003).

  All four trust a small checker of the result rather than the large
  producer. Translation validation also checks meaning, which no lint
  here does.
- **An unsound verifier is a hole.** Any verifier bug "can potentially
  enable a security attack" (Leroy 2003, §1).
  - Lua 5.2 removed 5.1's bytecode verifier after exploits were shown
    against it. The 5.4 manual (§6.1) says that "Lua does not check the
    consistency of the code inside binary chunks".
  - For this roadmap, see X1.

### What a type checker cannot find

- **Meaning.** A lint of shape and types passes well-typed wrong code
  (*Where we are*). The practice is comparison, which Rune has begun
  (`check-levels`, `check-cross`, S42, the functor generator):
  - random programs run on several compilers (Csmith: Yang, Chen, Eide and
    Regehr, PLDI 2011);
  - variants of a program that must agree (EMI: Le, Afshari and Su, PLDI
    2014; live code mutation: Sun, Le and Su, OOPSLA 2016);
  - Chen et al.'s survey (CSUR 2020).
- **Wrong rejection.** A checker of the elaborator's derivations finds
  programs accepted that should not be. It cannot find programs rejected
  that should be accepted: that needs a corpus.
  - Rossberg (*Defects in the Revised Definition*, 2013, §5.7) gives a
    functor program that the Definition accepts and "almost all existing
    implementations reject".
- **The checks themselves** are tested by breaking the IR on purpose and
  expecting the error: mutation testing (DeMillo, Lipton and Sayward,
  Computer 1978), and E3 here.

### The Definition has defects of its own

Kahrs (LFCS report, 1993) and Rossberg (2013) list the places where the
Definition is wrong, ambiguous or not algorithmic. A checker "following
the sml 97 defintion" must say how it reads each one, as HaMLet does in its
comments and runespec does in its readings. The places that matter to
AstLint (Rossberg's numbering):
- the instance at each identifier (rule 2);
- closure and non-expansiveness (4.8);
- type names new only relative to a context (4.9, `Abs`);
- equality maximised (4.9);
- flexible records with an unbounded "program context" (4.11);
- overloading, "the most hand-waving part" (Appendix E, §12);
- restrictions called syntactic that depend on an identifier's status
  (2.9);
- types left undetermined at the top level (§13, G.8);
- realisations in signature matching (chapter 5).

### Types for editors

Merlin, OCaml's language server (Bour, Refis and Scherer, ICFP 2018), keeps
ill-typed nodes in the typed tree: "It is better to keep ill-typed nodes in
the typed AST, even if the types are unsound". It depends on the typer's
snapshots to undo unification, because OCaml's typed tree holds the
inferencer's mutable types (§3.3, §3.8). This is the argument for an
immutable type language on the syntax (D2), and for recording what a
failed declaration did type (D6).

## What the implementations do

E11 read the checks of eighteen systems, all but Lua's in their sources
under `/home/ruud/reference` (paths below are relative to it; HaMLet's are
under `/home/ruud/rune-corpus-sml97/_work/research/hamlet-2.0.1`). Nothing
was built or run. Not on disk: Lua 5.x's C sources, CoreCLR, and Android's
verifier.

| System | Checks | Checking or inference | By default | Where |
|---|---|---|---|---|
| GHC Core Lint (`ghc/compiler/GHC/Core/Lint.hs`) | types, kinds, scope, coercions, join points | checking: Core is typed | off (`-dcore-lint`); **on for every compile of GHC's test suite** (`testsuite/mk/test.mk:40`) | after every Core pass; unfoldings read from interfaces |
| GHC STG Lint (`GHC/Stg/Lint.hs`) | scope, invariants after unarise, runtime representations agreeing | checking, of representations only | off; on in the test suite | after the STG passes |
| GHC Cmm Lint (`GHC/Cmm/Lint.hs`) | branch targets, blocks, types | checking | off; on in the test suite | before output |
| HotSpot (`java/jdk/src/hotspot/share/classfile/verifier.cpp`) | the types of locals and stack at each instruction, initialisation, handlers, targets | checking against StackMapTable; the old inferring verifier for class files before version 50 | on for classes not of the boot path; `-Xverify:none` no longer accepted | linking |
| MLton (`mlton/mlton/{xml,ssa,backend}/*type-check*`) | full types (XML), scopes, handlers, representations | checking | **on at the end of each translation and each simplify pipeline** (`main/compile.fun:385-574`); off after each pass (`-type-check true`); off for Machine, "too slow to run by default" (`:586,596`) | the ILs' boundaries |
| MLKit (`mlkit/src/Compiler/Lambda/LambdaStatSem.sml`) | Lambda's types; every binder bound once | checking | **on**; "very fast … you should not disable" (`src/Common/Flags.sml:801-806`) | once, before region inference; its environment is pickled in the basis |
| SML/NJ (`smlnj/compiler/FLINT/{plambda/chkplexp,flint/chkflint}.sml`) | PLambda's and FLINT's types | checking | **off**, with kind checks stubbed out (`chkplexp.sml:148-150`); comments say it "fails on MLRISC/*/*RegAlloc.sml" (`FLINT/main/control.sml:126`) | after translation; after each phase on request |
| OCaml (`ocaml5/parsing/ast_invariants.ml`, `middle_end/flambda/flambda_invariants.ml`, `asmcomp/cmm_invariants.ml`) | the shape of the syntax; flambda's binding and closures; Cmm's continuations | untyped | Ast_invariants **always**, on ppx output and binary syntax; flambda's and Cmm's by configure option, flambda's on in CI, Cmm's in some CI runs | after each flambda pass; per Cmm function |
| Erlang (`erlang/otp/lib/compiler/src/beam_validator.erl`) | registers' initialisation and types, frames, heap, `try` state | inference (abstract interpretation) | **always, with no option to turn it off**; `beam_ssa_lint` and `core_lint` behind options, which the compiler's own tests set | after code generation ("strong"), and again just before the file is written ("weak") |
| Cranelift (`wasmtime/cranelift/codegen/src/verifier/mod.rs`) | integrity, SSA dominance, the CFG, a recomputed dominator tree, branch arguments equal to block parameters | checking | **on** in Cranelift ("makes compilation slower"); wasmtime turns it off; its fuzzer asserts it on | stage boundaries |
| WebAssembly in wasmtime | every function's types | checking, one pass | always: the input is untrusted | compilation |
| rustc (`rust-lang/rust/compiler/rustc_mir_transform/src/validate.rs`) | the CFG, and types separately (`CfgChecker`, `TypeChecker`) | checking | per pass behind `-Zvalidate-mir`; **always once**, where MIR becomes optimised runtime MIR (`pass_manager.rs:354-361`); MIR tests pass the flag | phase changes |
| Swift (`swiftlang/swift/lib/SIL/Verifier/SILVerifier.cpp`) | types, ownership, CFG | checking | builds with assertions only, or `-sil-verify-all`; an escape `-sil-verify-none` | stage boundaries |
| Go (`golang/go/src/cmd/compile/internal/ssa/check.go`) | structure, arguments, dominance | checking | off (`-d=ssa/check/on`, which also randomises the order of values); on for its error-check tests | after each phase |
| Julia, Dart | SSA and CFG; graph and uses | checking | builds with assertions or debug only | after optimisation; after each pass |
| Koka (`koka/src/Core/Check.hs`) | Core's types | checking | off (`--checkcore`); calls after two passes commented out | after some passes |
| Manticore (`manticore/src/tools/mc/{cps,cfg,bom}/check-*.sml`) | scope, types | checking | CPS and CFG **after every pass, always**; BOM on request | after passes |
| Lua | (5.1 had a bytecode verifier) | inference | removed in 5.2 | -- |
| F# with ILVerify (`dotnet/src/fsharp/tests/ILVerify`) | the CIL of the compiler's own DLLs | an external checker | a CI job, against baselines of accepted errors | after the build |

### Where they put the checks

- **After every pass, on request:** GHC, MLton, rustc, Swift, Go, OCaml's
  flambda, Dart; Manticore always.
- **At the boundaries of the intermediate languages, by default:**
  - MLton: the end of each translation and each pipeline of the
    simplifier;
  - rustc: once, at the change of phase to optimised MIR;
  - Erlang: after code generation and just before writing;
  - MLKit: once, before region inference.
- **The rules change with the phase**, and the good checkers say so:
  - GHC's per-pass flags: global ids are not checked after Tidy;
    linearity only on the desugarer's output;
  - Erlang's strong and weak validators;
  - rustc's `MirPhase`;
  - SML/NJ weakens string and exception types after phase 20
    (`chkplexp.sml:111-125`).

  Rune's lints have one rule set per representation. The places E9 lints
  that are new will need phase-dependent rules too, for example after
  `results`, or inside `simplify`'s rounds.
- **At trust boundaries, always:**
  - OCaml checks a ppx's output;
  - Erlang lints Core it is handed;
  - HotSpot verifies classes not from the boot path;
  - wasmtime validates every module.
- **At loads from a cache:**
  - GHC lints unfoldings read from interfaces under `-dcore-lint`, since
    "it is very painful to catch errors otherwise" (`Core/Lint.hs:506-514`);
  - HotSpot records verification constraints when it writes its shared
    archive, and checks only those when it maps it
    (`classfile/systemDictionaryShared.hpp:250-265`);
  - wasmtime trusts its own serialised code, "only lightly validated",
    which is why `deserialize` is `unsafe` (`crates/wasmtime/src/runtime/module.rs:385-404`).
- **After linking**, little precedent exists: WebAssembly matches the
  types of imports when it instantiates a module. The common pattern is to
  check each unit alone, and at the link only that interfaces agree. That
  is D15.

### What they cost, and what is left on

- **The costs measured or written down:**
  - MLton: 0.6% to 1.1% of a self-compile per check of an intermediate
    language (RSSA 2.6 s, SSA 1.82 s and SSA2 1.34 s of 227.36 s; commit
    `3cf638243`, 2023);
  - MLKit: "very fast";
  - FLINT: "no noticeable overhead";
  - WebAssembly: 75-150 MiB/s;
  - MLton's Machine: "too slow".

  Of the rest: GHC times its lints but publishes no figure, and turns them
  off in its compiler performance tests.
- **The common policies:**
  - one cheap check always on at a boundary, and per-pass checks behind a
    flag (MLton, rustc, Erlang);
  - checks only in builds with assertions (Swift, Julia, Dart);
  - a flag, always on in the test suite (GHC, Go, OCaml's CI, Erlang);
  - on in the library and off in the product (Cranelift against
    wasmtime).
- **Escape hatches:**
  - Swift's `-sil-verify-none`, an attribute per function, and a message
    that tells the user how to turn the check off;
  - GHC's `no_lint` per test.

### What they learned

- **A check that is off rots.**
  - GHC's STG Lint checked types; that "never worked", was disabled in
    2000, and is gone (`Stg/Lint.hs:17-31`).
  - SML/NJ's FLINT check is off and fails on parts of SML/NJ itself,
    although in 1998 it cost "no noticeable overhead".
  - Koka and Julia have calls commented out.

  The checks that live are on in the test suite or by default, as Rune's
  are since 2026-10-25.
- **False alarms come from invariants that the passes do not keep, and
  from inference that loses precision.**
  - GHC's manual: "there are valid programs that fail Linear Core Lint".
  - Erlang's validator called correct code unsafe twice in its release
    notes, and needed a weak mode after blocks were merged.

  Declared types, not inferred ones, and rules per phase are the answers.
- **Validators constrain optimisers.** Erlang's jump optimiser will not
  share blocks across a `try`, partly because the validator could not
  follow. With declared types the constraint is explicit: a pass that moves
  code must keep the declarations right.
- **Eager error messages cost.** Moving one rule's message off the common
  path cut allocation by about 4% for one program (`Core/Lint.hs:277-311`).
- **Test the checker.**
  - Cranelift's verifier tests expect a given error at a given instruction
    (`cranelift/docs/testing.md:134-160`).
  - F# runs ILVerify against baselines of accepted errors, so that a check
    can be adopted before it is clean.

### Types kept for editors and checkers

- **A slot on each node.**
  - Poly/ML keeps `expType : types ref` in its parse tree's nodes
    (`polyml/mlsource/MLCompiler/ParseTree/BASE_PARSE_TREE.sml:58-85`) and
    exports types lazily to its IDE (`mlsource/MLCompiler/ExportTree.sml:26-39`).
  - HaMLet 2.0 gives each syntax class a property: the type of an
    expression, the environment and type of a pattern, the environment of
    a declaration (`syntax/Syntax.sml:42-56`). Its elaborator "stores [the]
    result of each rule as annotation in [the] respective AST node". Its
    derived forms "make sure to clone nodes where necessary"
    (`CHANGES.txt:34-35`).

    HaMLet is the closest precedent for AstLint: the Definition's own
    objects on the Definition's own syntax, with a comment
    `(* [Rule n] *)` at each of 51 places in `elab/ElabCore.sml`.
- **A separate typed tree.**
  - OCaml's Typedtree gives every expression a type and an environment
    (`ocaml5/typing/typedtree.mli:162-170`). It is saved as `.cmt`, partial
    trees included, when typing fails (`file_formats/cmt_format.mli:36-50`).
  - Roslyn binds a typed tree per member, with a side table from syntax to
    bound nodes (`dotnet/src/roslyn/.../MemberSemanticModel.cs:31-34`).
- **Side tables by node id.**
  - rustc's `TypeckResults` keeps `node_types` and the like in maps keyed
    by ids local to an owner. A missing entry is a compiler bug. The tables
    serialise (`rustc_middle/src/ty/typeck_results.rs:30-60`, `343-347`).
    Its "writeback" builds them afresh without inference variables
    (`rustc_hir_typeck/src/writeback.rs:1-10`).
  - rust-analyzer keeps `ArenaMap<ExprId, Ty>` and a source map back to
    syntax (`crates/hir-ty/src/infer.rs:702-730`). "Inference variables must
    not appear in the final inference result".
  - GHC's `.hie` files keep, for each node, indices into one array of types
    shared by all nodes (`GHC/Iface/Ext/Types.hs:81-86, 125-175`). They
    leave out the types of applications, which are not cheap to work out
    per node (GHC issue #16233), so hover over an application gives none.
    That is the cost of recomputing on demand rather than keeping.
  - Roslyn's verifier, in debug builds, checks that the expressions
    analysed are exactly those visited (`NullableWalker.DebugVerifier.cs:17-63`).
    That is the coverage check a side table makes easy.

No system or paper argues for a separate typed tree as the *input* of a
checker:
its agreement with the syntax would itself need checking. Side tables keep
the syntax immutable, let the elaborator's types and AstLint's be compared
node by node, make coverage a count, and serialise for the editor. Slots
are cheaper to read but mutable, and need cloning wherever a node is
shared. *Decisions*, D1.

## The experiments

Fourteen experiments came before the writing, by five agents and the lead,
each in a snapshot of its own built from `d551f19dd`.

**How they were measured**
- Every number comes from a script kept with its raw output in the drafts
  (`~/.cache/claude-rune-drafts/linting/results/E*`), and is named beside
  the script.
- Claims rest on instruction counts (`runevm --count`, or the runtime's
  own counter read in the process), which do not vary with load. Times and
  peak memory are best-of-3 indications.
- The machine's load was 12 to 33 throughout, since other sessions were
  working too.
- Where milliseconds are given for instructions, the rate is 2.56 ns per
  instruction, pooled over HaMLet and the bootstrap; E2's HaMLet and
  bootstrap columns use each program's own rate (2.48 and 2.63 ns).

**The prototypes** were throwaway, kept as patches in the drafts
(`patches/`). None of them lands.

**The programs** used throughout:

| Name | What |
|---|---|
| hello | `examples/hello.sml` |
| listpair | a small program of `tests/lang` (`-O1` unless said) |
| HaMLet | `examples/benchmarks/hamlet` with `shared/input.sml`, 23k lines; E1 and E2 add `shared/main.sml`, E5 and E6 do not |
| the bootstrap | the compiler compiling its own sources (`BOOT_SRCS`), frozen at `d551f19dd` |
| MLton | MLton's compiler, its 606 files |
| the REPL line | the average of a transcript's lines, after the first |
| warm, one unit | the bootstrap's sources in units on a warm cache, with `main.sml` or `shake.sml` changed |

The bootstrap at `-O1` is 1.556G instructions without lint; MLton whole
at `-O1` is 23.65G.

### E1. What each lint costs

**Question.** What does `--lint` cost, per program, per level and per
check?

**How.** A throwaway patch routes every check through one entry point,
`Pass.lintAt`, timed at every depth: instructions, processor time and
bytes allocated (`results/E1/build.sh`, `runone.sh`, `table.py`). The keys
are today's checks: `translate`, `mid`, `midcanon`, `expand`, `shake`,
`lift`, `workers`, `simplify`, `refs`, the second `shake` and `lower`.
Environment variables select any set of them, which E2 uses. The keys'
instructions add up to the difference with and without lint within 0.5%,
so a set of checks is costed by summing its keys.

**Result.** Today's `--lint` adds 16% to 148% of a compile's
instructions (`results/E1/table.txt`):

| Program | Instructions, without lint → with | Added | Seconds; peak memory |
|---|---|---:|---|
| hello -O1 | 2.44M → 3.23M | +32% | 0.13 → 0.15 (the VM's start dominates) |
| listpair -O0 | 35.4M → 56.9M | +60% | |
| listpair -O1 | 26.4M → 53.9M | +104% | |
| HaMLet -O0 | 1,063M → 1,624M | +53% | |
| HaMLet -O1 | 1,243M → 2,274M | +83% | 4.05 → 6.61 |
| the bootstrap -O0 | 992M → 1,614M | +63% | |
| the bootstrap -O1 | 1,556M → 3,854M | +148% | 7.88 → 13.92 |
| HaMLet `--units` -O1 | 2,333M → 3,347M | +43% | |
| HaMLet `--units --whole` -O1 | 3,201M → 5,180M | +62% | |
| the bootstrap `--units` -O1 | 1,738M → 2,998M | +72% | |
| the bootstrap `--units --whole` -O1 | 2,975M → 6,392M | +115% | |
| MLton whole -O1 | 23,651M → 32,974M | +39.5% | 171 → 223; 5.82 → 5.89 GB |
| MLton `--units --whole` -O1 | 84,162M → 97,868M | +16.3% | 322 → 333; 3.97 → 4.08 GB |

Lint adds 0-24 MB of peak memory to the small programs, HaMLet and the
bootstrap. A REPL line averages 0.072M instructions of checks, about
0.18 ms, which is 43% of that line's own passes. A warm build that changes
`main.sml` spends 38.6M instructions on checks (99 ms, 4.7% of the build);
one that changes `shake.sml`, 6.1M (16 ms, 0.8%).

**Per check** (`table.txt`, section E1.2):
- **LowLint is the largest single check:**
  - 234M on HaMLet (18.8% of the compile, 4.5 times Lower itself);
  - 312M on the bootstrap (20%);
  - 1,644M on MLton (6.9%).

  The top-level function is 86% of it on HaMLet and 59% on the bootstrap.
  HaMLet's top-level function has 123 blocks and 12,092 of the program's
  41,883 variables. LowLint keeps a map of the variables available in each
  block and filters it at every join (`lowlint.sml:87-107`), so its cost
  grows with blocks times variables.
- **MidLint after each Mid pass costs 2.4 to 7.4 times the pass**, and
  0.7 to 1.0 times `simplify`. After `refs`, which changes little, it costs
  16 to 47 times the pass. `midcanon`'s lint is 3.5 to 3.9 times `midcanon`.
- **LambdaLint** costs 0.4 to 1.4 times `translate`.
- **`--mid-roundtrip`**, which the bootstrap's build and `check-levels`
  pass, costs 944M on HaMLet (76% of the compile) and 1,678M on the
  bootstrap (108%), after `mid` alone.
- **`--pass-stats` does not show most of the lint under `--units`**
  (*Where we are*): its `checks` line leaves out 34-72% of the compile.

**`make check`.**
- **How:** a stratified sample of the check tier, 582 tests with what they
  need, run with `RUNE_LINT=1` and with it empty, at `-j 4`
  (`results/E1/makecheck/`).
- **The sample:** 485.0 s against 414.2 s of processor time (+17%).
- **Weighted by the size of each group,** for 11,501 of the 20,003 tests:
  +874 s, or +10.8% of their time.
- **Left out:** the host compilers' groups, whose hosts were not built in
  the snapshot. Runs of programs compiled by another test lint nothing of
  their own.
- **Overall:** about 6-8% of `make check`'s 15,979 processor-seconds.

**For the roadmap.**
- Two costs dominate, and neither is a type check:
  - LowLint's map per block in the top-level function;
  - MidLint's persistent tables (E2).
- `--pass-stats` must report checks per pass at every depth (M1).

### E2. Cheaper levels

**Question.** Which sets of checks are cheap enough for which workload,
and which ways of making a check cheaper work?

**How.** E1's instrument, with sets of keys chosen by environment
variables, and variants of the lints built beside today's
(`results/E2/e2b.sh`, `e2c.sh`, `warm.sh`, `table.py`). The new keys:
- `prelower`, MidLint once, before Lower;
- `lower-top`, LowLint of the top-level function alone.

The variants:
- `MidLint.checkStructure`, without types;
- `checkMemo`, which skips a definition seen unchanged by the previous
  check;
- `checkLazy`, which makes messages only on a breach;
- `checkFast`, with imperative tables;
- `MidCanon.checkRenaming`, which checks that `midcanon`'s output is its
  input under a bijection of names, in place of linting it again.

**Result** (`results/E2/table.txt`). Per cent of the compile without
lint; milliseconds in parentheses:

| Set of checks | a REPL line | warm, `main.sml` | listpair | HaMLet -O1 | bootstrap -O1 | bootstrap -O0 | MLton |
|---|---|---|---|---|---|---|---|
| today's | 43.5% (0.18) | 4.7% (99) | 104% (70) | 82.9% (2,559) | 147.6% (6,042) | 62.6% | 39.5% |
| LowLint only | 11.7% | 0.7% | 3.7% | 18.8% | 20.0% | 13.3% | 6.9% |
| LambdaLint only | 3.5% | 0.4% | 11.9% | 5.8% | 8.3% | 12.2% | 1.9% |
| MidLint before Lower only | 4.9% | 0.6% | 1.7% | 4.6% | 13.1% | 18.2% | 2.6% |
| the boundaries: translate, mid, before Lower, Lower | 24.6% | 2.2% | 37.9% | 35.5% | 53.1% | 62.6% | 14.8% |
| the boundaries, Mid without types | 22.0% | 2.1% | 34.8% | 33.7% | 49.7% | 57.8% | 13.9% |
| today's places, Mid without types | 35.7% | 4.2% | 91.5% | 74.4% | 132.6% | 57.8% | 35.3% |
| today's, `midcanon`'s lint skipped | | | 83.6% | 76.8% | 136.4% | 44.4% | 36.2% |
| today's, `midcanon`'s lint replaced by the renaming check | | | 92.2% | 79.2% | 140.9% | 51.6% | 37.4% |
| today's, memo across passes | 40.1% | 4.7% | 101.8% | 83.2% | 148.7% | 63.1% | 39.8% |
| today's, lazy messages | | | 103.7% | 82.7% | 147.1% | 62.5% | |
| today's places, imperative MidLint | | | 53.9% | 47.1% | 73.2% | 40.0% | |
| projected: imperative MidLint, LowLint without its top-level cost | | | 50.7% | 31.1% | 62.2% | 37.4% | |
| projected: the boundaries, with both | | | 21.9% | 12.9% | 27.2% | 37.5% | |

What the variants show:
- **Types are cheap; tables are not.** `Ty` is hash-consed and compared by
  id, so MidLint without its types still costs 85% of MidLint. Lazy
  messages gain 0.3%.
- **A memo across passes gains nothing.** Every pass rebuilds every
  definition, so almost none is physically the one the last check saw. It
  hits only in the REPL's small units.
- **Imperative tables cut MidLint to 37-40%**, with the same rules and no
  false alarm:
  - the binders, the globals and the functions of several parameters go
    in hash tables;
  - the scope is one table, entered and left during the walk, which works
    because stamps are unique, and that is checked.

  HaMLet's Mid checks go from 725M to 280M instructions, the bootstrap's
  from 1,857M to 697M.
- **Checking `midcanon`'s renaming costs 36-40% of linting its output
  again** (29M against 76M on HaMLet, 70M against 174M on the bootstrap,
  275M against 770M on MLton). It guarantees the same, given MidLint after
  `mid`.
- **The two projected rows assume LowLint's cost over the top-level
  function goes to zero.** The linear LowLint they need was not built.
- **Detect cheaply, diagnose dearly.** The boundaries are checked on every
  compile, and on a breach the compile runs again with every check, to say
  which pass. That is sound only if checks never change the output, and
  E9 found that so, but for one flag. The rerun was not built, since no
  breach occurred.
- **Each cached unit linted once.** Today a warm build lints only what it
  compiles.
  - Linting every cached unit's Mid when it is loaded would cost about
    what the cold build's MidLint after `mid` costs: 141M over 235 units,
    17% of that warm build, plus decoding the Mid.
  - A mark that an entry was linted, set when it is stored, costs nothing
    on a hit.

**For the roadmap.**
- **No IR lint, as built, can be always on.** The cheapest single one,
  MidLint before Lower, costs 4.6% of HaMLet, 13.1% of the bootstrap and
  2.6% of MLton, against D13's 1%.
- **Two fixes come first**, before any level below today's:
  - imperative tables in MidLint;
  - a LowLint that is linear in a function's blocks and variables.

  They bring every set to 35-60% of its cost without losing a rule. Types
  without checking, memos and lazy messages do not help (D13, M2).
- **The boundaries are the level between none and all.** With the two
  fixes, they cost 13% of HaMLet and 27% of the bootstrap.

### E3. Which check catches which bug

**Question.** Of bugs seeded into the compiler, which does each check
catch, and how near the bug? Which does nothing catch, and which only an
oracle?

**How** (`results/E3/`; the harness `harness/e3.py`).
- **The mutants.** 68 mutants of the compiler, hand-written edits of exact
  text, all of which build. They are chosen by the classes of E4, and 9
  of them revert 8 real fixes:
  - `fd101794e`, Astra's check of escapes;
  - `dca8b2f17`, `Do` lists;
  - `46f5a29dd`, `refs`, as two mutants;
  - `7493e99ba`, `1049facdd`, `40f290078`, `expand`;
  - `28d93a928`, `54a0d1928`, Lower.

  Each mutant compiler is built by `bin/rune`.
- **The corpus**, 1,710 items:
  - `tests/lang` and `tests/perf` at -O0 and -O2;
  - 24 Basis tests;
  - `tests/lang` on the stack target;
  - 24 programs in `--units --no-cache` and in `--units --whole -O2`, so
    that `Link` runs;
  - `tests/errors`, for the elaborator's and Translate's mutants;
  - the bootstrap at -O0 and -O2. Where it differs, its compiler compiles
    the compiler again and must give `bin/rune.rbc`.
- **The steps, for each mutant:**
  1. Every item is compiled without lint and compared with the good
     compiler's output. A mutant that changes no byte anywhere is not
     exercised.
  2. Up to 160 of the items that differ are compiled with `--lint`.
  3. Up to 160 are run three ways: `--jit=off --checked`,
     `--jit=all --jit-tier=2 --checked`, and tier 2 without `--checked`.
     Each run is compared with the good compiler's, which ran twice and
     never varied.
  4. `check-levels`' rule (-O0 and -O2 run alike) is applied to the
     mutant's own output.
- **The baseline:** the good compiler's 1,506 compiles are lint-clean.
- **Round 1** is against today's checks. **Round 2** runs again with E6's
  AstLint, E7's `RegVerify` and E7b's shapes applied.

**Result, round 1** (`mutants.tsv`, `by-check.tsv`):
- **Exercised: 61 of 68.** Not exercised: E09, E11, E13, T09, T10, M19 and
  L10. The corpus has no dynamic module, and no functor of an earlier unit
  is inlined.
- **Today's lints catch 27 of the 61**, all at the pass that was mutated,
  except three:
  - an elaborator's mutant seen by LambdaLint, one stage on;
  - `midcanon`'s seen after `expand`, one stage on;
  - another elaborator's seen after `expand`, four stages on, in 1 of 3
    programs.
- **What the other checks saw:**

| Check | Mutants it saw |
|---|---:|
| the passes' own assertions (the compiler stops) | 10 |
| the VM's checks: loader, kind and range tests, `--checked` | 31 |
| a wrong output or exception | 28 |
| -O0 against -O2 | 36 |
| the bootstrap reproducing itself | 30 |

- **Caught by lint alone, while the program prints right:** six mutants
  (M01, M02, M08, M16, M18 and L07). These are type substitutions dropped
  in `inline`, `specialise`, `lift` and `expand`, and the fix of
  `28d93a928` reverted.
  - A seventh, T09, a `Do` list that drops a global, changes no byte of
    any program, and MidLint refuses 674 of its 798 compiles ("global g…
    is not defined"). It is the purest lint-only bug.
  - This is lint's own value: latent bugs, before a layout or the JIT makes
    them miscompiles.
- **Caught by nothing: nine.**
  - **Seven make the elaborator accept a program the Definition rejects**
    (E01, E02, E03, E05, E06, E10, E14).
    - Together they accept 15 programs of `tests/errors`. Every one is
      lint-clean, and runs.
    - With E01, a value restriction left off, an ill-typed program compiles
      clean and is stopped only at run time, by the VM's test of a
      primitive's argument ("primitive string_concat: wrong argument").
  - **M17**, the alias of a global that changes, reverted. It shows only
    under `Dynamic.reload`.
  - **R05**, a register given back one instruction early. It is probably
    equivalent on this corpus.
- **Well-typed mutants no lint sees, which oracles do:**
  - `andalso`;
  - constant folding (three);
  - effects dropped (two);
  - `refs`' first hunk (the program loops);
  - a layout lost in `midcanon` (tier 2 segfaults; the interpreter's kind
    test stops it);
  - tags swapped (`--checked`);
  - every mutant of `Regs`, `Stack`, `Emit` and `Link`, seen by the loader,
    the VM or the outputs.

**Result, round 2** (`mutants-r2a.tsv`, `r2b.tsv`, `r2c.tsv`):
- **AstLint catches all seven elaborator mutants that nothing caught.**
  - Of their 15 accepted programs it refuses 14, each by its rule: Clos,
    equality (three mutants), scope, rule 15, escape (3 of 4).
  - It catches E07 at the elaborator, where LambdaLint caught it one stage
    later.
  - It misses three:
    - a wrong default for overloading, by design (the tests fail on valid
      programs);
    - one the passes' assertion refuses anyway;
    - one of signature matching, since the module language is axioms.
  - It raised no alarm on the eight exercised Translate mutants.
- **`RegVerify`** (with `--lint`) catches what nothing but the VM saw:

| Mutant | What it breaks | Caught |
|---|---|---:|
| R02 | an arity | 160 of 160 |
| R06 | the reps in `meta` | 160 of 160 |
| R03 | registers of different reps shared | 154 of 160 |
| L09 | a tag test swapped | 129 of 160 |
| K02 | a linked program | 20 of 20 |
| K01 | a linked program | 5 of 24 |
| L08 | the order of captures | 31 more than LowLint's |
| R01 | a jump's target | 8 of 160 |
| R04 | the order of parallel moves | 3 of 160 |
| L04 | tags | 3 of 160 |

  It misses R05 and the mutants of `Emit`, which runs after it. Run without
  `--lint`, it also catches every mutant of Lower's reps (L01-L03,
  158-160 of 160), but neither mutant of a field (L05, L06).
- **Shapes** catch L04, tags swapped, in 108 of 160 items, which no other
  check really sees.
- **Cheaper sets** (`raw/r1a/lintsets.tsv`):
  - LambdaLint alone catches every Translate mutant;
  - LowLint alone catches only Lower's;
  - Mid's mutants need a Mid lint at or after the pass.

  The boundaries (after `translate`, the last Mid pass and Lower: E3's
  set; E2's adds `mid`) still
  catch 23 of the 24 mutants lint caught, but on fewer of their items and
  further from the bug. They miss the elaborator's mutant that only the
  lint after `expand` saw.

**What else it found** (`bugs/README.txt`):
- **`RegVerify` reports breaches in the good compiler's code** for four
  Basis tests (`option`, `int`, `intinf`, `intn_int64`): unit where `int`
  is wanted, and `con0` at a `DECON`. E7 had not run `tests/basis`.
  They are the prototype's false alarms, not the compiler's (E7, again).
  - The verifier derived each global's rep from its stores. It then
    refused reads on branches that cannot run:
    - a global whose only store is Lower's placeholder of unit, since the
      function meant to set it always raises;
    - globals only ever set to `NONE` (`IntInf.precision`), taken apart on
      a `SOME` branch the optimiser kept.
  - A rep derived from stores is a lower bound, and must be widened, or
    read from a table of declared reps (D9).
  - Fixed in the prototype, the 128 programs of `tests/basis` it ran are clean at
    -O1 and -O2, and the eleven negative tests still fail.
- **Shapes refuse the good compiler's Low** for `rt.call_results-sum` at
  -O2. A variable read from a global that `results` shares holds a string
  for one constructor and an int for another, and the rule takes the first
  binding's type. It is the prototype's false alarm, of the kind LowLint
  had before `28d93a928`. In the prototype, fixed: a variable Lower makes
  with `defAny` gets no type, and its shape stays unknown.
- **AstLint misses an escape through an outer variable**
  (`tests/errors/err.ty_local-outer-variable.sml`:
  `fun f x = let datatype t = C val _ = if true then x else C in 1 end`).
  The datatype escapes through the type of `x`, not through the `let`'s
  result. A rule for M12.
- **A check that moves a counter hides a bug.** E9's prototype round trip
  after `midcanon` (today's flag runs after `mid` only) takes fresh stamps
  (E9's defect), which moved the counter past
  a collision that mutant M21 makes. With it, the bug that today's lint
  catches after `expand` vanishes. A check must not touch the compiler's
  counters, or must restore them (M1).
- **One abort of `runevm`** while it ran a compiler, among some 25,000
  compiles: "malloc(): mismatching next->prev_size", glibc's check of the
  C heap, on a loaded machine. It did not come back in 46 more runs.

**For the roadmap.**
- **Each IR lint pays for its own class**, and catches it at the pass that
  broke it: types in Lambda and Mid, reps in Low. That class is a
  minority: 27 of 61 exercised mutants (44%), and 15 of 42 of the
  history's bugs that a check could see (36%, E4).
- **Lint at every pass is worth its cost** in the tests: the boundaries
  lose items and distance (D13).
- **AstLint is the only check of the elaborator** (M12). It needs the
  module language for what remains (M13), and the escape rule.
- **`RegVerify` is the only check of `Regs` and `Link`** (M8).
- **Shapes or `--checked` are the only checks of tags and fields** (M6).
- **Well-typed wrong code is found only by oracles:**
  - -O0 against -O2 (36 mutants);
  - the VM's checks (31);
  - the bootstrap reproducing itself (30);
  - outputs (28).

  `check-levels` on the register target (M1) and scenarios for reloads
  extend them.

### E4. The compiler's bugs, in history

**Question.** Where have the compiler's bugs lived, how were they found,
and which would a check have caught?

**How** (`results/E4/`), by reading:
- **the issue lists:** `build-cache-issues.md`, issues 1 to 24 and *Found
  on the way*;
- **the plans:** type-checker.md, middle-end.md, performance.md,
  units-fixes.md, and functors-units.md's M5 to M7, with the independent
  review's seven findings, the generator's three and the lint's four;
- **the review** in linting.md;
- **the commits:** the bodies of the compiler's 194 commits, with the
  diffs of the fixes.

`bugs.tsv` has 65 bugs, each classified by where it lived, how it was
found, whether a lint saw it then, whether today's would, and the earliest
check that could have caught it.

**Result.**

| Where the bug lived | Bugs |
|---|---:|
| Mid's `expand` (all in functors-units M5 to M7, four days) | 14 |
| the cache | 13 |
| the elaborator (6) and the parser (1) | 7 |
| the VM and the JIT, in C | 5 |
| Lower | 4 |
| Translate | 3 |
| units and the link | 4 |
| `Emit` and positions | 2 |
| `Ty` | 2 |
| `refs` | 2 |
| the Basis | 2 |
| host compilers | 2 |
| the lints themselves | 2 |
| `midcanon`, ToMid, a generator | 1 each |

| How it was found | Bugs |
|---|---:|
| review or reading | 15 |
| tests and scenarios | 14 |
| a lint | 13 |
| differential oracles (bytes, outputs, hosts) | 9 |
| experiments | 4 |
| an external tester (Astra) | 4 |
| a crash on a corpus | 3 |
| other: a build in units, builds on the hosts, reading with an experiment | 3 |

**Would today's `--lint` catch it:** yes for 15, no for 27, and not
applicable for 23 (outside the IRs: a crash, a resource bound, the C
runtime).
- **Every "yes" is a type or a rep** that a pass of Mid or Lower got
  wrong, and 9 of the 15 printed the right answer.
- **The "no" group:**
  - **The elaborator** accepted what the Definition rejects, or the
    reverse (seven bugs). AstLint of the Core would see two of them (a
    datatype escaping its `let`, and the value restriction); three need
    the module language.
  - **Well-typed miscompiles:** a program's `if n = 0` folded as a
    descriptor's test, and an alias of a global that a function sets
    again.
  - **Layouts that Mid's types do not carry** (two), which shapes across
    functions would see.
  - **Positions and traces** (four).
  - **The cache and units** (fourteen). Each unit was well typed; they
    were found by scenarios, `--verify-cache` and byte comparison.
  - **The lints' own gaps:** `MkExn`'s payload, and the rule for casts.

**For the roadmap.**
- **The IR lints have a perfect record on their class:** a pass that
  breaks Mid's types or Low's reps. That class is 15 of the 42 bugs a
  check could see.
- **The newest pass had the most bugs:** 14 in four days. Lint between
  every step of a new pass, or a pass made of interleaved rounds, finds a
  breach nearest its cause (D12).
- **The elaborator's seven** are AstLint's case.
- **The cache's fourteen** are no lint's. They are M9's interfaces and
  marks, and the scenarios', as before.
- **The worst bugs passed every lint:** a well-typed fold, and a layout.
  Comparison found them, and keeps finding their kind.

### E5. What types on every node cost

**Question.** What does keeping a type for every node of the syntax cost
in time and memory, in what type language, and when may the types be
read?

**How** (`results/E5/`, `patches/E5-sourcety.patch`):
- `Ast` was left alone.
- **A side table**, keyed by a node's span and constructor tag, is filled
  post-order by one line in `elabExp` and one in `elabPat` (21 lines of
  `elaborate.sml` in all, with the witnesses), and read post-order.
- **`SourceTy`**, an immutable, hash-consed type language for the source:
  - type variables with an id, equality, the source name of an explicit
    one, a generic flag and overloading classes;
  - type names by stamp, with equality at each occurrence;
  - records with their labels;
  - flexible records.
- **The zonk**, from `Types.ty`, runs after `Elaborate.finish`.
- **A census** of node kinds.

**Result.**

The census, of the corpus's own files:

| Corpus | Files | Nodes | exp | pat | ty | other |
|---|---:|---:|---:|---:|---:|---:|
| HaMLet | 2 | 67,569 | 33,452 | 18,782 | 5,913 | 9,422 |
| the bootstrap | 96 | 231,905 | 162,796 | 44,750 | 8,761 | 15,598 |
| the Basis | 278 | 80,138 | 42,765 | 11,649 | 11,819 | 13,905 |
| MLton | 606 | 584,989 | 347,095 | 122,023 | 49,269 | 66,602 |

`EVar` is the largest kind everywhere.

**Keys.**
- The table holds 89,258 entries for HaMLet, 264,749 for the bootstrap
  and 579,826 for MLton.
- There is **no collision** anywhere, nor on `--basis all` or the 353
  programs of `tests/lang`. Infix `EApp` and `ETuple`, and `PApp` and
  `PTuple`, do share spans, but their tags differ.
- So a key of span and tag works today. Nothing guarantees it, which
  matters to D1.

**Cost** (`--typecheck-only`, instructions; per cent against the
prototype with nothing on; `summary.tsv`):

| Configuration | HaMLet | the bootstrap | MLton |
|---|---:|---:|---:|
| the base | 202.6M | 397.3M | 15.19G |
| the prototype, nothing on | 203.6M | 400.4M | |
| every node's entry, not zonked | 215.1M (+5.6%) | 433.1M (+8.2%) | |
| and zonked after `finish` | 286.7M (+41%) | 607.0M (+52%) | 15.64G (+3.0%) |
| the witnesses only, zonked | 265.4M | 556.2M | 15.52G |

MLton's front end is mostly elaboration itself (62 s), so the shares are
small there.
- **The prototype's zonk is slow:** about 176 instructions per step, 1.1 s
  on the bootstrap and 1.7 s on MLton. It needs memoising per cell (done),
  cheap integer keys, a batch per declaration and a budget of steps before
  it could be on by default.
- **On the budget fixtures** the table and zonk add 0.4-1.7% to most, but
  9.8% to `compile-hello` and 25.6% to `compile-sigs` (37.1M to 46.6M,
  over its budget of 40.8M).

**Peak memory** (`--typecheck-only`):

| Configuration | HaMLet | the bootstrap | MLton |
|---|---:|---:|---:|
| off | 67.6 MB | 112.5 MB | 4.10 GB |
| the entries, no types | 84.9 MB | 163.3 MB | |
| and `Types.ty` kept until `finish` | 93.4 MB | 168.9 MB | |
| and zonked | 98.1 MB | 226.3 MB | 5.00 GB |
| the witnesses only, zonked | 96.2 MB | 179.5 MB | 5.02 GB |

Keeping every node's `Types.ty` until `finish` costs only 5.6 MB on the
bootstrap, since the types are mostly shared with the environment. The
rest is the prototype's log of about 200 bytes an entry and the zonk's
temporaries.

**`SourceTy` shares well:**

| Corpus | Distinct `SourceTy` nodes | Node types they stand for | Sharing | Estimated size |
|---|---:|---:|---:|---:|
| HaMLet | 10,670 | 89,000 | 8.4× | 2.2 MB |
| the bootstrap | 16,700 | 265,000 | 16× | 3.3 MB |
| MLton | 81,232 | 580,000 | 7× | 16.8 MB |

The exponential type of type-checker.md stays linear: 989 steps and 170
nodes at 20 applications, 1,745 steps and 278 nodes at 128.

**When types may be read** (`results/E5/changes/`):
- **In HaMLet and the bootstrap, no node's type changes** between its
  declaration's end and `finish`: 0 of 79,885 and of 243,985, under all
  five `--flex-records` modes.
- **With targeted programs** (`tests/flexrec`, and four of the
  experiment's own: `ref nil`, and a flexible record that a later
  declaration settles), types change after a declaration at top level ends,
  in every mode that accepts such a program.
- **After a topdec's end** they change only under `--flex-records=program`.
- **So zonking:**
  - at a declaration's end is unsound;
  - at a topdec's end is sound but for `program` mode;
  - after `finish` is always sound.

**The witnesses alone** (the question of *What the Definition says*,
`witnesses.py`):
- **Today's slots already hold most of them:** `varinfo`'s instances, the
  constants, `ESelect`'s record, `[]`, a flexible record pattern, and
  `Ty.binders`' schemes.
- **What would be new:**

| New witnesses | HaMLet | the bootstrap | MLton |
|---|---:|---:|---:|
| at nodes, in all | 6,523 (8.4% of nodes) | 14,154 (5.9%) | 32,725 (6.4%) |
| of which constructor patterns | 2,914 | 6,751 | 14,735 |
| wildcards | 2,611 | 4,828 | 10,253 |
| a constructor in a variable pattern's place | 645 | 1,680 | 6,942 |
| `raise` | 216 | 459 | 334 |
| the pattern `[]` | 137 | 436 | 461 |
| fresh datatype names | 153 | 168 | 966 |
| `val`s scoping explicit type variables | 35 of 4,438 | 78 of 10,126 | 315 of 30,004 |

Counted with what the slots already hold, the witnesses are 65-72% of the
nodes, because `EVar` is so common.

**D1's options, priced with these numbers:**
- **D1 A, a node id on every node, and tables by ranges of ids:** about 8
  bytes a node, 0.6, 1.9 and 4.1 MB for HaMLet, the bootstrap and MLton,
  plus `SourceTy`'s pool. The ids also serve the LSP and errors as
  anchors. It touches about 350 matches in 19 files.
- **D1 D, a separate typed tree:** about the size of the syntax again (585k
  nodes for MLton), and again for the editor's copies.
- **D1 C, slots on every node:** two words a node, mutable, junk after a
  declaration that failed, and reset by `SyntaxAst.copy`.
- **D1 B, a key of span and tag:** no change to `Ast` and no collision
  measured, but nothing guarantees it.
- **Witnesses only,** with every other node's type worked out on demand
  (E6, E12): D2 A and D7 A.

**For the roadmap** (D1, D2):
- `SourceTy` is cheap in memory, and zonked after `finish` it is right in
  every mode.
- Witnesses cost a few per cent of nodes more than today's slots hold.
- Every node's type costs little memory but much time, until the zonk is
  made fast.
- A real zonk needs memoising by cell, integer keys, a batch per
  declaration and a budget (M11).

### E6. An AstLint of the Core

**Question.** Can a checker of the elaborated Core be built that shares no
code with the elaborator's unification, matching or types; what does it
cost; and does it find anything?

**How** (`patches/E6-astlint.patch`, `results/E6/`).
- **Size and data:**
  - `astlint.sml` is 1,159 lines, about 1,050 of them code, on top of
    E5's `SourceTy` and tables (740 lines).
  - It reads E5's tables, `varinfo` and `patinfo`, and the syntax.
  - It reads as data `Types`' built-in stamps, the environment's
    datatypes through its own lookups, and the table of overloading
    classes.
  - It builds its own environment, layered over the elaborator's at each
    top-level declaration.
- **How it types:** it works out every node's type bottom-up from the
  witnesses, with three tools:
  - equality of `SourceTy` skeletons;
  - one-way matching of a scheme against an instance, for variables and
    constructor patterns;
  - its own `Clos`, as a set difference against `tyvars(C)`.
- **Its switches:** `RUNE_ASTLINT=1` fails the compile on an alarm and
  `=warn` reports it. `RUNE_NODETYPES=witness` checks from the witnesses
  alone; by default every node is recorded and compared.
- **The module language is taken as axioms:**
  - the values of the incoming environment;
  - the results of ascriptions and of functor applications;
  - functor parameters;
  - dynamic modules.

**It never needs unification.** Without witnesses it would need inference
at:
- a variable's instance;
- a `raise`;
- a wildcard;
- a constructor pattern;
- `[]`;
- a flexible record, whose context in rule 38 is not local;
- an overloaded constant.

**What it checks:**
- every node against its recorded type (in the mode that records them
  all);
- instances, with an equality type variable's image admitting equality
  and an overloaded one's in its class;
- `Clos` against what the elaborator generalised at each binding;
- the value restriction as 4.7 states it, `conexp` and Appendix A's
  derived forms included;
- the scope of explicit type variables, worked out again from the syntax
  (4.6), and rule 15's side condition;
- the equality of datatypes, maximised;
- the classes of constants;
- names that escape a `let`;
- the identity and status in `varinfo` and `patinfo`, against its own
  environment;
- every slot that Translate reads, against the node's type;
- `Ty.binders`;
- each top-level declaration's result against the elaborator's, schemes
  and bound sets;
- closure (rules 87-89), at `finish`.

**Result.**
- **No alarm** anywhere, in either mode:
  - `tests/lang`, 353 of 353;
  - the Basis, 515 declarations;
  - HaMLet, 334;
  - the bootstrap, 313;
  - MLton, 1,152;
  - the nine programs of every `--flex-records` mode.

  `tests/errors` is still all rejected, with every expected message (204
  of 204). AstLint does not run there unless a mutant makes the
  elaborator accept.
- **Outputs unchanged:** every program of `tests/lang` compiles to the
  same bytes with AstLint on (`identity.sh`).
- **What it costs.** Taken as axioms on MLton: 109,333 values, 435
  ascriptions, 360 applications and 270 functor parameters. AstLint itself
  costs:
  - about 0.8 to 1.1 times the whole front end on HaMLet and the bootstrap
    (+161M and +431M instructions, from the witnesses);
  - 3.9-4.5 s against 62 s of elaboration on MLton.
- **What it catches.** Five mutants of the elaborator, each built by
  `bin/rune` (`sanity/`):

| Mutant | AstLint | `--lint` today |
|---|---|---|
| the value restriction off | caught (Clos, the declaration's result, closure) | silent: `r := [1]; r := ["s"]` compiles |
| the equality check off | caught | silent: the program prints `false` |
| a scheme in the place of an instance in `varinfo` | caught (a slot) | caught by LambdaLint |
| rule 15's side condition off | caught | silent |
| every variable generalised | caught (Clos, an instance) | ToMid fails with an internal error |

  Three of the five pass today's lints in silence, two of them to a wrong
  program. That is the case for AstLint in one table: what Lambda cannot
  see is a program the Definition rejects, and once accepted it is well
  typed below.

**A bug, confirmed: the value restriction misses `(conexp : ty) atexp`.**

```sml
val x = (SOME : 'a list -> 'a list option) nil
val p = (x : int list option, x : bool list option)
```

- **Rune** rejects it: "explicit type variable 'a cannot be generalised".
  - `nonexpansive` (`elaborate.sml:1170-1186`) takes a constructor
    application only as `EApp (EVar …)`, so the binding is not
    generalised, and `checkGeneralised` (`:444-453`) refuses the program.
  - 4.7 has `conexp ::= ( conexp <: ty> ) | <op> longvid` (runespec,
    `core.rs:254-257`).
  - The nested form `((SOME : t) : t) nil` and an annotated `op ::` fail
    the same way.
- **Other implementations:**
  - HaMLet 2.0.1, MLton (20241230, 20210117), Poly/ML (5.9.2, 5.7.1) and
    MLKit 4.7.25 accept and generalise it;
  - SML/NJ (110.79, 110.99.9, 2026.2) rejects it, as Rune does;
  - Moscow ML 2.10.1 accepts the declaration but does not generalise.
- **It is a valid program rejected, not an unsound one.** AstLint, which
  checks only what the elaborator accepted, cannot see it; runespec, which
  reads 4.7 right, can (D16).
- **The reproducer** is `results/E6/bugs/conexp-value-restriction.sml`,
  and its fix is M1's.

**The prototype's own false alarms**, all fixed, each a rule for M12:
- **`ESelect`'s entry** is the node's type, `r -> t`, not the record's.
- **"A type by stamp" is wrong in the module language.** One variable's
  stamp carries several schemes after an ascription: `SigMatch.mergeInfo`
  keeps the actual's stamp with the signature's scheme. That gave 1,352
  alarms on instances and 538 on results in `tests/lang`.
- **The equality of an axiom's type name** must be kept when it is
  converted (94 alarms).
- **In `fun f … and g …`, generalising `f` marks the type variables it
  shares with `g` generic.** So "what this binding generalised" is lost
  for `g` (37 alarms on HaMLet). Generalisation in place
  (`unify.sml:224-240`) means the record must be taken at the binding,
  before the group's first generalisation.
- **Equality per occurrence:** four disagreements in MLton, all
  AstLint's own. A `withtype` naming the datatype it accompanies saw the
  provisional `eq=true` (MLton's `ast/ast-atoms.fun:233`,
  `ast/ast-core.fun:70`). The table by stamp is the authority, not the
  occurrence.

**Corner cases, listed and not built:**
- **Trusted:** `_prim`'s annotation (its primitive's signature is not
  checked).
- **Axioms:** `_overload`, and the classes; `_dynamic`; a functor's
  `(spec)` parameter opened.
- **Partly checked:** wide and raw literals, by class only, not range.
- **Handled:**
  - or-patterns;
  - `--flex-records`, by zonking after `finish`. The policy is
    invisible, and the modes' rejections are not checked again;
  - local datatypes that name the enclosing type variables, allowed as
    Rune allows them.
- **Read as Rune reads them:**
  - abstype (the same stamps, equality false outside);
  - `array` and `ref` admitting equality;
  - the built-in exceptions, compared by index (they share one stamp).

**For the roadmap** (D3-D5, D16, M12):
- AstLint of the Core is about 1,100 lines and needs no unification.
- It costs about as much as elaboration again, so it belongs behind
  `--lint` and in every test compile, not always on.
- It catches what no lint below can, and the module language can wait
  behind axioms.
- Its records must be taken at the binding (generalisation), keep
  schemes, not stamps (modules), and take equality from the table by
  stamp.

### E7. A verifier of the register code

**Question.** Can the register code be checked in one forward pass
against the reps it declares, what does that cost, and what does it catch
that the loader does not?

**How** (`patches/E7-regverify.patch`, `results/E7/`).
- `backend/regverify.sml` is 929 lines, about 300 of them a census and the
  injection of faults. It runs:
  - after the `registers` stage, with `RUNE_REGVERIFY=1`, `report` or
    `census`;
  - on every program `Link.program` makes, in a build in units, in
    `rune -o P.rbc *.rbu`, and in `Session.writeProgram`.
- **A pre-pass** decodes each function once, fresh items and cached `Ops`
  alike, and scans `CLOSURE` and `CALLK`.
- **The first pass** records what reaches `RET`, `SETGLOBAL`, `CLOSURE`
  and `SETENV`. From that it derives:
  - each function's result rep, through `TAILCALLK` to a fixed point;
  - each captured slot's rep;
  - each global's rep.
- **The second pass checks.** Each register holds one packed integer: its
  rep, or *unset*, and one fact ("tag *t*", "a tag other than *t*", or "a
  closure of function *i*"). The array is copied only when written after a
  label's pending state shares it.

**The rules:**
- **A directed order of reps:** *x* ≤ *x*, *x* ≤ any, con0 ≤ con, ptr ≤
  con. A write of *m* into a register of rep *q* is:
  - right if *m* ≤ *q*;
  - a downcast, trusted and counted, if *q* < *m*;
  - otherwise a breach.

  A read that needs a rep is judged the same way.
- **Unset.** Nothing reads a register that is not set on every way in.
  The scratch is unset at every label.
- **Labels and loops.** A label's state is the meet of its forward
  edges, widened to the declared reps at loop heads and handlers. A jump
  back needs every register set at the head, which must be in
  `meta.loops`. The handlers' depth is the same on every way in, and none
  is set at `RET`, `TAILCALL` or `TAILCALLK`.
- **The order the JIT relies on:**
  - `RESULT` right after `CALL`, `CALLK` or `PRIMPUSH`;
  - `CATCH` at a handler's start;
  - `SWITCH` followed by its jumps;
  - no image primitive in `PRIM`, and only image primitives in
    `PRIMPUSH`. The seven of `Regs.imagePrims` are the seven of
    `Isa.effect` today.
- **Calls.**
  - `CALLK` and `TAILCALLK` pass exactly the callee's arity, each argument
    at the callee's register.
  - `CLOSURE` only of functions of arity 1, one count of captures per
    function, and `ENV` below it.
  - `ENV` and `SELF` only in functions a closure is made of and no `CALLK`
    calls.
  - Primitives' arguments and results as `Prims.repsOf` says.
- **Branches that cannot be taken.** A tag test that an earlier one
  already answered makes the other branch unreachable. Without this rule
  the optimiser's 18 to 25 redundant tests in the bootstrap gave the first
  false alarm.

**Result: no breach anywhere** (E3 later found the prototype's false
alarms on `tests/basis`, since fixed):
- `tests/lang` at -O0, -O1, -O2, `--units --no-cache` and with debug
  information;
- 510 benchmark programs at -O1 and -O2;
- the bootstrap at every level, and in units with no cache, a cold cache
  and a warm one, and linked from `.rbu` files;
- HaMLet in the same four ways;
- MLton whole: 578,193 instructions in 22,774 functions;
- MLton in units: 756,256 instructions in 32,165 functions, then the link;
- a program built through the compiler library.

The cached code, the frozen Basis in `lib/cache` included, was verified at
the link and is clean.

**What it catches that the loader does not** (`neg/run-neg.sh`). Eleven
kinds of corruption, injected into the code before it is verified and
written:
- the verifier catches all eleven;
- the loader catches one, a write of the wrong rep.

Of the ten the loader takes:
- **reading a pointer as an integer** (`int_add` on a `ptr` register) and
  **a `CALL` without its `RESULT`** give wrong results (an uncaught
  `Subscript` in IntInf);
- **a wrong `ENV`** stops the VM with a fatal error;
- **a `SWITCH` with its first jump dropped segfaults at tier 2**
  (`--jit=all --jit-tier=2`). It is a fatal "constructor field 2 out of
  range" in the interpreter and at tier 1. The reproducer is
  `results/E7/neg/keep/switch-dropped.rbc`;
- an unset read, `CALLK` with one argument too many, a misplaced `CATCH`,
  an extra `POPHANDLER`, `PRIMPUSH` made `PRIM`, and a `CLOSURE` of a
  function of arity 2 all run silently, with the right output here.

That is the reproducer for *Where we are*'s claim that the loader does not
make tier 2 safe.

**What it costs** (`cost.sh`; instructions with `RUNE_REGVERIFY=1` against
0):

| Workload | Instructions, off → on | Added |
|---|---|---:|
| a small program | 31.08M → 31.56M | +1.5% |
| HaMLet, whole | 1,247M → 1,289M | +3.3% |
| the bootstrap, whole | 1,589M → 1,738M | +9.4% |
| MLton, whole | 23.70G → 24.13G (145.5 s → 147.0 s) | +1.8% |
| HaMLet `--units`, no cache | 2,350M → 2,580M | +9.8% |
| the bootstrap `--units`, no cache | 1,772M → 2,106M | +18.8% |
| HaMLet `--units`, warm cache | 501M → 620M | +23.8% |
| the bootstrap `--units`, warm cache | 786M → 960M | +22.1% |
| HaMLet linked from `.rbu` files | 318M → 437M | +37.6% |
| the bootstrap linked from `.rbu` files | 416M → 590M | +41.8% |

- **In the machine's instructions** (`perf stat`): +5.9% on the
  bootstrap, +2.8% on HaMLet, +4.3% on the small program.
- **Per register instruction:** about 700 VM instructions, a quarter in
  the pre-pass and three-eighths in each pass.
- **A link costs more** because it verifies the whole linked program,
  every cached unit and the Basis with it, every time.

**The downcasts**, reads of *any* into a typed register:

| | `tests/lang` | benchmarks | the bootstrap | MLton |
|---|---:|---:|---:|---:|
| writes to typed registers | 170,437 | 1,863,257 | 118,289 | 285,095 |
| downcasts | 21,256 (12.5%) | 359,806 (19.3%) | 32,783 (27.7%) | 95,189 (33.4%) |
| — of them, heap reads (`SELECT`, `FIELD`, `DECON`, `EXNARG`) | 59% | 61% | 72% | 60% |
| — polymorphism (a callee returning any, `ref_get`, `array_sub`, a global set from any, any arguments) | 32% | 30% | 23% | 18% |
| — `RESULT` of `CALL` (no function types) | 8% | 8% | 3% | 17% |
| slot and sum globals of `results`, with disagreeing writes | 56 | 1,120 | 196 | 22 |
| con read as con0 or ptr | 0 | 39 | 0 | 344 |

What a unit alone cannot check (MLton in units, summed over units):
- 17,352 `CALLK` and 5,422 `TAILCALLK` of imported functions, for arity
  and arguments;
- 15,541 downcasts at the `RESULT` of an imported callee;
- 20 reads of another unit's globals.

Functions made into closures:
- 95% (`tests/lang`) to 99% (the bootstrap; MLton, 15,954 of 16,142) have
  a typed register 0, which `CALL` fills unchecked and tier 2 trusts;
- 73-90% have a typed result.

**`FIELD` and `DECON` against tag tests.** The facts are per register,
carried through `MOVE`, `JUMPIFNOTTAG`, `SWITCH` and constructors made in
the block. In the bootstrap:

| | Dominated by a test of its own tag | After a test of another tag | With no test |
|---|---:|---:|---:|
| `FIELD` | 6,091 | 4,929 (a two-constructor type such as `list`, safe only if the datatype is known) | 1,033 (942 on a `ptr` register, such as a datatype of one constructor) |
| `DECON` | 2,072 | 238 | 172 |

Without the datatype, "dominated" cannot be decided on registers; with a
shape `data(stamp)` it can (E7b).

**The verifier's own bugs**, lessons for M8:
- a fixed point along the chain of units' top levels that was quadratic
  (314M of 400M instructions on a linked HaMLet), until it ran in reverse;
- a pre-scan that read `CALLK`'s count as its function, which gave false
  alarms in builds in units only;
- tag facts kept as lists that grew with every constructor.

Generated tables and a suite of negative tests would have caught all
three.

**For the roadmap** (D8-D10, D13, D15, M7-M9):
- **The design works:** one forward pass over the declared reps, with the
  scratch tracked per block and `arrive` at loop heads.
- **It checks `Regs` and `Link`, not memory safety.** 12-33% of typed
  writes are trusted downcasts, and `Emit`'s bytes come after it.
- **Cost:** +1.5% to +9.4% of a fresh compile. As a check at every link it
  costs +22% to +42%, so each unit is verified once, when it is compiled,
  and the link checks only interfaces.
- **The derived facts cost a pass.** A result rep, the captures' count and
  reps per function, and a table of global reps in `meta` would make it
  one pass and halve the cost.

### E7b. Shapes, and what tier 2 trusts

**Question.** What would it take to make the code safe for what tier 2
trusts, and what does tier 2 lose by trusting less?

**How** (`patches/E7b-shapes.patch`, `results/E7b/`).
- **LowShapes** (238 lines) gives every Low variable a shape:
  - `tuple(n)`;
  - `data(stamp)`;
  - closure;
  - `opaque(kind)`;
  - immediate;
  - unknown.

  The shapes come from the Mid type Lower records for it (`Lower.lastTys`,
  about 30 lines).
- **The rules:**
  - a `Select` within the tuple's arity;
  - `Field` and `Decon` on data, with one count of fields per (stamp,
    tag) across all the program's `Con`s;
  - a `Call` on a closure;
  - definitions, jumps, known calls and captured values agreeing.
- **Carrying shapes into the code was measured two ways:**
  - registers shared by rep *and* shape;
  - a frame per block in `meta.blocks`.
- **Tier 2 trusting less** was measured in three variants, built with
  `-DRUNE_JIT_TRUST_LESS` and its parts.

**Result.**
- **LowShapes found no breach** in `tests/lang`, the bootstrap and MLton
  (E3 later found one false alarm at -O2, since fixed).
  - The comparison with `Rep.fields`, which is circular, never disagreed.
  - On MLton, these were checked against a known shape (and fell to
    unknown):

    | Operation | Checked | Unknown |
    |---|---:|---:|
    | `select` | 23,187 | 8,175 |
    | `field` | 21,570 | 555 |
    | `decon` | 10,611 | 596 |
    | `call` | 6,329 | 15,920 |
    | tag tests | 15,726 | 859 |

    40 `Field`s and 41 `Decon`s are of a (stamp, tag) that no `Con` in the
    program makes.
  - The cost: +0.5% (small), +1.8% (HaMLet), +4.6% (the bootstrap).
- **Registers shared by rep and shape:**

| | Registers | Added | Functions past tier 2's 64 registers (`compile.c:488`) |
|---|---|---:|---|
| the bootstrap | 51,795 → 61,017 | +17.8% | 2 → 5 |
| HaMLet | 12,902 → 15,756 | +22% | 0 → 1 |
| MLton | 174,978 → 213,097 | +21.8% | **2 → 50** |

  The instructions grow 0.1-0.2% (moves), the `.rbc` 0.3-0.5%.
- **Frames in `meta.blocks`.** A frame of every set `ptr` and `con`
  register at each block's entry is:
  - 355,574 entries over 43,594 labels for the bootstrap;
  - 584,968 over 97,791 for MLton, about 1.2 MB at 2 bytes, beside a
    10.4 MB `.rbc`.

  Only the registers a block reads before it writes them: 15,523 and
  37,837. But frames cover block entries only, while 60-72% of the
  downcasts are heap reads *inside* blocks. A shape of one level cannot
  type those; that needs the shapes of fields, which is to say types.
- **Tier 2 trusting less** (25 benchmarks at `--jit=all --jit-tier=2`;
  outputs the same):

| Variant | Instructions, median (range) | Cycles, median |
|---|---|---:|
| C: the kind, length and function-index tests kept on every `ptr` and `con` register | +15.1% (0.1 … 41.7) | +12.2% |
| C-kind: the kind test only | +10.5% (0.1 … 33.7) | +6.3% |
| C-call: `CALL`'s test of the function index only | +0.06% (0 … 2.7) | about 0 |

  C-call is free, and closes "a wrong rep sends control anywhere". Under C,
  E7's segfault becomes a fatal error.

**For the roadmap** (D8, D14):
- **Shapes belong in LowLint**, which checks Lower without dataflow since
  Low is SSA, and costs 0.5-4.6%. They do not belong in the code: sharing
  registers by shape costs a fifth more registers and leaves 50 of
  MLton's functions past tier 2's limit, against 2; frames do not reach heap reads.
- **The check of layouts across functions is the program-wide count of
  fields per (stamp, tag)**, not a datatype on Low's nodes (D14).
- **Memory safety for untrusted code is the VM roadmap's:** C or C-kind
  behind a flag, or a verifier with types. C-call costs nothing and is
  handed to it as the first step.

### E8. runeopt's check of the stack code, in the compiler

**Question.** Does runeopt's `RbcCheck`, run in the compiler after the
stack target, find anything, and at what cost?

**How** (`patches/E8-rbccheck.patch`). A hook of 45 lines,
`src/driver/rbccheckhook.sml`, with `src/isa` and `src/opt`'s reader and
check added to the compiler's build. It runs after the `stack` stage of a
whole program and at a link of stack code: `Emit.serialize`, then
`Rbc.read`, then `RbcCheck.check`.

**Result.**
- **No refusal** on `tests/lang`, the 510 benchmark programs, the
  bootstrap at every level, or MLton whole (806,020 stack instructions).
- **The cost:** +3.9% (small), +9.0% (HaMLet) and +19.4% (the bootstrap)
  of a stack compile.
- **It is superlinear:** 12.6 s to check MLton, plus 0.6 s to serialise,
  out of a 163 s compile, against 0.41 s for the bootstrap's 326k
  instructions. `Rbc.read` or `RbcCheck` has a quadratic part.

**For the roadmap** (D11, M10): the stack code's check is worth having
behind `--lint`, once its quadratic part is found. It is not worth having
always on, since nothing trusts the stack code's types and it found
nothing.

### E9. Lint where it does not run today

**Question.** Do today's lints find anything in the places they do not
run, and what would running them there cost?

**Prediction.** That bugs would be found, as turning `RUNE_LINT` on for
the tests found three on 2026-10-25.

**How.** E1's instrument with new keys (`results/E9/`):
- `simplify-round` and `simplify-def`: MidLint after each of `simplify`'s
  rounds, and per definition in `withCopies`;
- `lower-results`: the invariant of `results` in LowLint, that a slot is
  read right after its call;
- `cached-mid`: the compiler library's Mid as it is read;
- `functor-body`: the bodies `MidCodec` decodes;
- `midcanon-renaming`;
- `code-rt`: a unit's code written by `UnitFile` and read back, and
  compared;
- the Mid round trip after every stage.

Also:
- `lib/cache` built again with `--lint`;
- `check-levels`' builds made with the register target and run at tier 2
  with `--checked`.

Each compile with the new checks was also compared byte for byte with the
same compile without lint.

**Result: no compiler invariant was breached anywhere** (`findings.txt`).
- **The corpora, each compiled clean and to the same bytes:**
  - `tests/lang` and `tests/perf`: 363 programs at -O0, -O1 and -O2 whole,
    `--units`, `--units --target=stack` and `--units --whole -O2`;
  - `tests/basis`: 240 tests, four ways (E7's later re-check ran 128 of
    them);
  - the bootstrap: -O1, -O2, `--units`, `--units --whole`;
  - MLton: whole and `--units --whole`, 791 units, without the Mid round
    trip.
- **`lib/cache` rebuilt with `--lint`.** All 768 entries, the Basis and
  the compiler library for both targets, compile clean and to the same
  bytes as without lint. That took 28.4 s instead of 19.6 s for the
  register target, and 31.4 s instead of 19.1 s for the stack.
- **`check-levels` on the register target.**
  - It ran O0, O2, U0 and U2, and UL, a true `--units` build linked by
    `Link`, each with `--lint --mid-roundtrip`.
  - Each ran at the default JIT and at `--jit=all --jit-tier=2 --checked`.
  - All 363 programs gave the same output, errors and exit code in every
    build.
- **The compiler library's Mid:** clean, on `tests/lib/compiler/api.sml`.
  The gap matters only at -O0; at -O1 `expand`'s lint already covers that
  Mid.

**One real defect.** Under `--units`, `--mid-roundtrip` changes a unit's
basis file. For `tests/lang/dec.fun.clauses_astra-function-clause-many.sml`,
the basis's count of stamps goes from 1,021 to 2,036.
- **The cause:** `MidText.parse` takes a fresh stamp from the elaborator
  for every name it reads (`midtext.sml:398,406`). A whole program is
  renumbered after (`MidCanon`), which hides the drift; a unit's basis
  keeps it.
- **The effect:** the cache's configuration does not record
  `--mid-roundtrip`, so an entry made with it is taken by a compile
  without it, and `--verify-cache` sees the two disagree.
- **The reproducer:** `results/E9/bugs/mid-roundtrip-changes-basis.sh`.
  The fix is to parse with a scratch counter and restore the elaborator's
  afterwards. M1.

**What the new places cost** (`cost.sh`):

| Check | HaMLet -O1 | bootstrap -O1 | MLton |
|---|---:|---:|---:|
| the invariant of `results` | 2.0M (0.16%) | 9.9M (0.6%) | 29M (0.12%) |
| functor bodies, at the next unit's passes | 3.4M | | 5M (units) |
| `midcanon`'s renaming | 29M | 70M | 275M |
| MidLint per definition inside `simplify` | 55M (4.4%) | 187M (12%) | 622M (2.6%) |
| MidLint per round of `simplify` | 152M (12%) | 504M (32%) | 1,807M (7.6%) |
| the code's round trip, `--units --whole` | 11% | 16% | 1,470M |
| the Mid round trip after every stage | about 8 times the compile | | not run |

**The prototypes' own false alarms**, each a rule the real checks must
follow:
- **`results`:** after Lower's last step, a `CallK` names a function's id,
  not the Mid global that `results`' tables are keyed by
  (`lower.sml:1285-1307`). The check must invert `Lower.globalFids`.
- **Inside `simplify`:** `drain` empties the lists of pending copies
  before it simplifies them, so a copy naming a sibling copy looked
  undefined. The check's context must include the batch. MidLint's rule
  for `SetGlobal` looks only at a part's own globals (`midlint.sml:215`),
  so a part needs a context for the globals it sets.
- **The code's round trip:** `UnitFile.read` normalises the code:
  - `Op` becomes `Ops`;
  - labels are renumbered, and those nothing jumps to are dropped;
  - two labels at one offset merge;
  - a label and a position at one offset swap.

  Bytes written again are the same, and the code compares equal when
  labels are compared by their offsets.
- **Functor bodies at decode time:** the datatypes they name are not yet
  in `Ty.datatypes` ("slice has no constructor 0"). Linted at the start of
  the next unit's Mid passes, they pass.

**For the roadmap.**
- **The plan's prediction failed.** Every lint in every new place found no
  bug on these corpora. The new places are worth their cost as guards
  against regressions, not as a source of finds today. The cheap ones:
  - `lib/cache` with `--lint`, about +45-65% of `make basis-cache`;
  - `check-levels` on the register target and UL;
  - the invariant of `results`.
- **The register target under `check-levels`** covers `Regs` and `Link`,
  which nothing covered (M1).
- **A check must never change the output.** One did.

### E10. The IR lints' gaps, turned on

**Question.** What do the rules the review and *Where we are* find missing
catch, and can each be turned on?

**How** (`patches/E10-gaps.patch`, `E10-fault.patch`; `results/E10/`).
- **The prototypes:**
  - **MidGaps** (270 lines), after every Mid stage;
  - **LambdaGaps** (188 lines), after `translate`;
  - **PrimSig** (120 lines), a parser of `src/isa`'s type strings, from
    which a table `PrimTys` is generated. All 414 parse. Three type names,
    `option`, `order` and `Word32.word`, are wildcards.
- **Where they ran:**
  - `tests/lang` at -O0, -O1 and -O2;
  - the benchmarks at -O1 and -O2;
  - the bootstrap at every level;
  - MLton whole at -O1.

  The Basis is in every program.
- **A hook that injects faults**, `RUNE_FAULT=STAGE:KIND[@N]` (250 lines,
  34 kinds), corrupts the IR after a named stage, to give every rule a
  negative test.

**Result:**

| Rule | Checked (`tests/lang` / benchmarks / MLton) | Breaches |
|---|---|---|
| type variables in scope, in Mid | every type | 10 of 353 programs, 49 of 510 benchmarks, the bootstrap, MLton |
| `MkExn` against `Ty.exnArgs` | 3,445 / 30,648 / 206 at `mid` | none, but **none checked after `simplify`** |
| `Prim` against its parsed signature | 417k / 1.55M / 50.6k | none |
| `Const`'s kind and range | 260k / 1.10M / 44.7k | none |
| `unsafe_cast` by origin | `tests/lang` at `mid`: open constructors 64, the program's own 61, slots 22 | 1, a false alarm |
| a `Do`'s list against what it sets | 2,909 / 4,889 / 150 | 2, benign |
| LambdaLint's fixed `Gen` | 7,871 / 152,629 / 5,449 instances | none |

**What they found.**
- **Lift leaves type variables free (a bug).**
  - Lift gives each lifted function every type variable its body names as
    extra type parameters, including those an inner polymorphic function
    binds. It then passes them at call sites where nothing binds them
    (`lift.sml:103-141, 235-241`; `gensOf` collects every `Gen` and
    ignores inner schemes).
  - It first shows at `lift` in 46 benchmarks and one program of
    `tests/lang`. The reproducer is `results/E10/bugs/lift-tyvar.sml`: a
    function `fn g63 ['b]`, whose `'b` belongs to the inner function, is
    called as `g63['b]` from a monomorphic `g64`.
  - MidLint is silent, since `Ty.equal` compares ids. Nothing was
    miscompiled, because the ids are unique, but Mid is no longer well
    scoped, and any substitution through it would capture.
- **ToMid's output is not well scoped either**, so the rule cannot be
  turned on before a decision:
  - values that nothing generalises keep generics unbound
    (`let val [] = [] in … end`);
  - functor bodies make a polymorphic declaration a monomorphic `Fun`
    aliased by a generalised `Let`, and some `Let`s generalise a
    parameter bound by a lambda, or an application. Examples:
    `tests/lang/mod.functor.functions_expand`; 171 lines of MLton at
    `mid`, such as mlyacc's token functions;
  - polymorphic pattern bindings nest schemes that bind the same `Gen`
    again (`val Box id = Box (fn x => x)`).
- **`MkExn`'s check goes blind after the first pass that copies code.**
  - Copies get fresh stamps with no entry in `Ty.exnArgs`. So
    type-checker.md's open case (`exception E of 'a` inside a function,
    `results/E10/bugs/exn-open.sml`) is checked only in the original,
    where `'a` is the function's own, and never in the specialised copies.
  - The "same question" type-checker.md expected does not come up, but
    only because nothing is checked.
  - To check copies, the argument's type must travel with the
    constructor:
    - an `ExnCon` of a type in `Ty`;
    - or `Expand` and `Simplify` registering each copy's stamp with the
      substituted type, as `Ty.extrasOf` does for datatypes.
- **An `unsafe_cast`'s origin cannot be told from its type.** The
  program's own cast through `unit` (`tests/lang/mod.functor.functions_review`,
  case 6) looks like a dynamic slot's. The origin must be a primitive of
  the compiler's own, as `functor_cast` is.
- **The rule for `Do` is too strict as written.** After `simplify`, a
  `Do` whose expression always raises still lists a global it no longer
  sets (`tests/lang/rt.exn.uncaught_astra-bind-constructor`). The rule is
  "set on every path that returns".

**Faults injected** (`fault-neg.sh`): 34 of 36 (stage, kind) specs found a
place to corrupt.
- **Today's lints catch 29 of the 34:** 25 at the corrupted stage, and 4
  only at Lower, three stages late, through LowLint's reps.
- **With the prototypes all 34 are caught**, each right after the stage.
  The ones only a prototype catches:
  - a wrong `MkExn` payload, at `translate` and `mid`: missed today;
  - a primitive's name, at `translate` and `mid`: caught today only at
    Lower;
  - a constant's kind: today only at Lower, and after `simplify` missed
    altogether;
  - a function's type variables dropped after `simplify`: missed today;
  - a `Select` of a field the tuple lacks, after Lower: missed today.

**The hook against readers.** MidText's reader is 405 lines, with a printer
of 236. Readers for Lambda and Low would be about 400 lines each, and Low
would need a printer that loses nothing. The hook is about a third of
that, follows the IR as it changes, and corrupts real output. But it is
positional, and two specs found no place. So a negative test is a tuple
(stage, kind, program, expected message), not a file of IR.

**For the roadmap** (M4):
- **Turn on now:** `MkExn`, with the argument's type carried through
  copies; `Prim`, from structured types generated by IsaGen; `Const`; and
  `Do`, with the refined rule.
- **Turn on after fixing Lift and deciding what Mid's type variables
  mean:** the environment of type variables. Mid is meant to be System F
  (*Decisions*, D17); ToMid's functor bodies and ungeneralised values are
  not.
- **Check casts once their origin is a primitive.**
- **Give every rule a negative test** through the hook.

### E11. The literature and other compilers

**How.**
- Papers read in the authors' texts.
- Eighteen systems' checks, all but Lua's read in their sources under
  `/home/ruud/reference`. Nothing was built.
- Notes in `results/E11/`.

**Result:** *What the literature says* and *What the implementations do*.

### E12. What the LSP gains

**Question.** What would types on every node change for the editor, and
can they be worked out on demand instead of kept?

**How** (`results/E12/`). E5's table was dumped for a sample: HaMLet's
file and six of the compiler's, 796k positions of code. The sample was
compared with today's facts, and `typeAt`'s scan was timed on real spans.

**Result.**
- **Coverage.**
  - Today's facts already "answer" 90.6% of positions, and every node
    would answer 91.0%. But 14.4% of positions, and 26-40% in the
    compiler's files, are answered by the fact of a whole `fun`: a
    declaration's fact spans its whole text (`api/facts.sml`).
  - With every node, **the answer changes at 20.1% of positions**: 15.5%
    in HaMLet, 28-41% in the compiler. The new answers are those of
    `let`, tuples, constructor patterns, `case` and the like.
- **Ties.** 3,126 spans carry several nodes, and 2,968 of them have
  different types. All are an infix application and its tuple, in
  expressions and patterns. The rule must prefer the application.
- **`typeAt`'s linear scan** (2,000 queries, pinned):

| Facts | ms per query |
|---|---:|
| today's, 29,340 | 0.73 |
| every node, 53,040 | 1.66 |
| 5 times as many | 4.3, 7.3 |
| 10 times | 9.1, 14.3 |

  An index painted per position answers at once. Built by the spans'
  widths, it takes up to 4 s at ten times; a sweep builds it faster.
- **Printing every node eagerly:**
  - HaMLet: 80k types, 2.59 MB, 0.18 s;
  - the bootstrap: 245k types, 6.5 MB, 0.36 s.

  Today's facts take 1.54 MB and 3.85 MB. Lazily, a node costs about 8
  bytes plus the pool. With a fresh printer per fact, as today, **363 of a
  sample's 901 type variables appear under two or more names** across its
  hovers (HaMLet: 348 of 851). One printer per unit fixes that.
- **Binders.**
  - 29% of HaMLet's lambda-bound binders, 6.6% of the bootstrap's and
    15.7% of MLton's have a type that names an enclosing binding's generic
    variables. They are not polymorphic, so showing a "scheme" there
    misleads.
  - Polymorphic let-bound binders are 14%, 4.5% and 7.6%.

  A hover should show a binder's type, with only that binding's own
  quantified variables marked.
- **On demand.** Working out the enclosing declaration from its
  witnesses takes:
  - 0.12-0.28 s for the largest top-level declaration (13-20k nodes);
  - 0.10-0.13 s for the largest `val` (HaMLet's of 16,570 nodes; MLton's
    `ml.grm.sml`, 16,993);
  - at most 0.07 s in the compiler (`parser.sml`, 7,350 nodes).

  So hover from the witnesses, with the enclosing declaration worked out
  when asked, is feasible, given each declaration's environment. The LSP
  already records scopes (`Env.noteScope`).

**For the roadmap** (D7, M14):
- **Hover at every node** changes a fifth of the answers.
- **What it needs:**
  - an index, not a scan;
  - a rule for ties;
  - one printer per unit;
  - a binder's type rather than a scheme.
- **Keep or work out on demand.** Either works. Keeping costs 8 bytes a
  node; working out costs a tenth of a second on the largest declaration.

### E13. Overloading's context, and free type variables at top level, in eight compilers

**Question.** Appendix E leaves the size of overloading's "surrounding
text" to the implementation, below a bound. Appendix G.8 leaves what
becomes of a type variable free at top level to the implementation, as
one of two answers. What do the implementations choose, and where does
Rune stand?

**How** (`results/E13/`, `run.sh`). Thirteen small programs, run on:
- Rune (`d551f19dd`);
- HaMLet 2.0.1;
- MLton 20241230;
- Poly/ML 5.9.2;
- SML/NJ 110.99.9 and 2026.2;
- MLKit 4.7.25;
- Moscow ML 2.10.1 (`mosmlc`, with `-toplevel` for the programs that mix
  structures and values).

**Overloading.** `fun double x = x + x` and then `double 2.0`, placed in
different contexts. A means accepted, with `+` at `real`; R means rejected,
`+` defaulted to `int`:

| Where | the Definition | HaMLet | SML/NJ, MLKit | Rune, Moscow ML | MLton, Poly/ML |
|---|---|---|---|---|---|
| one `structure … end` | R | R | R | A | A |
| one `local … end` | R | R | R | A | A |
| two declarations at top level, no `;` | R | R | R | R | A |
| the same, with `;` | R | R | R | R | R |
| `val y = let fun double … in double 2.0 end` | A or R | R | A | A | A |
| `let val d = fn x => x + x val z = d 2.0 …` | A or R | R | A | A | A |
| `(fn x => x + x) 2.0` | A | A | A | A | A |

Appendix E bounds the context from above: "no larger than the smallest
enclosing structure-level declaration", and smaller if the implementation
asks. So there are four choices:
- **the innermost `val` or `fun` (HaMLet):** below the bound, as allowed;
- **the smallest enclosing structure-level declaration (SML/NJ, MLKit):**
  the bound itself;
- **the declaration at top level (Rune, Moscow ML):** a whole structure, or
  a `local`. This is above the bound, which `docs/language.md` lists among
  its *Deviations* (Overloading) and runespec names `E.topdec`;
- **the topdec, to `;` or the end of the file (MLton,
  Poly/ML):** further above it.

**Free type variables at top level.** `val r = ref []` and its kin:

| Program | Rune | HaMLet | Poly/ML | SML/NJ | MLton | MLKit | Moscow ML |
|---|---|---|---|---|---|---|---|
| `val r = ref []`, never used | refused | refused | warned; a unique monotype | warned; a dummy type `?.X1` | warned; left open | refused | refused |
| then `r := [1]`, no `;` | runs | runs | runs | error | runs | runs | runs |
| then `r := [1]`, after a `;` | refused | refused | error | error | runs | runs | runs |
| `r` in a structure, set by a later declaration | runs | runs | runs | error | runs | runs | runs |
| `val x = [] @ []`, never used | refused | refused | monotype | dummy | warned | refused | refused |
| a functor's result `val id = (fn x => x) (fn x => x)`, then `A.id 1` | refused at the functor | runs | error | error | runs | crashes | runs |

There are five behaviours, along two axes: when the type must be
determined, and what becomes of it if it is not.
- **Refused at the end of the topdec (Rune, HaMLet):** G.8's
  first answer. Rune also refuses at a functor's declaration, as rule 89
  says; HaMLet does not look into a functor's result.
- **A fresh monotype at the end of the topdec (Poly/ML):**
  G.8's second answer.
- **A dummy type at the end of each value declaration, at any depth
  (SML/NJ):** too early. It rejects two programs the Definition accepts: a
  later use in the same topdec, and one inside a structure.
- **Determined by any later use in the program; refused if none
  determines it (MLKit, and Moscow ML in a compiled unit):** the "arbitrary
  monotype" chosen with hindsight.
- **Determined by any later use, and only a warning if none does (MLton):**
  the same, for a whole program.

**Rune's three contexts are not one.**
- Overloading is settled per declaration at top level.
- Flexible records and free type variables are settled per topdec, to
  `;` (`--flex-records`' default, `topdec`).
- `docs/language.md` ties the second to the first: "In the modes of a
  top-level declaration, the free type variables of rules 87-89 are those
  left where the top-level declaration ends".

**Also found:**
- MLKit 4.7.25 fails with an internal error on the functor
  ("Impossible: IntModules.reelaborate.ParseElab.FAILURE").
- SML/NJ rejects the two valid programs above.

Neither is reported.

**For the roadmap** (D18, D19, M15):
- **The owner's direction (2026-10-26):** like `--flex-records`, both
  become options of the language, each mode named after what it does and
  which implementation does it.
- **Overloading's default is the Definition's bound;** Rune's present
  context becomes an option.
- **Free type variables keep Rune's present default.**

## Constraints

What any design here must keep.

- **Six hosts and Rune.**
  - **What builds the compiler:** MLton, Poly/ML, MLKit, SML/NJ (110.99.9
    and 2026.2), `smlnj32`, and Rune itself, whose bootstrap reproduces
    itself byte for byte. `check-cross` holds every build's output to the
    others'.
  - **What new code must do:** a new lint, `SourceTy`, AstLint and a
    verifier are compiler code. They must compile and run alike on every
    host. They are Basis-only SML, with no physical identity: an identity
    is a number a table gives, as `Ty`'s hash-consing does.
  - **What decides a design:** choices made for speed are decided by Rune
    at tier 2. The other hosts are measured for information (the owner,
    2026-10-21).
- **A check never changes the output.** A lint, a verifier and AstLint
  read; they never rewrite.
  - Every program compiles to the same bytes with checks on and off. This
    is testable, and M1 adds the test.
  - S42, a whole program the same bytes whole and from units, is
    untouched.
  - Types that the syntax records are new data. They must not change what
    Translate makes: Mid byte for byte the same (M11's gate).
- **What the checks cost in `make check`.**
  - **The tests:** every compile a test makes is linted
    (`RUNE_LINT=1`), so a lint's cost is paid once per compile of the
    suite, tens of thousands of times.
  - **The bootstrap:** it is built with `--lint --mid-roundtrip`.
  - **The budgets:** they clear `RUNE_LINT` and count the compiler as
    shipped (`tests/perf/*.budget`, instructions of bytecode). So a check
    that is always on shows in `compile-*` and the bootstrap's budget, and
    one behind `--lint` does not.
- **What a check that is always on costs a user.**
  - **The bill:** every compile pays it: a REPL line, one changed unit on
    a warm cache, a small program cold, the bootstrap and MLton's 606
    files.
  - **False alarms:** an alarm stops a correct program's compile with
    "internal compiler error". So a check goes on only after:
    - it has run clean on every corpus Rune is tested on;
    - its message says that the fault is the compiler's, and how to compile
      without it (D13).
- **Independence.** A check that shares its logic with what it checks
  cannot find that logic's mistakes:
  - AstLint shares no code with `Unify` or `SigMatch`, and reads `Types`
    only through the zonk (D4);
  - the register verifier takes its rules from the instruction sets'
    descriptions, not from `Regs`;
  - LowLint does not hold Lower to the very `Rep` that Lower used (D14).
- **Determinism.** A compile is deterministic, so a breach found by a
  cheap check can be diagnosed by compiling again with every check on
  (D13 B).
- **Memory.**
  - MLton's 606 files compiled whole peak at about 10.5 GB already, with
    the heap capped at 5 GB (`docs/plans/performance-64bit.md:1049`); E1's
    `-O1` compile peaked at 5.9 GB.
  - The language server's analyses run within supervised budgets
    (`b4ee62bdb`).
  - Types kept on every node of a large program are counted before they
    are kept (E5).
- **The incremental parser.**
  - The editor's front end copies every node at the bridge
    (`SyntaxAst.copy`), so anything keyed by node must be made afresh
    there.
  - The batch parser and the incremental parser must give the same keys
    to the same text, or the LSP's types and the compiler's differ.
- **The cache.**
  - Its entries and version keys (`UnitBasis.version`, `UnitCache.version`,
    `UnitFile.version`, `UnitMid.version`) change with what a unit records. Anything this
    roadmap adds to an entry bumps them: a "linted" mark, expected arities
    and reps of imports, recorded witnesses.
  - The frozen Basis cache is rebuilt by `make` and shipped.
- **The VM is not this roadmap's.** The brief leaves verification in the
  VM, for untrusted code, to a later roadmap. Here the VM changes only
  where the compiler's output needs it to. What tier 2 trusts (*Where we
  are*) is measured (E7b) and handed on, not changed, unless the owner
  lands C-call (D8).
- **Errors stay where they are.** Better error messages are a later
  roadmap. What this one lays for it (D6) must not change any message the
  suites expect (`tests/errors`, `tests/diagnostics`).

## The architecture

What the compiler looks like when this roadmap is done. Each part names
the decisions it rests on.

```
 source ─▶ parse ─▶ elaborate ──────────────▶ translate ─▶ Lambda ─▶ mid ─▶ Mid passes ─▶ lower ─▶ Low ─▶ registers ─▶ emit/link
             │         │  records witnesses        │            │        │         │            │        │            │
          node ids     │  (by node id)       LambdaLint      MidLint  MidLint   MidLint     LowLint   RegVerify   interfaces
                       ▼                                              (L2: per                + shapes   (per unit)   checked
                 SourceTy, zonked                                       pass)                              at link
                 after finish ─▶ AstLint (L2)
                       └──────▶ the LSP's types, error messages (later)
```

### The syntax: ids, witnesses and a type language of its own (D1, D2, D6)

**Every node has an id**, given by the parser in the order it makes nodes.
`SyntaxAst.copy` gives fresh ones, so the editor's copies are keyed apart.
Ids are what side tables are keyed by. They are unique by construction, as
a span and constructor tag are not: two `PVar`s share one in
`val … and rec` (`parser.sml:637-638`), though E5's corpora have no
collision.

**The elaborator records witnesses**, always: the choices the Definition
leaves open (*What the Definition says*). Today's slots hold most of them,
and stay as they are for Translate:
- the instance at each identifier;
- the constants' types;
- the record at `#lab`;
- the type of `[]` and of a flexible record pattern;
- the binders' schemes in `Ty.binders`.

What is added, in tables by node id, is about 6-8% of the nodes (E5):
- the instance at each constructor pattern;
- the type of each wildcard and of each `raise`;
- the `[]` pattern;
- the names each datatype declaration created;
- the explicit type variables each `val` scopes;
- the type variables each binding generalised, taken *at the binding*,
  before a group's first generalisation marks them all (E6);
- the defaults chosen for overloaded identifiers and constants;
- whether each declaration at top level elaborated, so that a failed one's
  records are known to be junk.

The tables are dropped by ranges of ids, as `UnitBasis.undo` drops stamps.

**`SourceTy`** is the type language of the syntax: immutable and
hash-consed (so equality is an id's comparison), with:
- type variables that keep their equality, their source name and their
  overloading class;
- type names by stamp, whose equality is answered from the table by stamp,
  which is the authority (E6);
- records with labels;
- arrows.

It is made from the elaborator's `Types.ty` by a zonk after
`Elaborate.finish`, the one point where no type can change any more in any
`--flex-records` mode (E5). The zonk is memoised per cell, keyed by
integers, done in a batch per declaration and bounded by a budget of
steps, like the translation's. It runs only when something reads
`SourceTy`: AstLint, the editor, and later the error messages.

Translate keeps reading the elaborator's types as it does, so Mid does not
change (M11's gate). `Ty.ty` stays the IRs' type: it erases labels,
abstraction and equality, as an IR should, and a checker of the source
must not (*Where we are*).

### AstLint (D3, D4, D5, D16)

A structure of its own that **checks the derivation the elaborator
found**:
- it reads the syntax, the witnesses and the zonked types;
- it builds its own environment;
- it works out every node's type bottom-up, with:
  - equality of `SourceTy`;
  - one-way matching of a scheme against a recorded instance;
  - its own `Clos`, non-expansiveness and scope of explicit type
    variables.

It never calls `Unify`, `SigMatch` or the defaulting, and shares no rule
with the elaborator. Each rule names the Definition's rule it checks, as
HaMLet's elaborator does. It checks what *What the Definition says*
lists, and reads Rune's deviations and extensions by runespec's names for
them.

It runs after `finish`, before Translate and before `UnitBasis.undo`, at
level 2 (D13), so in every compile of the tests. It needs no unification
because of the witnesses (E6).

In its first form the module language is **axioms**: the Basis's
environments, and the results of ascriptions, applications, dynamic
modules and functor parameters. In its second, the elaborator also
records the fresh names the module language chose and keeps schemes
rather than stamps, and AstLint checks matching by paths and one-way
matching, and discharges the axioms (D5, after gate G1). Programs the
elaborator wrongly *rejects*, as `(conexp : ty)` was, are runespec's to
find, not AstLint's (D16).

### Two choices of the language as options (D18, D19)

- **Overloading** is resolved, and defaulted, at the end of the context
  `--overloading` names. The default, `declaration`, is Appendix E's bound.
- **Free type variables at top level** are treated as `--free-tyvars`
  says. The default, `refuse`, is Rune's present answer to rules 87-89.
- **`--flex-records`** keeps flexible records alone.

All three are in the cache's configuration. AstLint takes them as its
configuration: it checks what each mode makes checkable (a default within
its class; no free type variable where the mode refuses one), and names
each mode by its reading.

### The editor's types (D7)

- **Hover:** a type at every node, from the witnesses, with each
  declaration's types worked out when first asked and kept. The largest
  declaration takes a tenth to a quarter of a second (E12).
- **Lookup:** an index from positions to nodes, not a scan.
- **Ties:** where an infix application shares its tuple's span, the
  application is shown.
- **Names:** one printer per unit, so a type variable keeps its name
  across hovers.
- **Binders:** a binder shows its type, with only that binding's own
  quantified variables marked.

### Lambda and Mid (D17, and track I)

LambdaLint and MidLint keep their shape, with the rules E10 found missing:
- **`MkExn`'s payload** against the exception's argument, with the
  argument's type carried through the copies passes make;
- **a primitive's arguments and result** against its signature, from
  structured types that IsaGen generates;
- **a constant's kind and range**;
- **a `Do`'s globals:** set on every path that returns;
- **casts** checked by origin, once each origin is a primitive of the
  compiler's own, as `functor_cast` is.

**Mid is System F** (D17): every type variable is bound by an enclosing
binder. Lift and ToMid are made to keep that, and MidLint gets an
environment of type variables.

**The cost** is cut before levels are cut:
- **MidLint keeps imperative tables**, with the scope a single table
  entered and left. That is 37-40% of today's, with the same rules.
- **LowLint is linear** in a function's blocks and variables.
- **`midcanon`'s output** is checked as a renaming of its input, not
  linted again.

### Low: representations and shapes (D14)

- **Directed order:** LowLint's `agree` becomes directed, so that `any`
  into a typed rep is a downcast, counted, not an agreement.
- **Shapes:** each Low variable has one, from the Mid type Lower records
  for it: `tuple(n)`, `data(stamp)`, closure, opaque or immediate. Low is
  SSA, so a shape never changes and needs no dataflow.
- **What shapes check:**
  - a `Select` within its tuple's arity;
  - `Field` and `Decon` on data;
  - one number of fields per (stamp, tag) across the program, which holds
    Lower's producers and consumers to each other rather than to the
    `Rep` they both used;
  - a tag test of the right datatype dominating each `Field` and `Decon`
    whose datatype has more than one constructor.

### The register code (D8-D11)

**`RegVerify`** checks the register code after `registers`, in one forward
pass:
- each register's declared rep, under the directed order, with downcasts
  trusted and counted;
- "unset", read by nothing;
- the scratch tracked per block, and `arrive` at loop heads;
- handlers' depths;
- the order the JIT relies on;
- calls' arities and arguments;
- closures' captures;
- primitives' reps.

Each function's result rep, captures and the globals' reps come with the
code from Lower, not derived again, so that the check is one pass (E7).
The per-opcode rules, the operands' roles and reps, the implicit traffic,
"followed by", the primitives' types and which are image primitives are
generated from `src/isa`. The dataflow is written by hand (D10).

It finds the bugs of `Regs`, and with the interfaces at the link those of
`Link`; `Emit`'s bytes it does not see. It does not make an untrusted
`.rbc` safe, since 12-33% of typed writes are downcasts that only ML
typing justifies (E7). That is the later VM roadmap's, and this
one hands it E7b's measures. The stack code gets runeopt's `RbcCheck`, at
level 2.

### Units, the cache and the link (D15)

- **Once per unit:** a unit's code is verified when it is compiled. Its
  cache entry records that it was, and that its Mid was linted.
- **Interfaces at the link:** each import carries the arity, the reps of
  the parameters and the result rep the importer expects, and each unit
  the reps of its globals. The link checks these, in time proportional to
  the imports, rather than verifying every cached unit again (E7: +22-42%
  at every link).
- **Schemes:** a unit's imported schemes are checked against what the
  exporting unit's basis says when the entry comes from the cache.
- **The frozen Basis** in `lib/cache` is built with lint.

### Where each check runs, and at which level (D12, D13)

- **Level 0, always on:** what runs today (the passes' own assertions, the
  decoders, the loader), plus the checks below the threshold. These are
  the invariant of `results`, the functor bodies at the next unit, the
  interfaces at the link, the schemes of a unit taken from the cache, and
  `RegVerify` if M8 brings it under the threshold.
- **Level 1, the boundaries:** LambdaLint after `translate`, MidLint after
  `mid` and before `lower`, the renaming check after `midcanon`, LowLint
  with shapes after `lower`, and `RegVerify`.
- **Level 2, every pass:** today's `--lint`, plus the new places (inside
  `simplify`, per definition; the code's round trip), AstLint and
  `RbcCheck`.
  This is what the tests compile with.
- **Level 3, deep:** level 2 plus the Mid round trip after every stage.
  It costs about eight times a compile, so it runs in one tier of
  `make check`.

A breach at a lower level is diagnosed by compiling again at level 2,
since a compile is deterministic and no check changes it.

## Decisions

Each decision gives the options, what favours each, and a recommendation.
The owner took every recommendation on 2026-10-26. Each decision says so
under its heading, and the table gives the choice.

| Decision | Decided (2026-10-26, as recommended) |
|---|---|
| D1. How nodes of the syntax are keyed | A: an id on every node, tables by ranges of ids |
| D2. What the elaborator records, and in what type language | A: the witnesses, always; `SourceTy`, zonked after `finish` when read |
| D3. What AstLint checks | A: the Definition's rules, Rune's deviations by runespec's names, policy by its result only |
| D4. How independent AstLint is | A: its own rules and environment over shared data, rule by rule after the Definition |
| D5. The module language in AstLint | B: axioms first, then the fresh names recorded and the axioms discharged, after gate G1 |
| D6. The groundwork for error messages | A: ids as anchors, spans on clauses and rules, one printer, a declaration's status |
| D7. The editor's types | A: every node, worked out per declaration when first asked |
| D8. Types for the register code | A: reps under a directed order, with shapes in LowLint |
| D9. How the verifier gets its facts | A: from Lower, carried in `Code`, and in `.rbu` for cached units |
| D10. Where the verifier's rules come from | A: tables generated from `src/isa`; the dataflow by hand |
| D11. Which code is verified | A: the register code; `RbcCheck` for the stack code at level 2 |
| D12. Where each check runs | the placement table |
| D13. Levels, and what is always on | B: four levels; a check always on under 1% of each large compile and 0.05 ms a REPL line, all of level 0 under 2% of the bootstrap |
| D14. Layouts across functions | B: shapes in LowLint, counts of fields program-wide |
| D15. The boundary of units | A: verify once per unit, check interfaces at the link |
| D16. runespec | A: independent of AstLint; a third oracle once merged |
| D17. What Mid's type variables mean | A: Mid is System F |
| D18. Overloading's context, as an option (the owner's direction) | `--overloading=binding\|declaration\|toplevel\|topdec`, default `declaration`, Appendix E's bound |
| D19. Free type variables at top level, as an option (the owner's direction) | `--free-tyvars=refuse\|monotype\|dummy\|later\|later-monotype`, default `refuse`, as today |

### D1. How nodes of the syntax are keyed

**Decided: A** (2026-10-26), as recommended.

Types, witnesses, facts for the editor and, later, errors all need to name
a node.

- **A. An id on every node,** given by the parser, fresh in
  `SyntaxAst.copy`, with side tables keyed by ids and dropped by ranges.
  **Recommended.**
  - **For it:** unique by construction, and immutable syntax. About 8
    bytes a node: 0.6, 1.9 and 4.1 MB for HaMLet, the bootstrap and
    MLton's expressions and patterns (E5). The ids are the anchors the
    editor and errors need. This is what rustc, rust-analyzer and GHC's
    `.hie` files do (*What the implementations do*).
  - **Against it:** one pass over every constructor, about 350 matches in
    19 files.
- **B. A key of span and constructor tag.** No change to `Ast`, and no
  collision in any corpus (E5). But nothing guarantees it: an infix
  application and its tuple share a span and differ only by tag. Each
  entry costs a hashed key, and the editor cannot name a node with it
  across edits.
- **C. A slot on every node** (Poly/ML, HaMLet): cheaper to read. But two
  mutable words a node, junk after a failed declaration, reset by every
  copy, and a node shared by a derived form needs cloning.
- **D. A separate typed tree** (OCaml's Typedtree, Roslyn): a second tree
  the size of the first, whose agreement with the syntax must itself be
  checked.

### D2. What the elaborator records, and in what type language

**Decided: A** (2026-10-26), as recommended.

- **A. The witnesses, always, and `SourceTy` made from them after
  `finish`, when something reads it.** **Recommended.**
  - **What it costs:** the witnesses are today's slots plus about 6-8% of
    nodes (E5).
  - **What it gives:** AstLint works out every other node's type without
    unification (E6), and the editor can do the same when asked (E12).
  - **The zonk** is after `finish`, the one point that is sound in every
    `--flex-records` mode; at a declaration's end it is not (E5). It is
    memoised per cell and bounded by a budget.
  - **Translate** keeps reading the elaborator's types, and Mid does not
    change.
- **B. Every node's type, always recorded and zonked.** It costs little
  memory (+5.6 MB on the bootstrap until `finish`) but much time: the
  prototype's zonk made the front end 41-52% dearer on HaMLet and the
  bootstrap, and a fast zonk is still a walk of every node on every
  compile. What it adds over A is a check of every node's recorded type,
  which nothing downstream reads.
- **C. In the IR's `Ty.ty`.** No: it erases labels, abstraction and
  equality, which a checker of the source and the editor need (*Where we
  are*).
- **D. In the elaborator's `Types.ty`.** Mutable, shared with the
  inferencer's union-find; a checker reading it reads through the very
  structure it is meant to check. OCaml's editor tooling pays for this
  with snapshots of the typer (Bour et al. 2018).

### D3. What AstLint checks

**Decided: A** (2026-10-26), as recommended.

- **A. The Definition's Core, as *What the Definition says* lists it.**
  **Recommended.** It checks:
  - instances against schemes, with equality and overloading classes;
  - `Clos`, the value restriction with `conexp` and the derived forms;
  - the scope of explicit type variables and rule 15's side condition;
  - the equality of datatypes;
  - constants' classes;
  - escapes from `let`;
  - every slot Translate reads;
  - each declaration's result;
  - closure at the top level.

  Rune's documented deviations and extensions, and the modes of
  `--flex-records`, `--overloading` and `--free-tyvars` (D18, D19), are read
  as Rune reads them, each named by runespec's reading (`spec/notes/M10-deviations.md`, and
  `docs/language.md`). Policy is checked only by its result: when a
  flexible record was settled, which default was chosen where both
  type-check. The parser's rewrites are trusted.
- **B. A, plus the policies.** The `--flex-records` mode's and the
  defaults' choices would be checked against records of them. That needs
  more records for little: E6 found no alarm of policy in any mode,
  because after the zonk a mode changes only what ends up polymorphic.

### D4. How independent AstLint is

**Decided: A** (2026-10-26), as recommended.

The literature suggests a gradient (*What the literature says*): a
separate checker over shared data, then one with
a written specification, then one mechanised.

- **A. Its own rules and environment, over the elaborator's data.**
  **Recommended.**
  - It reads the witnesses and `SourceTy`, shares no code with `Unify`,
    `SigMatch`, `Types` or the defaulting, and comments each rule with the
    Definition's number, as HaMLet does.
  - Independence is lost exactly where it would call the elaborator's
    code, so it never does.
  - The elaborator's records are data it checks. E6's prototype is this,
    at about 1,100 lines.
- **B. A, with runespec as its written specification**, rule for rule,
  once runespec is merged. A later step, not a different design.
- **C. AstLint generated from runespec's rules.** runespec searches for
  derivations, so a checker would have to be generated from its rules with
  the witnesses supplied. It is attractive, but it ties this roadmap to a
  branch that is not merged.

### D5. The module language in AstLint

**Decided: B** (2026-10-26), as recommended.

- **A. Everything at once.** The elaborator would record:
  - the bound names of each signature expression (rule 65's `T`) and the
    representatives of sharing classes (rule 78's `t`);
  - the fresh names at opaque ascriptions (rule 53's `T'`), and what each
    stands for;
  - the fresh names at applications (rule 54's `T'`);
  - the stamp range of each functor's body;
  - the names of dynamic modules.

  AstLint would find φ by paths and check enrichment by one-way matching.
- **B. The Core first, with the module language's results as axioms; the
  rest after gate G1.** **Recommended.** E6 checked MLton's 1,152
  declarations with 435 ascriptions, 360 applications and 270 functor
  parameters taken as given. The module records are larger and need one
  lesson applied first: one stamp carries several schemes after an
  ascription, so the records keep schemes, not stamps (E6).
- **C. The Core only.** Leaves the module language checked by nothing but
  the elaborator.

### D6. The groundwork for error messages

**Decided: A** (2026-10-26), as recommended.

The brief asks for groundwork only; the error-message roadmap comes later.

- **A. What the types on the syntax need anyway:**
  - node ids as the anchors of errors as data;
  - spans on clauses, match rules, labels and sequences of type variables
    (today a declaration's fact spans its whole `fun`, E12);
  - one printer over `SourceTy` for messages, hovers and AstLint;
  - each declaration's status, at top level.

  **Recommended.**
- **B. A, plus an error type** in `Types.ty` and `SourceTy`, so that a
  failed declaration still binds its names and the next error is not
  "unbound". That changes which errors programs report, and belongs to the
  roadmap that changes messages.

### D7. The editor's types

**Decided: A** (2026-10-26), as recommended.

- **A. A type at every node, worked out per declaration from the witnesses
  when first asked, and kept.** **Recommended.**
  - **Cost:** a tenth to a quarter of a second on the largest declaration
    of HaMLet or MLton, and less than a tenth in the compiler (E12).
  - **What comes with it:**
    - an index in place of the linear scan;
    - the application preferred where an infix application and its tuple
      share a span;
    - one printer per unit;
    - a binder's type, with only its own quantified variables marked.
- **B. Every node's type kept after every analysis.** About 8 bytes a node
  plus the pool, and the zonk on every analysis. Simpler, at a cost paid
  even for nodes nobody hovers.
- **C. As today.** A fifth of the positions answer with a larger node's
  type (E12).

### D8. Types for the register code

**Decided: A** (2026-10-26), as recommended.

- **A. Reps under a directed order, "unset", and downcasts trusted and
  counted; shapes checked in LowLint.** **Recommended.**
  - **E7 built it:** no false alarm in any corpus, once E3's on
    `tests/basis` were fixed in the prototype; it catches eleven kinds of
    corruption against the loader's one.
  - **Shapes in LowLint** cost 0.5-4.6% and found no breach, once E3's
    false alarm at -O2 was fixed (E7b).
  - **What it is:** a checker of `Regs` and, with the link's interfaces,
    `Link`, not of memory safety. 12-33% of typed writes are downcasts
    that only ML typing justifies.
- **B. Shapes in the code**, by registers shared by shape or by frames.
  Sharing by shape costs a fifth more registers, and leaves 50 of MLton's
  functions past tier 2's 64, against 2 (E7b). Frames cover blocks' entries, while
  60-72% of downcasts are heap reads inside blocks. Either way it needs the
  shapes of fields, which is to say types.
- **C. Tier 2 trusts less.** Keeping the kind, length and function-index
  tests costs a median 15% at tier 2, the kind test alone 10.5%, and the
  test of `CALL`'s function index alone nothing (E7b). That is the VM's
  roadmap. This one hands it the measures, and the free part, the test of
  `CALL`'s function index alone (E7b's C-call), which may land at any
  time.

Function signatures with variables of rep, so that `CALLK` instantiates
them, would check the 99% of closures' functions whose register 0 is
typed. A refinement for later.

### D9. How the verifier gets its facts

**Decided: A** (2026-10-26), as recommended.

`RegVerify` needs each function's result rep, its captures' count and
reps, and each global's rep. E7's prototype derives them in a pass of its
own, which is half its cost.

- **A. From Lower, carried in `Code`, and in `.rbu` for cached units.**
  **Recommended.** One pass, about half the cost. Declared, not derived:
  a rep derived from a global's stores is only a lower bound. The
  prototype's alarms on `tests/basis` came from it, on branches that
  cannot run (E3). Cached code has no
  Lower, so its unit file carries the facts (`UnitFile.version` bumped,
  which the cache's configuration includes).
  The `.rbc` format is not changed: that is for the VM roadmap to decide.
- **B. Derived again, always.** No format change, twice the cost.
- **C. In the `.rbc` itself, for the VM's later verifier too.** Prejudges
  the VM roadmap.

### D10. Where the verifier's rules come from

**Decided: A** (2026-10-26), as recommended.

- **A. Generated tables, from `src/isa`; the dataflow written by hand.**
  **Recommended.** The rules are tables:
  - each operand's role and the rep it wants;
  - the implicit traffic of `PRIM`, `RESULT` and `CATCH`;
  - "followed by";
  - primitives' types as data;
  - the image primitives taken from `Isa.effect`.

  RegGen already derives `rop_dest` this way. E7's own three bugs were of
  the kind tables prevent. The later VM verifier can be generated from the
  same descriptions.
- **B. Written by hand,** as E7's prototype is. Quicker, and the rules
  drift from the instruction set's description.

### D11. Which code is verified

**Decided: A** (2026-10-26), as recommended.

- **A. The register code first; `RbcCheck` for the stack code, at level 2,
  once its quadratic part is found.** **Recommended.** The register code
  is the default VM's and the one tier 2 trusts. Nothing trusts the stack
  code's types, and `RbcCheck` found nothing in any corpus at 3.9-19.4% of a
  stack compile (E8). `check-levels` gains the register target, so that
  `Regs` and `Link` are compared at every level (E9).
- **B. Both, typed.** A typed check of the stack code needs a fixed point
  or frames, since its locals change rep. That buys little when nothing
  trusts it.

### D12. Where each check runs

**Decided: the placement table** (2026-10-26), as recommended.

| Place | Check | Level |
|---|---|---|
| after `finish` | AstLint | 2 |
| after `translate` | LambdaLint | 1 |
| after `mid` | MidLint | 1 |
| after `midcanon` | the renaming check | 1 |
| after each optional Mid pass | MidLint | 2 |
| inside `simplify`, per definition | MidLint | 2 |
| before `lower` | MidLint | 1 |
| after `lower` | LowLint with shapes; the invariant of `results` | 1; `results` at 0 |
| after `registers` | `RegVerify` | 0 or 1 (D13) |
| after `stack` | `RbcCheck` | 2 |
| a unit written | the code's round trip | 2 |
| a unit stored in the cache | its Mid linted, its code verified, the entry marked | as the compile's level |
| a unit taken from the cache | the entry's marks; its schemes against the exporting basis | 0 |
| the link | interfaces: arities, reps, globals | 0 |
| the next unit's passes | functor bodies decoded | 0 |
| `lib/cache` | built at level 2 | -- |
| `check-levels` | the register target, and true `--units` | -- |

### D13. Levels, and what is always on

**Decided: B** (2026-10-26), as recommended.

**The measures.**
- **Today's `--lint`** costs 16-148% of a compile, and 6-8% of
  `make check` (E1).
- **No IR lint as built is under the threshold:** the cheapest, MidLint
  before Lower, costs 4.6% of HaMLet, 13.1% of the bootstrap and 2.6% of
  MLton (E2).
- **With imperative MidLint tables and a linear LowLint,** the boundaries
  cost 13% of HaMLet and 27% of the bootstrap.
- **`RegVerify`** costs 1.5-9.4% of a fresh compile (E7). Once its facts
  come from Lower it should cost about half that (D9).

- **A. As today:** one switch, everything or nothing.
- **B. Four levels, and a threshold for level 0.** **Recommended.**
  - **The levels:**
    - 0, always on;
    - 1, the boundaries;
    - 2, every pass, which is today's `--lint` with the new places, and
      what the tests use;
    - 3, deep, for one tier.
  - **`--lint`** takes a level, and so does `RUNE_LINT`.
  - **A breach at a level below 2** is diagnosed by compiling again at 2.
  - **What may be on always**, measured in instructions:
    - at most 1% of the bootstrap at `-O1`, of HaMLet and of MLton, and at
      most 0.05 ms per REPL line;
    - all of level 0 together under 2% of the bootstrap;
    - no false alarm on `tests/lang`, `tests/basis`, the bootstrap,
      MLton or the corpora;
    - never a change to the output.
  - **What passes today:** the invariant of `results` and the functor
    bodies. `RegVerify` goes to level 0 if M8 brings it under the
    threshold, and stays at 1 otherwise.
  - **The editor and the REPL** may run level 1 by default: a REPL line's
    full lint is 0.18 ms (E1).
- **C. B with a looser threshold, 5%,** for a check of the output just
  before it is written. That is Erlang's practice (*What the
  implementations do*), and would put `RegVerify` on always once M8 halves
  its cost (9.4% of the bootstrap today). It costs every user's compile
  for bugs that every test compile already looks for.

### D14. Layouts across functions

**Decided: B** (2026-10-26), as recommended.

- **A. A datatype on Low's `Con`, `Field` and `Decon`,** checked against
  `Rep.fields`. Circular: Lower made both from the same `Rep`, and the
  comparison never disagreed (E7b).
- **B. Shapes per Low variable, and one number of fields per (stamp, tag)
  across the program**, with `Select`'s arity and tag tests' dominance.
  **Recommended.** It holds the producers of a layout to its consumers,
  which is what the review's second finding broke, and costs 0.5-4.6%.

### D15. The boundary of units

**Decided: A** (2026-10-26), as recommended.

- **A. Each unit verified once, when compiled; its cache entry marked;
  interfaces checked at the link.** **Recommended.**
  - **At the link:** each import's arity, parameter reps and result rep,
    and each unit's globals' reps. That is linear in the imports, against
    +22-42% for verifying every cached unit at every link (E7).
  - **From the cache:** a unit's imported schemes are checked against the
    exporting basis when the entry is taken.
  - **The frozen Basis** is built with lint (E9: all 768 entries clean and
    the same bytes).
- **B. The whole linked program verified at every link.** Simple and
  complete, and dearer than the compile of the changed unit it serves.

### D16. runespec

**Decided: A** (2026-10-26), as recommended.

- **A. AstLint independent of runespec, and runespec a third oracle in
  `check-spec` once merged.** **Recommended.** AstLint checks only what the
  elaborator accepted; runespec finds what it wrongly rejects. The
  `(conexp : ty)` program is the example: Rune and SML/NJ reject it, and
  HaMLet, MLton, Poly/ML, MLKit and runespec's reading of 4.7 accept it
  (E6).
- **B. AstLint generated from runespec** (D4 C).

### D17. What Mid's type variables mean

**Decided: A** (2026-10-26), as recommended.

E10 found Mid not well scoped in its type variables, by Lift and by ToMid
(*Found while writing this roadmap*). Nothing is miscompiled, because every
id is unique.

- **A. Mid is System F:** every type variable bound by an enclosing
  binder. Lift and ToMid are made to keep that, and MidLint gets an
  environment of type variables. **Recommended:** a substitution through
  Mid that is not well scoped can capture, and the middle end's passes
  substitute (inlining, specialisation, expansion).
- **B. Mid's generics are constants**, unique ids that need no binder.
  This is what the code does today. It makes MidLint's scope check
  impossible, and leaves every substitution's correctness to the ids'
  uniqueness.

### D18. Overloading's context, as an option

**Decided: A, default `declaration`** (2026-10-26), as recommended.

The owner's direction (2026-10-26): as `--flex-records` does for flexible
records, an option chooses the context that must resolve an overloaded
identifier or constant (Appendix E). Its modes are E13's four choices,
named as `--flex-records`' are where the context is the same:

| `--overloading=` | The context | Whose | Within Appendix E |
|---|---|---|---|
| `binding` | the innermost `val` or `fun` | HaMLet's | yes, below the bound |
| `declaration` | the smallest enclosing structure-level declaration | SML/NJ's and MLKit's | yes, the bound |
| `toplevel` | the declaration at top level: a whole structure, `local` or functor | Moscow ML's, and Rune's until now | no |
| `topdec` | the topdec: to `;` or the end of the file | MLton's and Poly/ML's | no |

- **A. Default `declaration`.** **Recommended.**
  - It is the most the Definition allows, and what SML/NJ and MLKit do.
  - It follows the owner's rule from the functors-units brief: the
    Definition by default, other compilers' leniency as an option.
  - It breaks what relies on more. M15 measures that on the compiler, the
    Basis, MLton's sources, the corpora and HOL4 before it changes the
    default. HOL4, built with Poly/ML, is the likeliest to need `topdec`.
- **B. Default `toplevel`, as today.** Nothing breaks, and Rune stays
  outside the Definition by default.
- **C. Default `topdec`,** as `--flex-records`' default is. The most
  lenient; MLton's and Poly/ML's programs compile unchanged. Furthest from
  the Definition.

There is no `program` mode: defaulting at the end of a program would make
a unit's types depend on the units compiled after it.

### D19. Free type variables at top level, as an option

**Decided: A, default `refuse`** (2026-10-26), as recommended.

The owner's direction (2026-10-26). Rules 87 and 89 forbid a free type
variable in the basis, and Appendix G.8 lets an implementation refuse the
program or replace the variables by monotypes. E13 found five behaviours,
along two axes: when the type must be determined, and what becomes of one
that is not. An option chooses one:

| `--free-tyvars=` | Determined by | If not | Whose | Within G.8 |
|---|---|---|---|---|
| `refuse` | the end of the topdec | an error | HaMLet's, and Rune's | yes |
| `monotype` | the end of the topdec | a warning, and a fresh monotype | Poly/ML's | yes |
| `dummy` | the end of each value declaration, at any depth | a warning, and a dummy type | SML/NJ's | no: it rejects valid programs |
| `later` | any later use in the program, or the unit | an error | MLKit's and Moscow ML's | arguably, the monotype chosen with hindsight |
| `later-monotype` | any later use in the program, or the unit | a warning, and a fresh monotype | MLton's | arguably |

- **A. Default `refuse`, as today.** **Recommended.** It is within G.8,
  and gives the error where the type was left open. `monotype` lets a
  `ref []` that nothing uses pass in silence, and a later use fail with a
  message about an invented type.
- **B. Default `monotype`.** Also within G.8; quieter, and its errors come
  later and further from their cause.

The option is separate from `--flex-records`, which today also fixes
where rules 87-89 are checked. A flexible record still open when the check
runs counts as a free type variable, unless its own context ends later. In
the REPL, which compiles each topdec at once, `later` and
`later-monotype` keep a variable open across inputs until a use fixes it,
as OCaml's weak type variables are. Or they are refused there; M15
decides by what it costs.

Both options join the cache's configuration, as `flex` does
(`unitcache.sml:108`). AstLint reads them as its configuration (D3), named
by runespec's readings `E.default`, `E.topdec` and `87.free`, with new
readings for the modes runespec does not have.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check`
green. One that touches the compiler's sources also passes the host builds
and `make check-cross`; one that touches units or the cache passes
`make test-incremental`; one that touches the register code passes
`make test-register-jit`.

No check may change the output, so every milestone that adds one also
shows the same bytes with it on and off. The sizes are lines of code and
tests.

The tracks are those of *Status*. M1 comes first; after it, I, B and A do
not wait for each other except where a milestone says so. M16 closes them
all.

### M1. The fixes found, and the guards that cost nothing (P; S, about 300)

* **What:**
  - **The value restriction takes `(conexp : ty) atexp`** (E6):
    `nonexpansive` accepts a constructor expression in parentheses with a
    type, nested or not, before an atomic argument. There is a test in
    `tests/lang` of the program E6 found, used at two types.
  - **`--mid-roundtrip` changes nothing** (E9): `MidText.parse` takes its
    stamps from a scratch counter and gives the elaborator's back. A test
    builds a program in units with and without the flag and compares the
    bytes. The rule it obeys holds for every check: none touches the
    compiler's counters, since one that did hid a seeded bug (E3).
  - **`--pass-stats` counts every check at every depth, per stage,** as
    E1's instrument does, so that a build in units shows its lint.
  - **`check-levels` compiles with both targets**, and adds a true
    `--units` build linked by `Link` (UL). The register target's builds
    run at `--jit=all --jit-tier=2 --checked` as well (E9). `Regs` and
    `Link` are then compared at every level, as nothing compared them.
  - **`lib/cache` is built with `--lint`** (`Makefile:461-463`; E9: all 768
    entries clean, the same bytes, +45-65% of `make basis-cache`).
  - **The invariant of `results`** in LowLint (0.1-0.6%, E9), with the
    inverse of `Lower.globalFids` it needs. It is always on.
  - **A test that checks never change the output:** `check-levels`
    compares each build with lint against one without.
* **Why first:** two bugs, and guards that cover what nothing covered, for
  almost nothing.
* **Done when:**
  - E6's program compiles and is polymorphic;
  - `--mid-roundtrip` leaves every unit's basis the same;
  - `check-levels` runs both targets and UL;
  - `lib/cache` is linted;
  - `make check` is green.
* **Touches:**
  - `lib/compiler/elab/elaborate.sml`;
  - `lib/compiler/core/midtext.sml`;
  - `lib/compiler/util/pass.sml`;
  - `lib/compiler/backend/lowlint.sml`;
  - `tests/lang`;
  - `tests/runner/oracles.sml`;
  - the `Makefile`;
  - `docs/testing.md`.

### M2. Lints that cost less, with the same rules (P; M, about 600)

* **What:**
  - **MidLint with imperative tables:** the binders, the globals and the
    functions of several parameters in hash tables, and the scope as one
    table entered and left during the walk. This is E2's `checkFast`.
  - **LowLint linear in a function's size.** Availability is checked by
    dominance over the blocks, not by filtering a map per block at every
    join.
  - **`midcanon` checked as a renaming** of its input, a bijection per
    kind of name, in place of linting its output again.
* **Why:** every level below today's, and every check this roadmap adds,
  pays for these two costs first (E1, E2). They are not type checks.
* **Done when:**
  - every rule and negative test of today is kept;
  - the corpora give no new alarm;
  - today's `--lint` costs at most about half what it costs now:
    - HaMLet at -O1, about 31% of the compile against 83%;
    - the bootstrap at -O1, about 62% against 148%.
* **Touches:** `lib/compiler/core/midlint.sml`,
  `lib/compiler/backend/lowlint.sml`, `lib/compiler/core/midcanon.sml`.

### M3. Levels (P; S, about 300; after M2)

* **What:** D13.
  - **`--lint=0|1|2|3`, and `RUNE_LINT` set to a level;** a bare
    `--lint` is 2.
  - **The levels:**
    - 0 is always on;
    - 1 is the boundaries;
    - 2 is every pass, which is what the tests use;
    - 3 adds the Mid round trip after every stage, and runs in one tier
      of `make check`.
  - **A breach below 2** says which boundary, then compiles again at 2 to
    say which pass.
  - **The REPL and the editor** compile at level 1.
  - **A check that is always on and fires** says it is the compiler's
    fault, and names the switch that turns it off (`--lint=off`).
* **Done when:**
  - the budgets that level 0 moves are re-based;
  - `make check` runs at 2, and its time does not grow from M2's;
  - `docs/testing.md` and the manual say what each level runs.
* **Touches:** `lib/compiler/util/pass.sml`, `src/driver/options.sml`,
  `src/repl/repl.sml`, `lib/compiler/api/analysis-engine.sml` (the
  editor's level), `bin/rune-test`'s maker in the `Makefile`,
  `tests/perf/*.budget`.

### M4. The missing rules of LambdaLint and MidLint, with a negative test for every rule (I; M, about 700)

* **What** (E10):
  - **`MkExn`'s payload** against the exception's argument, in Lambda and
    Mid, with the argument's type carried through copies: each copy's
    stamp registered with its substituted type, as `Ty.extrasOf` does for
    datatypes.
  - **A primitive's arguments and result** against its signature.
    - IsaGen generates `PrimTys`, the primitives' types as data, from
      `src/isa`'s strings with a real parser; all 414 parse.
    - `Prims.repsOf` comes from the same table, not from a split on `*`.
  - **A constant's kind and range.**
  - **A `Do`'s globals:** set on every path that returns.
  - **Casts by origin.** Open constructors and dynamic modules' slots get
    primitives of the compiler's own, as `functor_cast` is. Each is
    checked by its origin's rule, and the program's own `unsafe_cast` is
    left alone.
  - **A test-only hook,** `RUNE_FAULT=STAGE:KIND[@N]`, that corrupts the
    IR after a named stage. It gives each rule of each lint a negative
    test: a program, a stage, a kind of fault and the message expected.
    There are three such tests today, all for MidLint.
  - **E3's mutants of the compiler,** kept as a harness, beside
    `make test-mutants`. Its corpus gains a dynamic module and a functor of
    an earlier unit inlined, which E3's fast corpus lacked.
* **Done when:**
  - every rule has a negative test;
  - the corpora are clean;
  - E10's 34 faults are caught at the stage that made them.
* **Touches:** `lib/compiler/core/lambdalint.sml`, `core/midlint.sml`,
  `core/ty.sml`, `core/translate.sml` (the casts' primitives),
  `core/expand.sml` and `core/simplify.sml` (each copy's exception
  registered), `util/pass.sml` (`RUNE_FAULT`), `src/isa/isagen.sml`,
  `src/isa/prims.sml` (the compiler's own primitives),
  `lib/compiler/backend/prims.sml`, `tests/ir`, `tests/runner`.

### M5. Mid is System F (I; M, about 400)

* **What:** D17.
  - **Lift** gives a lifted function only the type variables its free
    variables' types name, minus those its inner schemes bind
    (`lift.sml:103-141, 235-241`). E10's program is a test.
  - **ToMid** binds every generic it leaves:
    - values that nothing generalises get their variables bound or made
      ground;
    - a functor body's function and its alias agree on their scheme;
    - patterns do not bind a variable twice.
  - **MidLint** gets an environment of type variables: a type may name
    only one in scope.
  - **LambdaLint** refuses an instance of a variable that an enclosing
    scope fixes.
* **Done when:** the rule is on and the corpora are clean at every level,
  MLton included.
* **Touches:** `lib/compiler/core/lift.sml`, `core/tomid.sml`,
  `core/midlint.sml`, `core/lambdalint.sml`.

### M6. Shapes and layouts in LowLint (I; M, about 400)

* **What:** D8 A and D14 B.
  - **`agree` directed:** `any` into a typed rep is a downcast, counted in
    `--pass-stats`, not an agreement.
  - **A shape per Low variable**, from the Mid type Lower records for it:
    `tuple(n)`, `data(stamp)`, closure, opaque, or immediate. A variable
    Lower shares between types on purpose (`defAny`) has none.
  - **What shapes check:**
    - `Select` within its arity;
    - `Field` and `Decon` on data;
    - one number of fields per (stamp, tag) across the program;
    - a tag test of the datatype dominating each `Field` and `Decon` of a
      datatype with more than one constructor.
* **Done when:**
  - the corpora are clean;
  - the cost stays within E7b's 0.5-4.6%;
  - the review's second finding, a constructor built boxed in one function
    and taken apart flat in another, is a negative test that fails here.
* **Touches:** `lib/compiler/backend/lowlint.sml`, `backend/lower.sml`, a
  new `backend/lowshapes.sml`, `lib/compiler/internal.build`.

### M7. The instruction sets described for checking (B; M, about 500)

* **What:** D10.
  - **What `src/isa`'s register instructions gain:**
    - each operand's role, read or write, and the rep it wants;
    - the implicit traffic of `PRIM`, `RESULT` and `CATCH`;
    - "followed by";
    - which primitives are image primitives, taken from `Isa.effect`, so
      that `Regs.imagePrims` is generated.
  - **RegGen** writes the tables into `regcodes.sml` beside what it writes
    today; the primitives' types come from M4's `PrimTys`.
  - The descriptions stay out of the instruction set's fingerprint, which
    keys the bytecode's encoding and must not change.
* **Done when:**
  - the tables are generated;
  - `make check-isa` passes;
  - the fingerprint is unchanged.
* **Touches:** `src/isa/regs.sml`, `src/isa/reggen.sml`,
  `src/isa/isagen.sml`, `lib/compiler/backend/regcodes.sml`,
  `lib/compiler/backend/regs.sml`.

### M8. A verifier of the register code (B; M, about 700; after M7)

* **What:** D8 A, D9 A.
  - **`RegVerify`** after `registers`, in one forward pass, under E7's
    rules, from M7's tables.
  - **Its facts come from Lower, in `Code`:** each function's result rep,
    its captures' count and reps, and the globals' reps.
  - **Its level** is D13's: 0 if it costs under the threshold, else 1.
  - **Negative tests:** E7's eleven corruptions, injected.
  - **Handed to the VM roadmap,** in `docs/plans` beside this one:
    - the reproducer of the segfault (E7: a `SWITCH` missing a jump);
    - E7b's measures of tier 2 trusting less;
    - the test of `CALL`'s function index alone (E7b's C-call), which
      costs nothing.
* **Done when:**
  - the corpora are clean, `tests/basis` included (E3 found the
    prototype's alarms there);
  - the cost is at most about half E7's (one pass);
  - the eleven corruptions are caught, and E3's mutants of `Regs` and
    `Link`.
* **Touches:** a new `lib/compiler/backend/regverify.sml`,
  `backend/code.sml`, `backend/lower.sml`, `backend/unitfile.sml` and
  `UnitFile.version` (the facts of cached units), `driver/pipeline.sml`,
  `lib/compiler/internal.build`.

### M9. Units and the link (B; M, about 500; after M8)

* **What:** D15 A.
  - **The interfaces.** Each import in `unitCode.imports` carries the
    arity, parameter reps and result rep the importer expects, and each
    unit the reps of its globals. Both link sites check these,
    linearly: `linkUnits` (`main.sml:996-1000`), which `linkUnitFiles`
    calls too, and `Session.writeProgram` (`api/session.sml:364-368`).
  - **The cache entry** records that its Mid was linted and its code
    verified, at what level.
  - **A unit taken from the cache** has its imported schemes checked
    against the exporting basis.
  - The versions are bumped (`UnitFile.version`, `UnitCache.version`,
    `UnitBasis.version`).
* **Done when:**
  - a warm build costs no more than a check of the interfaces;
  - a negative scenario in `tests/incremental`, a unit relinked against a
    changed import, fails at the link.
* **Touches:** `lib/compiler/backend/link.sml`, `backend/unitfile.sml`,
  `driver/unitcache.sml`, `driver/unitbasis.sml`, `src/driver/main.sml`,
  `lib/compiler/api/session.sml`, `tests/incremental`.

### M10. The stack code's check, in the compiler (B; S, about 150)

* **What:** D11 A. runeopt's `RbcCheck` runs after `stack` at level 2,
  with its quadratic part found and removed (E8: 12.6 s on MLton).
* **Done when:** MLton's stack code is checked in time linear in its
  size, and the corpora are clean.
* **Touches:** `src/opt/rbc.sml`, `src/opt/rbccheck.sml`,
  `driver/pipeline.sml`, `lib/compiler/internal.build` (with
  `src/isa/isa.sml`, `src/isa/stack.sml` and `src/opt/rbc.sml` brought into
  it).

### M11. Node ids, witnesses and `SourceTy` (A; L, about 1,200)

* **What:** D1 A, D2 A, D6 A.
  - **Ids:** an id on every node, in both parsers, fresh in
    `SyntaxAst.copy`.
  - **Spans:** on clauses, match rules, record labels and sequences of
    type variables.
  - **The witness tables** of *The architecture*, by node id, dropped by
    ranges, among them:
    - each binding's generalised variables, recorded at the binding;
    - the defaults chosen;
    - each declaration's status.
  - **`SourceTy`,** zonked after `finish` under a budget of steps, only
    when something reads it.
  - **One printer** over `SourceTy`.
* **Done when:**
  - Mid is byte for byte the same on every corpus;
  - the budgets `compile-hello`, `compile-sigs` and the bootstrap's move
    by at most 1% (the zonk is not on by default);
  - the editor's tests pass.
* **Touches:** `lib/compiler/frontend/ast.sml`, `frontend/parser.sml`,
  `syntax/parser.sml`, `syntax/ast.sml`, `elab/elaborate.sml`, new
  `elab/sourcety.sml` and `elab/witness.sml`, `driver/unitbasis.sml` (the
  tables dropped with a unit), `lib/compiler/internal.build`, and the
  constructors' matches throughout (about 350 in 19 files).

### M12. AstLint of the Core (A; L, about 1,300 with tests; after M11)

* **What:** D3 A, D4 A, D5 B.
  - **AstLint** after `finish`, at level 2, with the module language's
    results as axioms.
  - **Its rules** carry the Definition's numbers, and Rune's deviations
    runespec's reading names.
  - **Negative tests** are elaborator mutants that accept an ill-typed
    program, kept with E3's harness: E6's five, and E3's seven that nothing
    else catches.
  - **The escape of a local datatype through an enclosing function's
    variable** is checked, which E6's prototype missed (E3).
* **Done when:**
  - no alarm on any corpus, MLton and HOL4 included;
  - every mutant of the harness is caught;
  - the cost is recorded at each level.
* **Touches:** a new `lib/compiler/elab/astlint.sml`, `src/driver/main.sml`,
  `lib/compiler/driver/pipeline.sml`, `lib/compiler/internal.build`,
  `tests/runner`.

### Gate G1: how AstLint goes on (the owner's)

After M12, the owner decides two things from what AstLint cost and found:
- whether the module language is checked as M13 plans, or stays axioms;
- whether AstLint stays at level 2 or moves to 1.

### M13. AstLint of the module language (A; L, about 1,000; after G1)

* **What:** D5 B's second step (D5 A's records).
  - **The elaborator records** the fresh names the module language chose:
    - the bound names of each signature expression (rule 65's `T`) and the
      representatives of sharing classes (rule 78's `t`);
    - the fresh names at opaque ascriptions (rule 53's `T'`);
    - the fresh names at applications (rule 54's `T'`);
    - each functor body's range of stamps;
    - dynamic modules' names.

    Its records keep schemes, not stamps.
  - **AstLint** finds φ by paths, checks enrichment by one-way matching,
    and discharges the axioms. Imported unit bases stay axioms.
* **Done when:** the axioms other than imported bases are gone, and the
  corpora are clean.
* **Touches:** `elab/sigmatch.sml`, `elab/elaborate.sml`, `elab/astlint.sml`.

### M14. The editor's types (A; M, about 500; after M11, with M12's synthesis)

* **What:** D7 A.
  - **Hover at every node,** each declaration's types worked out from the
    witnesses when first asked, and kept.
  - **An index** from positions to nodes.
  - **The application preferred** over its infix tuple.
  - **One printer per unit.**
  - **A binder's type,** with only its own quantified variables marked.
* **Done when:**
  - hover answers at every node of E12's sample;
  - the largest declaration answers within a quarter of a second;
  - `tests/lsp` passes.
* **Touches:** `lib/compiler/api/facts.sml`, `api/analysis.sml`,
  `api/analysis-engine.sml`, `src/lsp/worker-analysis.sml`.

### M15. Overloading's context and free type variables, as options (A; M, about 400)

* **What:** D18 and D19, the owner's direction.
  - **`--overloading=binding|declaration|toplevel|topdec`.** The elaborator
    resolves and defaults the open overloaded variables at the end of the
    chosen context; `toplevel` is what `resolvePending` does today.
  - **`--free-tyvars=refuse|monotype|dummy|later|later-monotype`.** The
    check of rules 87-89 is moved out of `--flex-records`' context, which
    then decides only flexible records.
  - **Wiring:** both go into the cache's configuration, the REPL's and the
    compiler library's settings, the help, the man page and
    `docs/language.md`. Under the defaults the *Deviations* row
    *Overloading* is no longer a deviation.
  - **A suite in the manner of `tests/flexrec`:** E13's programs under
    every mode of each, each held to what the implementation it follows
    did with them.
  - **First, before any default changes:** the compiler, the Basis,
    MLton's 606 files, the `rune-corpus-sml97` packages and HOL4 compiled
    under `--overloading=declaration`, counting what breaks. The default
    moves when the owner accepts the count; a corpus that needs more
    names its mode in its build.
* **Done when:**
  - Rune reproduces E13's tables, mode by mode;
  - every corpus compiles under the defaults or under the mode its build
    names;
  - `make check` is green.
* **Touches:** `lib/compiler/elab/elaborate.sml`, `src/driver/options.sml`,
  `lib/compiler/driver/unitcache.sml`, `src/repl/repl.sml`,
  `lib/compiler/api/session.sml`, `docs/language.md`, the man page, a new
  `tests/overloading` beside `tests/flexrec`.

### M16. Retire (S)

* **What:**
  - the final measurements: E1 and E2 again, on the merged tree;
  - **docs:**
    - `docs/ir.md`, the lints' rows and "none yet";
    - `docs/testing.md`, the levels;
    - `docs/architecture.md`;
    - `type-checker.md`, its open case answered;
    - `language-server.md`, the types;
    - `errror-messages.md`, what this roadmap lays for it;
  - *At the close*, as earlier roadmaps did.

### Later

Not this roadmap's:
- **The VM's verifier,** for untrusted code: tier 2 trusting less (D8 C),
  or a verifier with types, sound by design, with E7b's measures.
- **Function signatures with variables of rep,** to check `CALL` through
  closures (D8).
- **The error-message roadmap:** errors as data, recovery with an error
  type, more than one error per declaration (D6 B).
- **runespec as a third oracle** once it is merged (D16), and AstLint
  checked against its rules (D4 B, C).
- **Checking policy:** defaults and the `--flex-records` mode against
  records of them (D3 B).
- **Meaning.** A generator of programs in general, beyond the functor
  generator, run every way, for the bugs no type check sees (*What the
  literature says*).

### Why this order

- **M1 first:** it fixes two bugs and adds guards for almost nothing.
- **M2 before M3,** because levels are worth having only once the lints
  they choose between are not dominated by two costs of their tables
  (E2).
- **B in order M7, M8, M9,** because the verifier's rules are generated
  before it is written (D10), and the link's interfaces need the
  verifier's facts.
- **A in order M11, M12, G1, M13,** because AstLint needs the witnesses,
  and the module language needs what the Core showed. M14 can follow
  M11 at once, with M12's synthesis when it lands.
- **M15 independent:** it changes typing, not checks, and is best before
  M12, whose AstLint takes its modes as configuration.
- **I independent:** M4, M5 and M6 touch the lints alone. M5's Lift fix
  and M4's casts change the compiler's output and are tested as such.

## Prerequisites and flags

- **The premise:** functors-units, its own M8 and M9 included, merged into
  master before this roadmap's M1 starts. Line numbers here are of `d551f19dd` and are checked
  again on the merged tree before each milestone.
- **Flags this roadmap adds or changes:**
  - **`--lint=LEVEL`** (0 to 3), with `RUNE_LINT=LEVEL` and `--lint=off`
    (M3);
  - **`RUNE_FAULT=STAGE:KIND[@N]`**, for the tests only (M4);
  - **`--pass-stats`** gains a line per check (M1);
  - **`--overloading=MODE`** and **`--free-tyvars=MODE`** (M15, D18, D19).
- **No new switch for AstLint or `RegVerify`:** their levels place them.
- **Files whose formats change:**
  - the unit file (`.rbu`), with the verifier's facts (M8) and the
    interfaces (M9);
  - the cache entry, with its marks (M9).

  The `.rbc` and the image do not change (D9).
- **What the owner decides:** the owner took D1 to D19 as recommended
  (2026-10-26). What stays the owner's:
  - whether the default of `--overloading` moves, once M15 has counted
    what it breaks;
  - gate G1, after M12;
  - whether the test of `CALL`'s function index (E7b's C-call) lands in
    the VM now or with the VM roadmap (D8).

## Relation to the other plans

- **functors-units.md.** This roadmap starts where it ends.
  - Functors compiled once mean no copy is elaborated again, so
    `lintSummaries` had nothing left to check.
  - Its expansion (`expand`) is where the history's most recent bugs were
    (E4).
  - Its generator of functor programs is one of the oracles of *What a
    type checker cannot find*.
- **build-cache-issues.md.** M9's interfaces make a unit linked against an
  import whose arity or reps changed fail at the link. Issues 21 to 23,
  links to the wrong load of a unit with the same interface, are the
  identities' and are not caught by it.
- **type-checker.md** left open whether `exception E of 'a` inside a
  function would raise the question its datatypes raised. E10 found that
  nothing checks it after the first copy. M4 makes it checked, and the
  question is answered there.
- **errror-messages.md** (three lines: recovery, errors as data, runedoc).
  This roadmap lays its groundwork (D6): ids as anchors, spans on clauses
  and rules, one printer, a declaration's status. It leaves recovery and
  errors as data to that roadmap.
- **specification.md (runespec).**
  - It is not merged. AstLint is independent of it (D16).
  - Merged, it finds the programs Rune wrongly rejects, as E6's was.
  - Its readings name AstLint's deviations, and its rules are AstLint's
    written specification (D4 B).
- **formal-verification.md** asks for the lexer and parser, and the type
  checker, generated from a specification. AstLint is a hand-written
  checker of the elaborator; a generated one is that plan's.
- **language-server.md and ide.md.** M14 gives hover a type at every node,
  and an index for `typeAt`. It changes no protocol.
- **quickcheck.md and quickcheck-hunt.md** built `tools/mutate` and
  `make test-mutants`, which E3 extended to the compiler. M4 keeps that
  harness.
- **middle-end.md** made Mid typed in the manner of System F (its D3).
  D17 holds Mid to that.
- **docs/language.md's *Deviations*: Overloading and Flexible records.**
  M15 rewrites the first, which under D18's default is no longer a
  deviation. It moves the check of rules 87-89 out of the second, and adds
  rows for the two options. `tests/flexrec` is the model for M15's suite.
- **A future roadmap: the VM's verifier.** It gets E7b's measures and the
  test of `CALL`'s function index (E7b's C-call, D8), E7's reproducer, and the tables M7 generates from `src/isa`. Its
  verifier must be sound by design (*What the literature says*).

## Risks

1. **False alarms in a user's compile.** A check at level 0 that is wrong
   stops a correct program. Level 0 admits only checks that are clean on
   every corpus, and `--lint=off` turns them off (D13, M3).
2. **The elaborator's records change what it does.** Recording witnesses
   at the right moment (generalisation, E6) touches the elaborator's
   hottest code. M11's gate: Mid the same bytes everywhere, and the
   budgets.
3. **AstLint's own bugs.** E6's prototype had five kinds of false alarm
   before it was clean. Each is now a rule. MLton's and HOL4's sources are
   run before the check goes into every test compile (M12).
4. **The cost of `make check`.** Level 2 adds checks: AstLint, `RbcCheck`,
   MidLint inside `simplify` per definition. M2's savings come first, so that `make check` ends
   no slower than today's.
5. **Mid made System F is a change to two passes** (Lift, ToMid) whose
   outputs every later pass reads. M5 compares outputs, as any change of
   the compiler is compared.
6. **The descriptions in `src/isa` drift from the VM's C.** The VM's
   implicit traffic is described in comments today. M7 makes it data beside
   the interpreter's C bodies, which `src/isa` already holds and
   `check-isa` holds the generated files to. The JIT's hand-written C is
   held to it only by the tests (`make test-register-jit`).
7. **The witnesses outgrow 8%.** On a corpus unlike these, more nodes may
   need one. The tables are by id, so the cost is measured, not guessed
   (M11's budgets).
8. **A default that changes what compiles.** `--overloading=declaration`
   rejects a structure or `local` that today resolves overloading across
   its declarations, which MLton and Poly/ML accept as well. M15 counts the
   breakage on every corpus first, and the owner decides whether the
   default moves.

## Testing

- **Negative tests for every rule of every check**, through the
  fault-injection hook (M4) and `RegVerify`'s injection (M8). There are
  three today.
- **The mutants of the compiler** (E3) as a harness, with the
  elaborator's mutants (E6) for AstLint (M4, M12).
- **Checks never change the output:** every build compared with and
  without lint (M1), and AstLint's and `RegVerify`'s identity runs.
- **`check-levels` on both targets and UL** (M1).
- **`lib/cache` built with lint** (M1).
- **Meaning**, which no lint finds, stays with the comparisons of *Where
  we are*; *Later* names a generator of programs in general.

## Measuring

- **Instruments:** E1's per check, kept as `--pass-stats` (M1). Every
  milestone that adds or changes a check reports its cost in instructions
  on:
  - a REPL line;
  - one changed unit on a warm cache;
  - a small program;
  - HaMLet;
  - the bootstrap;
  - MLton.
- **D13's threshold** decides level 0.
- **The budgets** (`tests/perf`) count the compiler as shipped, so a check
  at level 0 shows there and is re-based in the milestone that adds it.

## References

The papers E11 read:

- Bour, Refis, Scherer. Merlin: a language server for OCaml (experience report). PACMPL 2 (ICFP), 2018. doi:10.1145/3236798
- Chen et al. A survey of compiler testing. CSUR 53(1), 2020. doi:10.1145/3363562
- DeMillo, Lipton, Sayward. Hints on test data selection. Computer 11(4), 1978. doi:10.1109/C-M.1978.218136
- Haas et al. Bringing the web up to speed with WebAssembly. PLDI 2017, doi:10.1145/3062341.3062363
- Kahrs. Mistakes and ambiguities in the Definition of Standard ML. LFCS report, Edinburgh, 1993 (no DOI)
- Klein, Nipkow. Verified bytecode verifiers. TCS 298(3), 2003. doi:10.1016/S0304-3975(02)00869-1
- Le, Afshari, Su. Compiler validation via equivalence modulo inputs. PLDI 2014. doi:10.1145/2594291.2594334
- Leroy. Bytecode verification on Java smart cards. SPE 32(4), 2002. doi:10.1002/spe.438
- Leroy. Java bytecode verification: algorithms and formalizations. JAR 30(3-4), 2003. doi:10.1023/A:1025055424017
- Milner, Tofte, Harper, MacQueen. The Definition of Standard ML (Revised). MIT Press, 1997. doi:10.7551/mitpress/2319.001.0001
- Minamide, Morrisett, Harper. Typed closure conversion. POPL 1996. doi:10.1145/237721.237791
- Morrisett, Walker, Crary, Glew. From System F to typed assembly language. TOPLAS 21(3), 1999. doi:10.1145/319301.319345
- Necula. Proof-carrying code. POPL 1997. doi:10.1145/263699.263712
- Necula. Translation validation for an optimizing compiler. PLDI 2000. doi:10.1145/349299.349314
- Peyton Jones. Compiling Haskell by program transformation: a report from the trenches. ESOP 1996, LNCS 1058. doi:10.1007/3-540-61055-3_27
- Pnueli, Siegel, Singerman. Translation validation. TACAS 1998, LNCS 1384. doi:10.1007/BFb0054170
- Rideau, Leroy. Validating register allocation and spilling. CC 2010. doi:10.1007/978-3-642-11970-5_13
- Rose. Lightweight bytecode verification. JAR 31(3-4), 2003. doi:10.1023/B:JARS.0000021015.15794.82
- Rossberg. Defects in the Revised Definition of Standard ML. 2013 (people.mpi-sws.org/~rossberg/papers/sml-defects-2013-09-18.pdf; no DOI)
- Shao, League, Monnier. Implementing typed intermediate languages. ICFP 1998. doi:10.1145/289423.289460
- Sulzmann, Chakravarty, Peyton Jones, Donnelly. System F with type equality coercions. TLDI 2007. doi:10.1145/1190315.1190324
- Sun, Le, Su. Finding compiler bugs via live code mutation. OOPSLA 2016. doi:10.1145/2983990.2984038
- Tarditi, Morrisett, Cheng, Stone, Harper, Lee. TIL: a type-directed optimizing compiler for ML. PLDI 1996. doi:10.1145/231379.231414
- Tristan, Leroy. Formal verification of translation validators. POPL 2008. doi:10.1145/1328438.1328444
- Yang, Chen, Eide, Regehr. Finding and understanding bugs in C compilers. PLDI 2011. doi:10.1145/1993498.1993532

**Specifications and others:**
- the Lua 5.4 reference manual, §6.1, and lua-l, October 2011 (msg01216);
- ECMA-335, 6th edition (2012), Partition III;
- JSR 202 (final release 2006) and the JVM specification SE 21, §4.10;
- the WebAssembly core specification, appendix "Validation Algorithm".

**Sources** under `/home/ruud/reference`, cited in place: GHC, HotSpot,
MLton, MLKit, SML/NJ, Poly/ML, OCaml, Erlang/OTP, wasmtime and Cranelift,
rustc and rust-analyzer, Swift, Go, Julia, Dart, Koka, Manticore, Roslyn
and F#. Also HaMLet 2.0.1, at
`/home/ruud/rune-corpus-sml97/_work/research/hamlet-2.0.1`.

## Appendix: what each check costs, against what it catches

The costs are instructions as a share of a compile at `-O1` without lint
(E1, E2, E5, E7, E7b, E8, E9). The catches are E3's seeded bugs and E4's
history of real ones.

| Check | HaMLet | the bootstrap | Seeded bugs it catches (E3) | Real bugs of its class (E4) |
|---|---:|---:|---|---|
| LambdaLint | 5.8% | 8.3% | Translate's, all of them, alone | none in the history |
| MidLint after every pass, today's tables | 58% | 119% | type substitutions dropped in `inline`, `specialise`, `lift`, `expand`; a `Do` list dropping a global | 15 of 15 that today's lint would catch (with Lower's) |
| MidLint after every pass, imperative tables (M2) | about 22% | about 45% | the same | the same |
| LowLint, today | 18.8% | 20.0% | Lower's reps | results' reps |
| LowLint, linear (M2, projected) | 2.6% | 8.2% | the same | the same |
| the boundaries only, after M2 | 12.9% | 27.2% | 23 of the 24 that lint caught, on fewer programs and further from the bug | |
| the invariant of `results` | 0.16% | 0.6% | | -- |
| AstLint of the Core (prototype; of E5's whole compiles) | about 25% | about 27% | all seven elaborator mutants nothing else caught | the elaborator's seven: two in the Core, three with modules |
| `RegVerify` (prototype, two passes) | 3.3% | 9.4% | arity, reps in `meta`, registers shared across reps, tag tests swapped, linked programs | |
| shapes in LowLint (prototype) | 1.8% | 4.6% | tags swapped | layouts across functions (two) |
| `RbcCheck`, of a stack compile | 9.0% | 19.4% | not run | none |
| `midcanon`'s renaming, in place of its lint | 2.3% | 4.5% | not run (it guarantees what its lint does, given MidLint after `mid`, E2) | |
| the Mid round trip after every stage | about 8 times the compile | | (it hid one, E3) | |

What nothing catches but comparison:
- well-typed folds, effects dropped, `refs`, aliases;
- layouts lost in `midcanon`;
- positions;
- the cache's fourteen bugs.

The comparisons that find them are -O0 against -O2, the VM's own checks,
the bootstrap reproducing itself, outputs, and the cache's scenarios
(E3, E4).

The rows of mutants and bugs are in the drafts:
`results/E3/mutants.tsv` (68 mutants) and `results/E4/bugs.tsv` (65 bugs).
