# Roadmap: the full Definition of Standard ML '97

This document lists what separates Rune from *The Definition of Standard ML
(Revised)* (Milner, Tofte, Harper, MacQueen, MIT Press 1997) and the order in
which to close the gaps. Rule and section numbers refer to that book. The
Basis Library is a separate specification and is out of scope here except for
the Definition's own initial basis (Appendices C and D). Status as of
2026-09-18.

## Status (2026-09-18, after the work below)

All milestones M1–M4 are implemented and `make check` passes: modules
(signatures, ascription, functors by specialisation), equality types, the
exhaustiveness and redundancy reports, rigid and implicitly scoped explicit
type variables, the top-level closure rule, `abstype`, the syntactic
restrictions of 2.9 and 3.5, `val it`, and `val ... and rec ...`. The
compiler bootstraps with `functor OrdMapFn` in its own sources.

Of M5, the external corpus is in place: `tests/external/run-mlton.sh` runs
MLton's regression programs; 105 pass, and the 142 on
`tests/external/mlton-skip.txt` are Basis Library gaps, MLton-specific
extensions, environment-specific output, or places where MLton itself
deviates from the Definition (equality on an `abstype` outside its body,
undetermined top-level types). The Deviations table of `docs/language.md` is
down to implementation-defined choices. Still open: the Appendix B checklist
as a table, HaMLet differential testing, the class of `~` in Appendix E
(Rune also overloads it at `word`), and the Basis Library.

The rest of this document is the roadmap as it was written before the work.

## Where we were

| Chapter / appendix | Status | Missing |
|---|---|---|
| 2 Syntax of the Core | Nearly complete | `abstype` (2.8). Syntactic restrictions of 2.9: duplicate type variables in a `tyvarseq`, duplicate binders in `typbind`/`datbind`/`exbind`, rebinding of `true false nil :: ref` (and `it` by `datbind`/`exbind`). Over-acceptance: `structure` inside `let`, and `exp` as a declaration inside `let`/`struct`. |
| 3 Syntax of Modules | Missing | Everything except `structure S = struct … end`, `structure S = T`, `open`. All 40 reserved words are lexed (`src/frontend/token.sml`); the parser rejects `signature`, `functor`, `:`, `:>`, `abstype` with "not supported yet" (`src/frontend/parser.sml`, `STRUCTURE` branch of `parseDec`); `structure A = … and B = …` and `local` at structure level are not parsed. |
| 4 Static Semantics for the Core | Mostly complete | Equality types (4.9, Appendix C: `=` is `''a * ''a -> bool`; `real`, `exn` and function types do not admit equality). Rigid explicit type variables and their implicit scoping (4.6, rule 15). Unbound type variables in `type`/`datatype` declarations are accepted. `abstype` (rule 19). Exhaustiveness and redundancy reports (4.11). Overloading resolved per top-level declaration rather than per smallest enclosing `strdec` (Appendix E). |
| 5 Static Semantics for Modules | Missing | Type names with equality attribute, type functions, realisations, signatures (rules 62–84), matching by instantiation and enrichment (52–53), functor signatures and generative application (54), rules 87–89 (no free type variables in the top-level basis). |
| 6 Dynamic Semantics for the Core | Complete | (`abstype` evaluates as `local datatype … in dec end`.) |
| 7 Dynamic Semantics for Modules | Missing | Functor application. `Inter` (cutting a structure down to its signature) is already implied by static resolution of long identifiers. |
| 8 Programs | Deviation | Batch semantics: a static error anywhere rejects the program and an uncaught exception terminates it, where the Definition skips a failed `topdec` and continues. `exp ;` binds `_` instead of `it`. |
| A Derived forms | Core complete | `exp ;` ⟹ `val it = exp ;`; all module derived forms. |
| B Full grammar | Core complete | Module grammar. |
| C, D Initial basis | Complete | Equality attributes of the initial type names. |
| E Overloading | Complete | Resolution scope; the class of `~` (Rune: int/word/real) to be checked against Appendix E. |

Already in place and reused below:

* `Types.tvar` carries an unused `eq : bool` (`src/elab/types.sml`), set from
  the `''a` spelling and propagated by `Unify`; only the check in
  `Unify.bindVar` is missing.
* `Error.warn` / `Error.flushWarnings` exist (`src/util/error.sml`) but have
  no caller; `Main` never flushes.
* `coninfo.ncons` gives the match compiler the constructor count of every
  datatype, so exhaustiveness needs no new elaboration output.
* `git show 7064c0c -- src/util/ordmap.sml` is the functor form of the
  ordered maps (`signature ORD_KEY`, `signature ORD_MAP`, `functor OrdMapFn
  (Key : ORD_KEY) : ORD_MAP`, applied twice for `StringMap`/`IntMap`).
  Restoring it is the acceptance test for modules.

Facts checked against the Definition's text and against HaMLet (Rossberg's
literal implementation of it): 4.11 requires exhaustiveness only for `fn`
matches (hence `case` and `fun`, not `handle`), irredundancy for all matches,
and a report for non-exhaustive `val` patterns except components of top-level
declarations. Chapter 8 "tacitly regards all programs as interactive": a
failed `topdec` is skipped, an uncaught exception discards that `topdec`'s
bindings and continues. Appendix A has `exp ;` ⟹ `val it = exp ;`. Section
3.5 lists the module syntactic restrictions. Rules 87–89 reject free type
variables in the top-level basis.

## Constraints for all items

* Compiler sources stay inside the language Rune accepts (`docs/building.md`
  rule 6) until M1.7 rewrites that rule; `make bootstrap` enforces it.
* Every step leaves `make check` green. Steps that change only static
  semantics must not change emitted bytecode: `make check-cross` and a diff of
  `--dump-lambda` over `tests/lang/*.sml` prove it, which is what makes them
  safe to land separately.
* Every `docs/language.md` row that changes status needs
  `tests/lang/<id>_<name>.sml` with a hand-verified `.expected`; every new
  rejection needs `tests/errors/err.<name>.sml`. Ids contain no `_`.
* Warnings need a home in the test suite: `tests/run-tests.sh` already
  captures compiler stderr for `tests/lang` tests in `tests/out/<name>.cerr`
  but never compares it. Add an optional `.cwarn` sibling (compiler stderr
  compared exactly when present; must be empty otherwise), mirroring
  `.stderr`.
* Determinism: new stamps come from counters; environments are iterated in
  `StringMap` order. This applies to type names, signature instantiation and
  functor application copies.
* Items that turn accepted programs into errors start with an audit
  (`grep`) of `lib/basis` and `src/` so `make boot` keeps working.

## Milestones

Ordered as agreed: modules, equality types, exhaustiveness, remaining Core
rules, conformance verification. "Independent fixes" can be done at any time.
Sizes: S (about a day), M (a few days), L (a week or more), XL (several
weeks).

### M1. Modules (chapters 3, 5, 7; Appendix A) — XL

**Design decision: functors by static specialisation.** Signatures and
functors have no runtime representation. A functor body is elaborated once at
its definition against the parameter signature (this is where the Definition's
errors are reported), and at every application the body's AST is copied with
fresh annotation slots and elaborated again against the argument, then
translated like any structure. Consequences:

* Structures stay flattened to globals; `M.insert` remains one `GLOBAL`, so
  the self-hosted compiler pays nothing for using functors.
* Generativity (rule 54) is automatic: re-elaboration creates fresh type
  names for datatypes and opaque types in the body, and the copied
  `exception` declarations evaluate again, so two applications give distinct
  types and exceptions.
* Constructor tags are those of the actual argument. The alternative
  (compiling the body once against a tuple laid out from the signature) would
  mis-tag a `datatype t = A | B` spec matched by `datatype t = B | A`, because
  enrichment compares constructor *sets*; fixing that by name-sorted tags
  would break the fixed `option`/`order` tags the VM relies on.
* Costs: bytecode duplicated per application; elaboration time linear in the
  number of applications; a `freshenStrexp` copy function that must cover
  every mutable slot in `Ast` (a missed slot means a stale annotation; the
  two applications of `OrdMapFn` in the compiler are the regression test).
* `Lambda`, `Codegen` and the VM are unchanged. SML '97 has no first-class
  or recursive modules, so every application is static.

**M1.1 Type names and type structures (refactor, no language change) — M**

* `Types.tycon` becomes a type name `{name, stamp, arity, eq : bool}`; `eq`
  is stored now and enforced in M2 (`real`, `exn`: false; `ref`, `array`
  admit equality regardless of their argument).
* `type tyfcn = {params : int list, body : ty}` (today's `Abbrev` shape) as
  the general Λα.τ, with `applyFcn` (today's `Unify.substitute`),
  `fcnIsName`, `fcnEqual`, `admitsEq : ty -> bool`, `fcnAdmitsEq`.
* `Env.tystatus` (`Tycon | Abbrev`) becomes one `TyStr {fcn, cons}`
  (well-formedness: `cons <> []` implies `fcnIsName`). `elabTy` applies
  `applyFcn` uniformly. A signature `type t` matched by `type t = int` is
  why the general form is needed.
* `realize : tyfcn IntMap.map * ty -> ty` and `Env.realizeEnv` (schemes,
  constructor schemes, exception types, substructures). One function serves
  `where type`, `sharing`, matching, opaque renaming and the datatype
  equality fixpoint.
* Datatype equality attribute (Section 4.9, rule 17): compute the maximal
  solution per `datbind` group (start with all true, drop a datatype when a
  constructor argument does not admit equality, iterate). Stored, not yet
  enforced.
* Latent bug to fix here: `Unify.bindVar` (`KOverload`) and
  `Translate.operandTycon` compare tycon *names*; compare stamps against the
  builtin names, or an opaque type called `int` would admit `+`.
* Acceptance: bytecode of every test and of `bin/rune.rbc` byte-identical to
  the previous commit; `make bootstrap`.

**M1.2 Module grammar (3.4, 3.5, Appendix B) — M**

* `Ast`: `sigexp` (`SigSig of spec list`, `SigId`, `SigWhere`); `spec` (val,
  type, eqtype, type abbreviation (derived), datatype, datatype replication,
  exception, structure, include, `sharing type`, structure `sharing`
  (derived)); `strexp` gains `StrAscribe of strexp * sigexp * opaque`,
  `StrApp of funid * strexp * strexp option ref` (the slot holds the
  elaborated copy), `StrLet of dec list * strexp`; `dec` gains `DStructure
  of strbind list` (for `and`), `DSignature`, `DFunctor of funbind list`
  where `funbind = {name, param : string option, paramSig, body}` (`param =
  NONE` is the `functor F (spec)` form). `--dump-ast` printers.
* Parser: derived forms rewritten exactly as Appendix A: `structure S : SIG
  = e` and `:>` ⟹ ascription on `e`; `functor F (X : S) : R = b` ⟹
  ascription on `b`; `funid (strdec)` ⟹ `funid (struct strdec end)`; `type t
  = ty` in a spec ⟹ `include sig type t end where type t = ty`; `include A B`
  ⟹ two includes; `where type … and type …` ⟹ nested; structure `sharing`
  ⟹ `sharing type` over the common type paths (resolved in elaboration).
* `parseDecs` takes a context (`Top | Str | Let`): `signature`/`functor` only
  at `Top` (rules 88–89 are `topdec`s); `structure` and `local` containing
  `structure` not in `Let` (fixes today's over-acceptance in the `let`
  branch); the `exp`-as-declaration fallback of `parseDec` only at `Top`.
  Fixity environments saved and restored around `sig`, `struct` and functor
  bodies.
* Section 3.5 restrictions: no duplicate binder in a `strbind`/`sigbind`/
  `funbind` group; no identifier described twice in a spec sequence (rule 77
  side condition, via an `Env.plusDisjoint`, also through `include`); type
  variables on the right of a `datdesc` or in a `where type` right-hand side
  must occur in its `tyvarseq`; `true false nil :: ref` may not be described
  by `valdesc`/`datdesc`/`exdesc`, `it` not by `datdesc`/`exdesc`.
* Elaboration says "not supported yet" for `sigexp`/`functor` nodes until
  M1.3–M1.6, with one `tests/errors/` test per message.
* Rows: `mod.strdec.and`, `mod.strdec.local`, `mod.let`; errors
  `err.let_structure`, `err.spec_duplicate`.

**M1.3 Signatures and transparent ascription (rules 52, 62–63, 65–74, 79–84, 88) — L**

* New `src/elab/sig.sml` (before `elaborate.sml` in `sources.txt`):
  `type sigma = {bound : tycon list, env}`; `instantiate` renames every bound
  name to a fresh stamp at every use of a `sigid` (rule 65); `match (sigma,
  actual) : env` in two phases: (1) realisation: for every bound name, look up
  the same type path in the actual structure (arity check, `eq` check once M2
  lands, a `datatype` spec requires a type name) and record `phi`;
  (2) enrichment on `realizeEnv (phi, env)`: every type present with
  `fcnEqual`; constructor sets and schemes equal where the spec has
  constructors; every value present with a scheme at least as general
  (instantiate the actual, unify against the spec scheme with its generic
  variables replaced by fresh nullary skolem tycons, so neither environment
  is mutated); `exception` specs matched only by exceptions. The result
  keeps the spec's schemes and type functions and the actual's stamps,
  `coninfo`, `exninfo`.
* Status downgrade (rules 52–53 via enrichment `is' = v`): a constructor or
  exception matched by a `val` spec becomes a plain value. Needs a
  `valstatus` variant that translates like the constructor in expressions but
  is not a constructor in patterns (`S.A` in a pattern is then an error, `A`
  after `open S` a variable). Cheap, and required by the Definition.
* Specs: `val` closes over its type variables (rule 79, elaborate at `level
  + 1` then generalise); `type`/`eqtype` create bound names with `eq`
  false/true; `datatype` specs create bound names with constructor
  environments and maximised equality (71); replication (72), `exception`
  (73), nested `structure` (74). Signatures and functors are basis
  components, not environment components: `Elaborate.sigs`/`funs` maps, reset
  by `Main`.
* Type explication holds by construction (bound names only arise from
  type/eqtype/datatype specs, which bind them in the environment; `where
  type` and `sharing` only remove names). Assert it with `Error.bug`.
* Rows: `mod.signature` (declaration and reference), `mod.spec` (each spec
  kind), `mod.ascription` (transparent, hidden components, status
  downgrade). Errors: `err.sig_missing_val`, `err.sig_val_type`,
  `err.sig_datatype_cons`, `err.sig_exception_by_val`, `err.ascription_hidden`.

**M1.4 `include`, `where type`, `sharing` (rules 64, 75, 78; Appendix A) — M**

* `include`: instantiate the included signature and merge disjointly.
  `where type` (64): the path must be a bound name (else "type … is not
  flexible"), arity check, equality check, a spec with constructors can only
  be realised to a type name; remove the name from `bound`, realise.
  `sharing type` (78): all paths flexible names of equal arity; keep one with
  `eq` = or of all; realise the others. Structure `sharing` is the derived
  form over all common type paths of the structures named.
* Rows: `mod.include`, `mod.wheretype`, `mod.sharing`, `mod.sharing.structure`.
  Errors: `err.wheretype_rigid`, `err.sharing_rigid`, `err.wheretype_arity`.

**M1.5 Opaque ascription (rule 53) — S**

* Match as in M1.3, then rename `bound` to fresh names in the result;
  abstract types carry `eq` from the spec (`eqtype` true, `type` false,
  `datatype` maximised) and keep the spec's constructors under the fresh
  name. Printing: when two distinct stamps share a name, append the stamp.
* Rows: `mod.ascription.opaque`. Errors: `err.opaque_abstract` (`S.t` used as
  its implementation type).

**M1.6 Functors (rules 54–55, 85–86, 89) — L**

* Definition: instantiate the parameter signature, bind `X` (or open the
  instance for the `spec` form), elaborate the body in the definition
  environment, discard annotations, record `{paramSig, body, defEnv,
  allowPrim}`. Application: elaborate the argument, `match` it against the
  parameter signature, copy the body (`Ast.freshenStrexp`), elaborate the copy
  with `X` bound to the thinned argument (restoring the recorded `allowPrim`,
  so basis functors using `_prim` work from user code), store it in the
  `StrApp` slot. `Translate` emits the argument's declarations then the
  copy's. Errors inside a copy cannot happen (the definition check is at
  least as strict); report them as `Error.bug` prefixed "in application of
  F". `let strdec in strexp end` (55) is a local scope of declarations.
* Rows: `mod.functor` (both parameter forms, `open` of the parameter,
  datatype replication of a parameter type, `F (strdec)`), `mod.functor.result`
  (`:` and `:>` result ascription), `mod.functor.generative` (two
  applications: distinct exceptions at runtime; incompatible types as an
  error test), `mod.functor.nested` (application inside a body, functor
  result as argument). Errors: `err.functor_arg_mismatch`,
  `err.functor_body_illtyped` (with no application present),
  `err.functor_generative_types`.

**M1.7 Closing the milestone — S**

* Restore `src/util/ordmap.sml` from `7064c0c` (functor form, two
  applications) and pass `make check` including `bootstrap`; compare
  bootstrap time and `bin/rune.rbc` size before and after (duplication cost).
* `docs/language.md`: `mod.*` rows Supported, `dec.structure` Supported,
  Deviations row *Modules* removed; new deviation "functor bodies are
  specialised per application (no observable difference)".
  `docs/building.md` rules 2 and 6 and `AGENTS.md` allow signatures and
  functors (SML/NJ CM still wants only `structure`/`signature`/`functor` at
  top level). `docs/architecture.md`: Elaboration row, a *Modules*
  paragraph, the Bootstrapping paragraph. `README.md`.
* Optional follow-up: ascribe `lib/basis` structures to (partial) Basis
  signatures as a permanent matching regression test; measure the cost on
  the per-program basis compile (0.5 s on the interpreter today).

### M2. Equality types (4.9, Appendix C; rules 17, 19, 70–71) — M

* Enforce `eq`: `admitsEq` in `Unify.bindVar`: binding an `eq` variable to a
  type that does not admit equality is an error ("type … does not admit
  equality"); binding to a plain variable marks it `eq`; an `eq` overloaded
  variable drops `real` from its class; flexible records propagate `eq` to
  all fields. `=`/`<>` in `Env.builtinVals` get `''a * ''a -> bool`.
* Signature matching honours `eqtype` (realised type function must admit
  equality), `datatype` specs, `where type`/`sharing` attributes (M1.3–M1.4
  leave hooks for this). `abstype` (M4.4) and opaque `type` give `eq = false`.
* Audit first: `=` on `real`, functions, `exn`, streams in `lib/basis` and
  `src/` (the compiler compares tokens and AST fragments; `Token.REAL of
  string` is fine). `TextIO` streams are datatypes and stay equality types
  as long as they contain no `real`/function fields.
* Rows: `ty.eqtype` Supported; errors `err.eqtype_real`, `err.eqtype_fn`,
  `err.eqtype_exn`, `err.eqtype_datatype`, `err.eqtype_opaque`,
  `err.eqtype_spec`. Deviations row *Equality types* removed;
  `ty.tyvar.explicit` notes updated.

### M3. Exhaustiveness and redundancy reports (4.11) — M

* Warning channel: `Error.warn` collects; `Main.compile` flushes after
  elaboration (also with `--typecheck-only`), sorted by position. Option
  `--no-warnings`. `.cwarn` support in `tests/run-tests.sh`;
  `scripts/check-docs.sh` unchanged (rows still map to `tests/lang` files).
* Analysis on elaborated `Ast` patterns: Sestoft's algorithm (*ML pattern
  match compilation and partial evaluation*, 1996; also HaMLet's
  `CheckPattern`), which yields both reports from one traversal. It is the
  same algorithm the performance plan's item 4 needs for decision-tree match
  compilation in `src/core/matchcomp.sml`, so the two can share the pattern
  matrix, but the reports do not require the match-compiler rewrite.
  Constructor sets via `coninfo.ncons`; exceptions are an open type; special
  constants are infinite domains (no attempt to enumerate `char`); `ref`,
  records and tuples are single-constructor; layered and typed patterns are
  transparent.
* Reports exactly as 4.11 says: `fn` matches (hence `case` and `fun`
  clauses) not exhaustive → "match not exhaustive"; any match, including
  `handle`, with an unreachable rule → "redundant match rule"; `val pat = exp`
  not exhaustive → "binding not exhaustive", except when the binding is a
  component of a top-level declaration. Name the missing case when cheap.
* Audit: the basis and compiler sources will produce warnings (intentionally
  partial functions such as `hd`). Rewrite them or, for the prelude, compile
  with warnings off; `make boot` output must be warning-free.
* Rows: `ty.exhaustive` Supported with `tests/lang/ty.exhaustive_*.sml` +
  `.cwarn`. Deviations row *Exhaustiveness* removed.

### M4. Remaining Core static semantics — M in total

**M4.1 Explicit type variables (4.6; rule 15) — S/M**

* Pre-pass per `val`/`fun`: collect the type variables occurring unguarded
  in it that are not scoped by an enclosing value declaration; scope them,
  with the explicit `tyvarseq`, at this declaration (the Definition scopes at
  the *outermost* such declaration; `elabTy` today scopes at the innermost
  use). A `tyvarseq` variable already in scope is an error (rule 15's `U`
  side condition).
* Scoped variables are rigid: a `Types.kind` case `KRigid of string` that
  `Unify.bindVar` refuses to bind to anything but a fresh plain variable
  ("type variable 'a cannot be instantiated"); generalised at the closing of
  the declaration as today.
* Type variables in `type`/`datatype` declarations not bound by the
  `tyvarseq`, and in `exception` declarations not scoped by an enclosing
  value declaration, are errors ("unbound type variable").
* Errors: `err.tyvar_rigid`, `err.tyvar_rescoped`, `err.tyvar_unbound_type`.
  Deviations row *Type variable scoping* removed.

**M4.2 No free type variables at top level (rules 87–89) — S**

After `resolvePending` in `Elaborate.elabTop`, walk the declaration's
environment for unbound non-generic variables and report an error naming the
binding (`val r = ref nil`). Audit compiler sources and basis for top-level
expansive bindings with unresolved types. Deviations row *Value restriction*
updated; error `err.toplevel_tyvar`.

**M4.3 Syntactic restrictions (2.9) — S**

Add the missing checks: duplicate type variable in a `tyvarseq`; duplicate
type constructor across a `typbind`/`datbind` (including `withtype`);
duplicate exception in an `exbind`; `true false nil :: ref` not bound by
`valbind`/`datbind`/`exbind`; `it` not bound by `datbind`/`exbind`; `and
rec` in a `valbind` follows the grammar (`rec` applies to the rest of the
list) instead of being skipped. One `tests/errors/` test each. (Duplicate
record labels and duplicate pattern variables are already checked.)

**M4.4 `abstype` (rule 19; row `dec.abstype`) — S**

Parse `abstype datbind ⟨withtype typbind⟩ with dec end`; elaborate the
`datbind` as a datatype, elaborate `dec` with the constructors in scope,
return the type structures without constructors and with `eq = false`
(Section 4.9 `Abs`) plus the environment of `dec`. Translate as `local
datatype … in dec end`. Errors: constructor used outside the `with` part,
`=` on the abstract type. Deviations row *`abstype`* removed.

**M4.5 Programs and overloading (Chapter 8, Appendices A, E) — S**

* `exp ;` at top level ⟹ `val it = exp` (Appendix A); the row
  `dec.toplevelexp` stops being an extension; test that `it` is bound and
  rebindable.
* Record the batch decision in the Deviations table: Rune rejects a program
  with a static error in any `topdec` and terminates on an uncaught
  exception, where Chapter 8 skips the failed `topdec` and continues. Same
  choice as MLton; no code.
* Appendix E: resolve pending overloads and flexible records at the end of
  the smallest enclosing `strdec` (also inside `struct … end` and functor
  bodies) instead of the top-level declaration only; check the classes of
  `~` and `abs` against Appendix E and adjust `Env.builtinVals`.

### M5. Conformance verification and closing — M

* Appendix B checklist: a table in `docs/language.md` mapping each
  production and derived form of Appendices A/B to the row that tests it,
  so `make check-docs` remains the contract. Every rule of chapters 4 and 5
  that rejects a program gets a `tests/errors/` test.
* External corpus under `tests/external/` (not in `make check` until
  stable): MLton's `regression/` programs (BSD licence, `.sml` + expected
  `.ok` output) with an allow-list for tests needing unimplemented Basis
  structures; HaMLet for differential accept/reject testing of the static
  rules; Rossberg's *Defects in the Revised Definition of Standard ML* for the
  known ambiguities (sharing with `where type`, datatype replication in
  specs, rule 15 scoping): decide each and record it in the Deviations table.
* Retire the Deviations table to what the Definition leaves to the
  implementation: 64-bit `int`/`word`, 8-bit characters, batch program
  semantics, functor specialisation, the `_prim` extension, and the
  Basis-related rows (single-member overloading classes, `Word8Vector` as
  `string`, I/O streams as datatypes). Everything else must be gone.
* `README.md`: "the full language of the Definition"; version 1.0 candidate.

### Independent fixes (any time, S each)

* Warning channel and `.cwarn` (first bullet of M3).
* Unbound type variables in `type`/`datatype` declarations (part of M4.1).
* `structure` and `exp` inside `let` rejected (part of M1.2).
* `tests/errors/` coverage for every error message in `parser.sml` and
  `elaborate.sml` that has none.

## Out of scope

* The Basis Library (2004): `Substring`, `Word8`, `StreamIO`, literal and
  operator overloading at `IntInf.int`, `fmt`/`scan`, slices. Tracked by the
  `basis.*` rows. After M1 the Basis signatures become expressible, and
  Appendix E's classes can grow (`Int` = {`int`, `IntInf.int`}) without
  Definition-level changes.
* An interactive top level.
* Performance: `docs/plans/performance.md`. Its item 4 and M3 share Sestoft's
  pattern matrix.

## Verification

```sh
make check                                        # four builds, identical bytecode, docs, bootstrap
sh tests/run-tests.sh mod.                        # module rows with bin/rune, the self-hosted compiler
sh tests/run-tests.sh --rune bin/rune-mlton mod.  # the same, faster, while iterating
```

Static-only steps (M1.1, M1.3–M1.5, M2, M4): `--dump-lambda` on every
`tests/lang/*.sml` identical before and after; `make check-cross`.

M1.7: `git show 7064c0c^:src/util/ordmap.sml > src/util/ordmap.sml`, adapt
the two applications, `make check`; record bootstrap time and `.rbc` size.

M3: `make boot 2>&1 | grep -c warning` prints 0.

M5: the external runner prints pass/fail per corpus; every failure is on the
allow-list with a reason or listed as a bug in this file.
