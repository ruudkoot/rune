# Functors: how Rune types and compiles them

What was learned about functors while writing the performance roadmap
([performance.md](performance.md), D3 and M3), on 2026-10-11 and 12,
against master `921af2cc`. It covers:

* what the Definition says;
* what Rune does, and where that departs from the Definition;
* what it costs, in a whole compile and in the cache of units;
* what the other implementations and the literature do;
* the options.

**Decided (owner, 2026-10-12):** A, extended, now, as part of
performance.md's M3. B is to be revisited later; this file is where that
starts.

## What the Definition says

The rules below are cited from their transcription on branch `runespec`
(`spec/sml97/modules.rs`).

* **A functor's signature** is `(T)(E, (T')E')`:
  * `T` binds the parameter's type names in `E`, the parameter's
    environment, and in the result `(T')E'`;
  * `T'` binds the type names the body generates.
* **A functor declaration** (rule 86) elaborates the body once, against
  the parameter signature. The parameter's names act as constants in the
  body. The result is the functor's signature.
* **A functor application** (rule 54) never looks at the body again. It
  instantiates the functor's signature (§5.4) so that the argument
  enriches the parameter's instance. The result's names `T'` are renamed
  apart, so each application generates new datatypes. Nothing about the
  argument beyond what the parameter signature promises reaches the
  result, except through the realisation of `T`.
* **At run time** (rule 154) a functor is a closure. Each application
  evaluates the body again, in the closure's basis, with the argument cut
  down to the parameter's interface. So each application makes new
  exceptions and new `ref`s.

Two things follow:

* Whether an implementation compiles a functor once (a function) or once
  per application (a copy) is its own choice. Both implement rule 154.
* Typing by rule 54 is not a choice. One consequence: a datatype declared
  in a functor body gets its equality at the declaration, from the
  parameter as specified, not from the argument it is later applied to.

**A test.** Two programs, kept with the drafts (`results/D3/`):

```sml
functor F (type t) = struct datatype d = D of t end
structure S = F (type t = int)
val b = S.D 1 = S.D 1
```

By rule 54, `S.d` does not admit equality: `t` is a plain `type` in the
parameter, so `d` was fixed as a type without equality at the declaration.
Line 3 is a type error.

```sml
functor G () = struct exception E end
structure A = G ()
structure B = G ()
val r = (raise A.E) handle B.E => "one exception" | A.E => "two distinct exceptions"
```

By rule 154, `A.E` and `B.E` are distinct.

| Implementation | Equality program | Exceptions program |
|---|---|---|
| HaMLet 2.0.1 | rejected | two distinct exceptions |
| SML/NJ 110.99.9 | rejected | two distinct exceptions |
| Poly/ML 5.9.2 | rejected | two distinct exceptions |
| Moscow ML 2.10.1 | rejected | two distinct exceptions |
| MLKit 4.7.23 | rejected | two distinct exceptions |
| MLton 20241230 | **accepted** | two distinct exceptions |
| Rune `921af2cc` | **accepted** | two distinct exceptions |

So Rune, like MLton, accepts a program the Definition rejects.
[docs/language.md](../language.md) does not list this among its deviations,
and its row `mod.functor` cites rule 54.

## What Rune does today

**A declaration** (`src/elab/elaborate.sml:1006-1028`):

* The body is elaborated once against the parameter signature: rule 86's
  check, with its errors.
* Its annotations are then thrown away.
* `FunInfo` (`elaborate.sml:16-19`) keeps:
  * the body as syntax;
  * the environment of the declaration;
  * the signatures and functors in scope then.

**An application** (`elaborate.sml:1050-1075`):

* The argument is elaborated and matched against the parameter signature,
  transparently (`SigMatch.ascribe`, line 1059).
* The body is copied with fresh annotation slots (`Ast.copyStrexp`,
  `src/frontend/ast.sml:241-307`).
* The copy is elaborated in the declaration's environment, with the
  matched argument bound to the parameter, and kept in the application's
  slot.
* Translate compiles that copy where the application is
  (`src/core/translate.sml:533-542`). There are no functors at run time.

This is static interpretation, as in MLton and MLKit. The result of an
application is typed from the copy, and the copy sees the actual argument:
here, that `t` is `int`, so `d` admits equality. That is the deviation
above.

**Nested applications are elaborated again and again.** An application
inside a functor body is elaborated:

* when that functor's declaration is checked;
* again inside every copy of that functor's body.

So a body nested d deep is elaborated about d + 2 times. With two
applications in each body, that doubles with each level of nesting (E19,
below).

**In units and the cache** ([units.md](../units.md)):

* **The export basis holds no body.** A unit that declares a functor
  exports its parameter signature and the environment it was declared in,
  but not its body: "A functor's body is not written: where it is in the
  unit's source is" (`units.md:69`). Loading the basis parses the source
  again for it, checked by hash.
* **Each application re-elaborates the body.** A unit that applies a
  functor elaborates the body again, "in the basis of its declaration, as
  it was parsed there" (`units.md:240`), and the copy's code is in that
  unit.
* **The dependency is coarse.** A use of a functor is matched by its
  binder alone, not by a fingerprint (`units.md:275`). Every unit that
  applies a functor is compiled again when the declaring unit's basis
  changes, even where the change is elsewhere in that unit. Such a change
  is:
  * a change to the body (its hash is in the basis);
  * or a change in what the body's free names are bound to, units before
    (S49 to S51 of `tests/incremental/SCENARIOS.md`).

  [units.md](../units.md) calls this "the cost is precision, not
  correctness".
* **The applying unit's basis is typed from the copy.** So a change to a
  body can change the bases of the units that apply it beyond what the
  functor's signature says, and so recompile the units after them as
  well.
* **The incremental plan already saw this:**
  * [incremental-compilation.md](incremental-compilation.md) lists it as
    risk 3: "functor bodies in the basis are large and change often", with
    HOL4's functorised kernel as the case to measure.
  * Its *Ready for, not built* has "SC against a functor signature", which
    "needs run-time functors or a link-time expansion".
  * Its D1 keeps static interpretation "for now to keep strict SML'97
    semantics". As above, the Definition requires typing by the functor's
    signature, which today's copies do not keep. It does not require
    static interpretation.

## What it costs

From the performance roadmap's experiments (performance.md, *Track A*).
Seconds are of MLton's build of Rune, which is 4 to 5 times faster than
Rune at tier 2.

**MLton's 606 files, one unit each, type-checked** (E18; 151.3 s of
elaboration, measured per top-level declaration):

| Where | Seconds | Share |
|---|---:|---:|
| sharing in signatures (performance.md's M2) | 83.7 | 55.3% |
| copies of functor bodies made only to check a declaration | 32.4 | 21.4% |
| copies made to compile code | 22.8 | 15.0% |
| matching at declarations | 8.7 | 5.7% |
| the rest | about 4 | |

* **Matching accounts for much of the copies' time.** Inside them,
  matching the argument against the parameter takes 25.8 s in check-only
  copies and 21.3 s in code-producing ones; matching in all is 37% of
  elaboration.
* **The applications:** 359 make code and 1,204 are made only to check,
  nested up to 9 deep.
* **The worst files:**
  * `main.sml`, 22.7 s: 301 applications that make code, 21.3 s of it
    matching;
  * `main.fun`, 10.1 s, and `compile.fun`, 9.4 s: about 300 check-only
    applications each.

**Generated programs** (E19; the least of three runs):

| Program | Rune | Others |
|---|---|---|
| a functor of 40 declarations applied A times | linear: 0.13 s at A = 320 | Poly/ML out of store from 40 × 80; MLKit 73 s |
| nested functors, one application in each body, depth D | quadratic: 0.94 s at D = 128 | Poly/ML 65 s at D = 32; Moscow ML 11 s at D = 64 |
| nested functors, two applications in each body | doubles with each level: 2.86 s at D = 12 | MLton doubles too, 21.7 s at D = 12; SML/NJ 1.2 s; Poly/ML, Moscow ML and MLKit time out |
| a functor with a parameter of S specs, applied 40 times | 0.45 s at S = 800 | Moscow ML 115 s |

SML/NJ, which never elaborates a body again, is the only one that does not
blow up on nested functors.

**After elaboration:**

* **MidCanon is quadratic** in the number of datatypes. Functors multiply
  datatypes, so nested functors of depth 10 took 20.3 s; a fix of 20 lines
  takes them to 0.88 s (E24, performance.md's M3).
* **The back end** compiles every copy, about 10 s of Rune's compile of
  MLton at tier 2.
* **Memory.** The live data of MLton's compile grows in its functor-heavy
  files: past 2.5 GB in `main.sml` (E22). Not keeping each declaration's
  check alive changed nothing measurable, and what holds the memory is
  not yet known.

**The prototype of summaries** (E21; patch `A-e21-functor-summary` with the
drafts). An application inside a functor declaration's check takes the
applied functor's result: realised by the argument's match, with fresh
names for the datatypes its body makes. That is MLton's `functorClosure`.

* **Results:**
  * −19.5% of MLton's elaboration instructions;
  * `main.fun` from 9.2 s to 0.01 s, `rssa-simplify.fun` from 2.8 s to
    0.5 s;
  * with sharing (M2) and MidCanon's fix as well, −80% in all, about the
    time MLton takes to type-check its own sources.
* **The whole program's output** for MLton's first 219 and 420 files is
  identical.
* **The bytes of 645 of 1,582 unit files differ.** At first this was put
  down to fewer fresh names, so that the counters and datatype entries
  written into the files move. Building M3 showed it is more than that:
  *A contradiction in M3, found while building it*, below.

## What the others do

| | Typing an application | Code |
|---|---|---|
| SML/NJ | evaluates an entity expression, or instantiates the body's signature: never elaborates the body again (`Elaborator/elaborate/elabmod.sml:946,1147-1166`, `modules/evalent.sml:250-287`); sharing by Paterson and Wegman's unification (`modules/instantiate.sml`) | a functor is a closure at run time, compiled once (`modules/sigmatch.sml:1159-1200`) |
| Poly/ML | from the functor's result signature (`mlsource/MLCompiler/STRUCTURES_.ML:1442-1483`) | compiled once into a function, inlined at each application by default (`inlineFunctors`, `Debug.ML:45,99`) |
| MLKit | by matching against the functor's signature (`Common/EfficientElab/ElabTopdec.sml:397-425`) | static interpretation: the body parsed and elaborated again for each application's code (`Manager/IntModules.sml`) |
| MLton | the body elaborated once against a dummy argument; an application inside a functor body uses that summary; one that makes code elaborates the body again (`elaborate/elaborate-env.fun:4547-4720`, `functorClosure`) | static interpretation; the whole program then monomorphised |
| Rune today | the elaborated copy | static interpretation |

**MLKit's design is extended A.** It types by the functor's signature, as
the Definition does, and compiles a copy per application, as MLton does.
That is why MLKit rejects the equality program and MLton accepts it.

## What the literature says

* **MacQueen and Tofte** (ESOP 1994) gave higher-order functors a semantics
  that elaborates a functor's body again at each application. This is how
  Rossberg, Russo and Dreyer (JFP 2014) describe it; only the record of the
  1994 paper was read.
* **Kuan and MacQueen** (IFL 2009) describe SML/NJ's entity calculus, which
  replaced that re-elaboration.
* **Elsman, "Static interpretation of modules"** (ICFP 1999), describes
  MLKit:
  * a functor is type-checked once and its code generated per
    application;
  * on MLKit itself (about 87,000 lines), 6 of 138 functors were applied
    more than once, and the code grew by 10.9%.

  Elsman, Henriksen, Annenkov and Oancea (ICFP 2018) do the same for
  Futhark's higher-order modules.
* **Rossberg, Russo and Dreyer, "F-ing modules"** (JFP 2014):
  * modules translated into System F-omega;
  * a functor becomes a function polymorphic in its parameter's types, and
    an application one matching plus a substitution.

  It is the recipe for B.
* **Appel and MacQueen, "Separate compilation for Standard ML"** (PLDI
  1994): "the problem is particularly severe for ML because of its functor
  facility", since depending on a functor is depending on an
  implementation. Quoted from incremental-compilation.md.
* **Swasey, Murphy, Crary and Harper** (ML 2006): separate compilation
  against signatures, functor specifications included (SMLSC).

## The options

### A, extended: decided, in performance.md's M3

Static interpretation for code, and the functor's signature for types.

* **Every application typed from the functor's signature.** It is
  computed by the declaration's check, which Rune already makes. The
  parameter is matched and the generated datatypes are renamed apart: rule
  54 and E21's summary, for every application, including those that make
  code.
* **A copy of the body elaborated only for the code of an application
  that makes code.** It is safe because the body was checked against the
  abstract parameter at its declaration. Only what the copy showed to the
  rest of the program was wrong, and that now comes from the signature.
* **In units:**
  * the functor's signature in the export basis;
  * a use of a functor depending on the signature's fingerprint for
    types, and on the body's hash for code. An applying unit's basis is
    then the same as long as the functor's signature is, so the cut-off
    after it holds.
  * the counters replayed, and M3 gated as *A contradiction in M3* below
    says. Its first wording, unit files byte for byte the same as before,
    cannot hold.
* **Matching made cheaper**: the fast path for equal schemes, a cheaper
  `checkEnrich` and `mergeInfo`. It is most of `main.sml`'s cost.
* **The equality program rejected**, with a test, and docs/language.md's
  row made true.
* **Checked before it lands:** MLton's sources, HOL4, the Basis libraries
  of xc2 and every suite still compile. MLton accepts the leak, so code
  written for it may rely on it.

What A does not change: a change to a functor's body still recompiles every
unit that applies it, since each has a copy of the body's code. Elaborating
the copies that make code also stays: 15% of MLton's elaboration, plus the
back end's work on each copy.

### A contradiction in M3, found while building it

performance.md's M3, and this file's *A, extended*, asked for two things
that cannot both hold:

* the functor's signature added to the export basis;
* unit files kept byte for byte the same as before M3, by replaying the
  counters.

The front-end agent found it on 2026-10-12, while implementing M3, by
looking at why E21's 645 unit files differed.

* **The counters were the smaller part.** 323 of the 645 are code files
  (`.rbu`), and they differ because the identities of the units they name
  changed.
* **The identities changed because the hashed bases changed.** Before M3,
  a copy made only to check a functor's declaration recorded a usage for
  every name the applied body looked up. A summary records none. So the
  basis of a unit that only applies functors changes too:
  `0292-integer.rbi` went from 6,240 bytes to 6,178.
* **And the signature changes the rest.** Adding the functor's signature
  to the export basis changes the interface file of every unit that
  declares a functor, then its identity, then every code file that names
  that unit.

So replaying the counters cannot make the files equal. The difference is
what M3 asks for, not a fault in it.

**The gate M3 is held to instead** (the lead's ruling, 2026-10-12):

1. **The whole program's output is byte for byte the base's:** the
   bootstrap, the suites' outputs and bytecode, every error test's
   messages, the five xc2 configurations, and MLton's 606 files compiled
   whole. Static interpretation stays, so the code does not change.
2. **Unit files are equal in their code.** The `.rbu` files are compared
   with units' identities masked, and the linked program of a build in
   units is identical.
3. **M3 is reproducible against itself.** A fresh build and one through
   the cache give the same unit files (`check-units`,
   `check-reproducible`, `test-incremental`, and MLton's units compiled
   twice, once through the cache).
4. **The cut-off is tested.** A scenario changes a functor's body and not
   its signature. The applying units' interface files are byte for byte
   the same across the change, and the units after them come from the
   cache.
5. **Old caches are invalidated.** The version keys of the cache and of
   unit files are bumped, so that a cache made before M3 is a miss rather
   than misread.

The counters are still replayed, so that `used` matches.

**Rejected:** keeping identities equal to the base's, by leaving the
functor's signature out of the identity's hash and replaying the body's
usages at checks. It would weaken the cut-off that M3 is meant to
improve.

### B, functors as functions: to revisit

* **The design:**
  * A functor is compiled once, in its own unit, into a function of its
    argument structure (a record of values).
  * The parameter's types become type parameters of that function, as in
    F-ing modules.
  * Generativity carries over. Rune makes exceptions at run time
    (`NEWEXN`), so each call makes new ones. Datatype tags are static
    constants, which is enough, since a datatype's generativity is only
    static.
  * A client is compiled against the functor's signature through an ABI,
    the shape the incremental plan's D17 gives signatures.
* **Gains:**
  * separate compilation: a change to a body recompiles only its own unit,
    and clients depend on the signature;
  * no copies, so the other 15% of elaboration and the back end's copies
    go.
* **Costs:**
  * **Code quality.** What a body takes from its argument becomes a field
    of a record, called unknown; the parameter's types are abstract, so
    tier 2 gives them no registers and equality goes through the generic
    walk. Functor-heavy code would pay: Rune's own maps are made by
    `OrdMapFn`, and MLton is written in functors.
  * **Size.** Translate, Lambda and the units' code change: larger than any
    milestone of performance.md.
* **The way to keep both: a link-time expansion.** Incremental builds call
  the functor (B). `--units --whole`, which already assembles the whole
  program's Mid from the cache (incremental M7), specialises each
  application on its known argument, getting A's code back. This is the
  incremental plan's "run-time functors or a link-time expansion", taken
  together.

### C, as now: rejected

It keeps a deviation from the Definition and pays for the copies made only
to check.

## Before revisiting B

To be measured first:

1. **HOL4's recompiles.** When a functor body in HOL's kernel changes, how
   many units and how many seconds are compiled again, against the whole
   build: risk 3 of the incremental plan, unmeasured.
2. **What B costs at run time.** Prototype functors as functions without
   specialisation, and time:
   * the compiler compiling itself, whose maps are functors;
   * MLton built by Rune;
   * MLton's benchmark set.
3. **What the link-time expansion recovers.** Specialise those applications
   from the cached Mid in `--whole` and compare with static
   interpretation's code, instruction for instruction.

## Open questions

* **Unit files.** Settled: *A contradiction in M3, found while building
  it*.
* **What depends on the leak.** Whether MLton's sources, HOL4 or the
  libraries rely on equality leaking through a functor's result. M3
  answers it by compiling them.
* **The copies' code.** A copy elaborated against the actual argument may
  still compile `=` on a body's datatype by its representation (in the
  equality example, `d` holds an `int`). That is a choice of code inside
  the body, which the body's check already allowed or refused, and changes
  no type the program sees.
* **What holds 2.5 GB** while MLton's functor-heavy files are elaborated
  (E22): not yet known.

## Where the evidence is

With the drafts of performance.md (`~/.cache/claude-rune-drafts/performance`
on the machine they were made on):

* `results/D3/`: the two test programs and every implementation's answer.
* `results/A-report.md`, and `results/E18` to `E24`: the elaborator's
  counters, the generated programs, the prototypes' gates.
* `patches/A-e18-elab-stats.patch`, `A-e20c-sharing-matching.patch`,
  `A-e21-functor-summary.patch`, `A-e24-midcanon-extras.patch`.
* `lit/modules.md`: the reading of the implementations and the literature.

## References

Every DOI was checked against Crossref.

* D. B. MacQueen, M. Tofte. A semantics for higher-order functors. *ESOP
  '94*, LNCS, 409-423. 10.1007/3-540-57880-3_27 [record; as characterised by
  Rossberg et al. 2014]
* A. W. Appel, D. B. MacQueen. Separate compilation for Standard ML. *PLDI
  '94*, 13-23. 10.1145/178243.178245 [record; quoted via
  incremental-compilation.md]
* M. Elsman. Static interpretation of modules. *ICFP '99*, 208-219.
  10.1145/317636.317800 [in part]
* D. Swasey, T. Murphy, K. Crary, R. Harper. A separate compilation
  extension to Standard ML. *ML '06*. 10.1145/1159876.1159883 [in part]
* M. Elsman, T. Henriksen, D. Annenkov, C. E. Oancea. Static interpretation
  of higher-order modules in Futhark. *PACMPL* 2(ICFP), 2018.
  10.1145/3236792 [abstract]
* G. Kuan, D. MacQueen. Engineering higher-order modules in SML/NJ. *IFL
  2009*, LNCS, 2010, 218-235. 10.1007/978-3-642-16478-1_13 [record]
* A. Rossberg, C. Russo, D. Dreyer. F-ing modules. *JFP* 24(5), 2014,
  529-607. 10.1017/S0956796814000264 [in part]
