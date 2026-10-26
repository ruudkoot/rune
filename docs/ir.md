# The intermediate representations

What the compiler's intermediate representations are, what every one it
makes keeps, and how to look at them. The plan they come from, and the
ones still to come, is [plans/middle-end.md](plans/middle-end.md).

## The pipeline

| Stage | From | To | Lint |
|---|---|---|---|
| `translate` | the elaborated syntax | `Lambda` (`lib/compiler/core/lambda.sml`) | `LambdaLint` |
| `mid` | `Lambda` | `Mid` (`lib/compiler/core/mid.sml`, by `ToMid`) | `MidLint` |
| `midcanon` | `Mid` | `Mid` numbered canonically (`lib/compiler/core/midcanon.sml`), as one made of its units' `Mid` is; a whole program only | its renaming (`MidCanon.checkRenaming`); `MidLint` of the units' `Mid` it concatenates (`midconcat`) |
| `expand` | `Mid` | `Mid`, functors' applications copied (`lib/compiler/core/expand.sml`; *Functors compiled once* below), from `-O1` | `MidLint` |
| `shake` | `Mid` | `Mid`, what nothing reaches gone (`lib/compiler/core/shake.sml`), from `-O1` | `MidLint` |
| `lift` | `Mid` | `Mid`, local functions that never escape made functions of the top level (`lib/compiler/core/lift.sml`), from `-O1` | `MidLint` |
| `workers` | `Mid` | `Mid`, tupled and curried functions split into workers and wrappers (`lib/compiler/core/workers.sml`), from `-O1` | `MidLint` |
| `simplify` | `Mid` | `Mid`, shrunk (`lib/compiler/core/simplify.sml`), from `-O1` | `MidLint` |
| `refs` | `Mid` | `Mid`, a loop's local refs as values (`lib/compiler/core/refs.sml`), from `-O1` | `MidLint` |
| `lower` | `Mid` | `Low` (`lib/compiler/backend/low.sml`, by `Lower`) | `LowLint`, `LowShapes` |
| `stack` | `Low` | instruction lists (`lib/compiler/backend/stack.sml`), with `--target=stack` | the loader's checks and `RbcCheck` (`StackCheck`) |
| `registers` | `Low` | instruction lists of the register bytecode (`lib/compiler/backend/regs.sml`), the default target | `RegVerify` |
| `emit` | instruction lists | the `.rbc` (`lib/compiler/backend/emit.sml`) | |

`-O0` is the same stages with no optional pass; `-O0` and `-O2` must give
programs that print and exit the same, traces included (`make
check-levels`). The first code generator, of `Lambda`, was `-O0` and the
reference the new back end was compared with until M10 (decision D10 of
the plan).

Each stage runs through `Pass.stage` (`lib/compiler/util/pass.sml`), which prints
what it is given or makes when asked, checks it with the lint of its
representation, and says what it cost. An optional pass, one that only
optimises, says from which level it runs (`Pass.enabled`): `trees`, which
is how `translate` compiles a match (see *Matches*), then `expand` (under
*Functors compiled once*), `shake`, `lift`,
`workers`, `simplify` and `refs`, in that order, and `shake` again where `simplify`
inlined (see *The optimisations of Mid*); `inline` and `specialise` are
what `simplify` does besides shrinking, each of which may be left out, as
is `equality`, which only `-O2` runs; and `results` is what `lower` does
of results in globals (see *Low*).

## Options

| Option | What it does |
|---|---|
| `-O0`, `-O1`, `-O2` | the level; `-O1` when none is given; `-O2` adds `equality` (see *The optimisations of Mid*) |
| `--passes=P,...` | run these optional passes, whatever the level |
| `--dump-before=P`, `--dump-after=P` | print what the pass `P` is given or makes (`all`: every pass); `--dump-lambda` and `--dump-code` are `--dump-after=translate` and `--dump-after=registers` (`stack` with `--target=stack`) |
| `--lint`, `--lint=LEVEL` | check what the passes make, at the level given (*Levels*, below; a bare `--lint` is 2, every pass), and stop with `Error.Bug`, which names the check, at the first breach; `RUNE_LINT=LEVEL` does the same where no flag reaches (the REPL, the compiler library), and every test sets `RUNE_LINT=2` ([testing.md](testing.md), *Running the tests*). A check changes nothing of what the compiler makes, the same bytes at every level, units and their bases too (`make check-levels`), and moves none of its counters of names -- stamps, type names, functions, labels -- which `Pass.checkAt` holds every check to, since one that took fresh names hid a bug it should have caught |
| `--fuel=N` | make no more than `N` rewrites: a pass that rewrites asks `Pass.spend` before each |
| `--pass-stats` | the size of what every stage makes and its processor time, on standard error, as `pass NAME: N nodes, T s`; then each check, at every depth, as `check KEY: N runs, T s, I instructions` (the instructions where the runtime counts them, as Rune's own build does); then `total: T s processor time, S s in the stages (P%)` (below) |
| `--pass-stats=elab` | `--pass-stats`, and a line for each top-level declaration elaborated: where its processor time went, by context and operation, and what the elaborator counted (*The elaborator's counters* below) |
| `--pass-stats=expand` | `--pass-stats`, and after the expansion a line `expand: N applications expanded, M left calls (B past the budget), P copies not all definitions; at most S nodes copied for a top-level application` (*Functors compiled once* below) |
| `--pass-stats=hash` | `--pass-stats`, and at the end what the compile hashed: a line `hash PHASE:SITE: B bytes, N hashes` for each part of a compile in units (`usages`, `find`, `export`, `load`, `cache`) and place that hashed, and `memo PHASE: H hits, M misses` for the memo of fingerprints (*What a compile in units hashes* below) |
| `--units` | run the pipeline on one unit, a file, at a time, and link them ([units.md](units.md)): the passes see a unit, with `Pass.whole` false, and `--pass-stats` names each unit before its passes |
| `--read-mid FILE` | read a Mid program in the text a dump prints, and make and check it as the pass `mid` would (there is no bytecode from Mid yet) |
| `--mid-roundtrip` | check that Mid printed with its positions, read and printed again is the same, after `mid` (the check `mid-roundtrip`); what it reads is numbered by counters of its own, so that a unit's basis is what it is without it |
| `--functor-budget=N` | the Mid nodes `expand` may copy for a top-level application and those in its copies (1000000 by default; 0 copies none) |

### Levels

The checks of a compile run by level (`Pass.checkAt (KEY, LEVEL)`; the
linting roadmap, D12 and D13), each from its level up:

| Level | What runs | What it costs, in instructions (HaMLet `-O1`; the compiler `-O1`) |
|---|---|---|
| `off` | none of level 0's; the passes' own assertions, the decoders and the loader, as always | -- |
| 0 | always on, where nothing says otherwise in `rune`: the invariant of results in globals after every `lower` (`results`), and the functor bodies a unit's basis decoded, linted at the next unit's passes (`functor-body`) | 0.14%; 0.52% |
| 1 | the boundaries between representations: `LambdaLint` after `translate`, `MidLint` after `mid` (and of the units' Mid `--units --whole` concatenates, `midconcat`) and of what `lower` is given (`prelower`), `midcanon`'s renaming, `LowLint` and `LowShapes` after `lower`, `RegVerify` after `registers` and at every link (*The register target*); what the REPL and the compiler library run where nothing says otherwise | 16.4%; 32.8% |
| 2 | every pass: `MidLint` after each optional pass on Mid, and inside `simplify` of each definition as it is made, with the copies its calls made, in the program around it (`simplify-def`), and a unit's code read back as its file says it (`code-rt`: `UnitFile.read` of the bytes written, the same code but for the reader's normal form, and the same bytes written again); what `--lint` runs, and every test | 35.4%; 70.7%, and 11% more of a compile in units for `code-rt` |
| 3 | and Mid's text read back after every stage of Mid (`KEY-roundtrip`), as `--mid-roundtrip` does after `mid` alone from level 1; one tier of `make check` (`make test-ir`) | about 9 times the compile |

`--lint=LEVEL` gives the level; else `RUNE_LINT` (a level, `off`, or
anything else not empty, 2; empty or unset, the program's own); else 0 in
`rune`, and 1 in the REPL and the compiler library. A check that is always
on and finds a breach says so: it is the compiler's bug, not the
program's, `--lint=2` names the pass that made it, and `--lint=off` turns
the check off. A breach that a check at level 1 finds names the check, the
boundary that found it; `rune` then compiles again at level 2, from the
state its options left (`CompilerState`'s baseline, sealed before the
first compile), and names the pass that made it, since a compile is
deterministic and no check changes it. The seal costs about 300,000
instructions, a seventh of compiling `examples/hello.sml`, so `rune` takes
it at level 1 and not at 0. The REPL and the library name the boundary,
and that `--lint=2` would name the pass.

**What `--pass-stats` shows** is the whole compile: the stages add up to
the process's processor time from its start, which `tests/compiler` holds
them to (within 2%, and 15% on SML/NJ's builds, whose processor time counts
the collector's twice), so that no part of a compile goes untimed. Beside the
stages of the pipeline above, the compile's stages are:

* `startup`, what the process took before the compiler's own code ran:
  loading it, and on `runevm` the bytecode and the compiler's top-level
  declarations;
* `lex`, the input files read and lexed (their tokens), and `select`, the
  files of the libraries they need chosen (those files);
* `parse` and `elaborate`, whose size is the top-level declarations;
* with `--units`, the work of the cache and of each unit (`cache-key`,
  `cache-find`, `unit-begin`, `unit-passes`, `unit-export`, ..., and `link`);
  the pipeline's stages of a unit run inside its `unit-passes`, and only
  the outermost stages are added up;
* `stats`, the sizes `--pass-stats` counted, and `checks`, what `--lint` and
  the dumps took, apart from the stages they checked or printed.

After them, a line `check KEY` for each check that ran, at whatever depth,
by its key (`Pass.checkAt`; *Levels* above): the stage it follows
(`translate`, `mid`, `midcanon`, ..., `lower`), `midconcat`, `prelower`,
`mid-roundtrip` and the other round trips, `results`, which runs inside
`lower`, `simplify-def`, inside `simplify`, `functor-body`, `code-rt`,
`shapes` (level 1), `rbccheck`, the check of the stack code (level 2), and in units `link`, the
check of the units' interfaces at the link, and `schemes`, of a cache
entry's imported schemes where it is taken, both at level 0
([units.md](units.md)). They are counted in the stages' times already, `checks`
or a unit's `unit-passes`, so they show what a compile in units lints,
which `checks` does not, and are not added to the total again. A check's
line ends with what it counted (`Pass.tally`): `lower`'s `downcasts`,
`shapes`' `shaped` and `unshaped`.

**A dump** (`Lambda.show`) prints one node to a line, its parts indented
below it unless they are all atoms, and leaves positions out. Variables
and globals are numbered afresh (`v1`, `g1`, ...) in the order they appear,
so that an expected dump does not change with stamps made elsewhere.

### What a compile in units hashes

`--pass-stats=hash` counts the bytes `Pickle` hashes (`Pickle.counting`),
each under the label of the part of the compile and the place that hashed
it (`UnitBasis.labelled`):

* `usages:KIND`, the fingerprints of a unit's usages by what is hashed:
  an entry (`v`, `t`), an environment's entries (`env`), a signature
  (`sig`), a functor (`fun`), a structure of a signature that their
  streams name by reference (`sigref`, once a session: [units.md](units.md),
  *Fingerprints*), a fixity (`fix`), and a group of type names they name
  (`tycon`), each group once a session (`tyconFps`);
* `find:KIND`, the fingerprints worked out to check a cache entry's usages;
* `export:source`, `export:identity` and `export:body`, a unit's source, its
  basis and a functor's body; `export:KIND` a functor applied in a body;
  `sigabi`, a dynamic module's signature (UnitBasis.sigFingerprint);
* `load:source`, a source parsed again for a functor's body;
* `cache:key`, `cache:source`, `cache:read`, `cache:store`, `cache:paths`
  and `cache:configuration`, the cache's keys and the integrity of its
  files.

`memo PHASE` counts the memo of fingerprints (`fpMemo`): a usage's
fingerprint by its binder and key is worked out once a session. Nothing
else changes: the bytes and the program are the same with the counters on.

### The elaborator's counters

`--pass-stats=elab` (`lib/compiler/elab/elabstats.sml`) prints, for each top-level
declaration, a line

```
elab FILE:LINE:COL KIND NAME total=US CONTEXT.OPERATION=US ... COUNTER=N ...
```

with `KIND` one of `signature`, `functor`, `structure` and `core`, and
`NAME` the first name it binds (`-` for a core declaration). Times are
microseconds of processor time; what is zero is left out. The
declaration's time is split by:

* **context:** `top`, the top level; `fundecl`, a functor's body
  elaborated at its declaration; `appcode`, an application at the top
  level whose code is made, its match and its call; `appcheck`, an
  application inside a functor's body, or anywhere under
  `--typecheck-only`, which makes no code;
* **operation:** `inst`, a signature instantiated; `where`, `where type`;
  `share`, sharing; `match`, a structure matched against a signature;
  `specs`, a signature's specifications, without the operations before
  inside them; `core`, the rest. Time goes to the innermost operation
  running.

The counters: `realize`, the environments realised, and `nodes`, the type
nodes they visited (the steps of type work they took, one a node); `inst` and `inst.names`, the signatures instantiated
and the flexible names renamed; `where`, the clauses of `where type`;
`share.types` and `share.structures`, the sharing equations (a structure's
counting its types' among `share.types`); `match` and `match.paths`, the
matches and the type paths of their signatures; `fundecl`, the functor
bodies checked; `app.code` and `app.check`, the applications of each kind,
and `app.depth` their deepest nesting; `unify`, the pairs of types
unified; `steps`, the steps of type work that `--type-work` bounds. The
counters do not depend on the machine. The checks deferred to the end of
the program or of a unit -- whether matches are exhaustive, flexible
records -- have a line of their own, `elab - deferred - ...`.
`bin/rune-measure elab-stats` adds the lines up into a table of contexts and
operations, and names the declarations that took longest.

## What a `Lambda` keeps

`LambdaLint` checks, after `translate`:

* **Scope:** every variable is used where a binder of it is in scope: a
  function's parameter, a `Let`, a `LetRec`, a `Handle`.
* **Unique stamps:** every binder's stamp is bound once in the whole
  program. Every representation after it relies on it: what a pass knows
  of a variable is kept by its stamp.
* **`Fail`:** every `Fail` is in tail position of the body of a `Try` of the
  same function, where it jumps to the `Try`'s fallback with the stack as
  the `Try` found it. Tail position runs through a `Let`'s body, the second
  of a `Seq`, both arms of an `If`, the fallback of an inner `Try`, a
  handler and a mark.
* **`Jump`:** every `Jump` is in tail position of the scope of its `Join`,
  in the same function, with an argument of each parameter's type. Only a
  match compiled as a decision tree makes them (below).
* **`LetRec`:** every right-hand side is a function.
* **Types:** it is well typed, as below.
* **What its types alone do not say** (`IrRules`, which `MidLint` shares;
  plans/correctness/linting.md, M4):
  - a constant is of its type's kind -- an `int`'s `CInt`, a `word`'s
    `CWord`, ... -- and in its range: an `int`'s 63 bits, an `Int64.int`'s
    64, a `word`'s and a `Word64.word`'s from 0, a `char`'s 8;
  - a primitive's type at a use is an instance of its description
    (`PrimTys`, which `runeisa` makes of `src/isa/prims.sml`): each type
    variable one type throughout, a type the compiler builds in itself,
    `unit` the empty tuple, and a name it does not (`option`, `order`,
    `Word32.word`) any type; the compiler's own primitives are checked by
    their own rules;
  - an exception's payload (`MkExn`) has its argument's type, by the
    constructor's stamp (`Ty.exnArgOf`): the elaborator's, or a copy's
    that the pass which copied it registered at the copy's types
    (`Ty.copyExn`: `Expand` and `Simplify` with their substitutions, `Lift`,
    `MidCanon` with its renaming), or the one `Simplify` gave it where it
    put the body of a function called once at the call's types
    (`Ty.retypeExn`), each from level 1, where a lint will look:
    `exception E of 'a` in a function is checked at `'a` in the function
    and at the types of each copy made of it;
  - a cast the compiler makes is of its origin's kind (below): a
    `functor_cast` or a `dynamic_cast` is to `unit` or from it, an
    `open_cast` to or from a flat type (`unit`, a tuple of units,
    `Ty.flat n`); the program's own `unsafe_cast` is anything.

A breach is a bug of the compiler, never of the program.

### Types

`Lambda` is typed (decision D3 of the plan): the lint finds the type of
every node from its parts, and a mistake of the translation or the match
compiler shows as a node whose parts do not fit. The types are `Ty.ty`
(`lib/compiler/core/ty.sml`), made from the elaborator's once it has finished:

* **Generic and free variables:** `Gen` is a variable of a scheme; `Var` one
  no type was ever found for, equal only to itself.
* **Records** are tuples of their fields in the order of their labels.
* **Abstract types** are what they stand for: an opaque signature hides a
  type from the program, not from the compiler.
* **`ExnCon`** is the type of an exception constructor; `exn` that of an
  exception.
* **A datatype declared in a function** that names the function's type
  variables (`fun 'a f ... = let datatype t = T of 'a ...`) has them as
  parameters after its own, and every type made of it gives them as
  themselves (`Ty.extrasOf`): those its constructors name, and those of the
  datatypes they name. An instance of the function -- inlined, specialised
  -- then gives its constructors' arguments the instance's types.
* **Shared:** a type is hash-consed ([plans/performance.md](plans/performance.md),
  M4): each node is made once, through a table, and has a number of its
  own (`Ty.id`), so that two types are equal where their numbers are
  (`Ty.equal`), and one the elaborator shares, of 2^n nodes as a tree, is
  n nodes here too. A node is seen through `Ty.view` and made by `Ty.gen`,
  `Ty.var`, `Ty.con`, `Ty.tuple`, `Ty.arrow` and `Ty.exnCon`; a node knows
  its size as a tree (`Ty.size`) and its generic variables (`Ty.gens`).
  Every walk over a type that could meet a big one is memoised on the
  numbers of its nodes (`Ty.subst`, `Ty.match`, MidCanon's renaming,
  MidText's printing), and walks one of at most `Ty.smallType` nodes as a
  tree. Simplify's key of a type is its number. The translation of each
  top-level declaration's types still spends `--type-work`, a step for a
  node converted, a big type's shared node once
  ([plans/type-checker.md](plans/type-checker.md)).

The elaborator fills four tables as it goes (`Ty.binders`, `Ty.exnArgs`,
`Ty.datatypes`, `Ty.realizations`): the scheme of every variable, the
argument of every exception, the constructors of every datatype, and what
each opaque type stands for. A node carries a type only where its parts do
not give it:

| Node | Carries | Checked |
|---|---|---|
| `Fn (x, t, b)` | `t`, an arrow; `x` has its domain | `b` has its codomain |
| `Inst (e, t)` | the instance a polymorphic variable is used at | `t` is an instance of `e`'s scheme (`Ty.match`) |
| `LetRec` | each function's type | its right-hand side has it |
| `Const`, `Con0`, `Con` | the type made | a constructor is one of the datatype's, and its argument fits |
| `Decon (tag, e)` | the constructor's tag | `e`'s datatype has it; the result is its argument |
| `ExnArg (t, e)` | the payload's type | `e` is an `exn` |
| `Prim (p, t, args)` | `p`'s type at this use | the arguments fit its domain |

A `Prim` without a type is one of the three whose type the lint works out:
`poly_eq` and `ptr_eq` (two of a type, giving `bool`) and `ref_get`. A
primitive's type is the one the Basis Library's `_prim "name" : ty` gives
it. That it agrees with the type the instruction set's description gives
it (`src/isa/prims.sml`) is checked by the `xc1` configurations of the
Basis Library suite, which compile `lib/basis` on the hosts with each
`_prim` replaced by a value of the description's type
(`bin/rune-generate host-basis`). A
`Raise` or a `Fail` never returns, and fits wherever a type is wanted. A
`Let` binds its variable at the type of what it binds; the variables of a
function, a letrec and a handler have the types their binders give them.

A dump shows each function's parameter and result types, `(fn (v1 : 'a
list) : int`, each use of a variable at an instance, `(inst g1 : int ->
int)`, and the type of each payload, `(exnarg v3 : int)`; type variables
are numbered afresh as `'a`, `'b`, ... like the program's.

### Functors compiled once

A functor is compiled once, where it is declared, to a function, and an
application is a call of it, in every mode: a whole compile, a build in
units and `--units --whole` ([plans/functors-units.md](plans/functors-units.md),
M5 to M7). The expansion (below) gives a whole program and a unit's own
applications their copies back in Mid. Until M7 a functor's body was
copied and elaborated again for each application, and the copy was what
was translated (static interpretation). The options that chose the new
way until then, `--functors=functions` and `--datatype-tags=sorted-x`, are
gone rather than kept as no-ops, since no release had them: a compile that
gives one is refused as for any option it does not know.

* **A structure's record.** A structure that reaches a functor is a value
  at run time: a tuple of its slots, each cast to `unit` by `functor_cast`
  (a polymorphic value at `unit` for its type variables, which changes
  nothing of it; an `unsafe_cast` that only a record's slots are given,
  which Lower makes one, the expansion folds and MidLint checks: a value
  cast to `unit` is cast back at its own type) -- its values, its exceptions (their constructors), and the
  constructors, exceptions and primitives a value specification gave as
  values, by name; then each substructure's record, a record of its own, by
  name; at least two slots. A constructor has no slot: tags are the
  datatype's, the same in every instance. A parameter's record holds a
  descriptor after its values for each open constructor (below).
* **The function** (`Elaborate.functorCode`, named `functor F`) takes the
  parameter's record and returns the body's. Its body sets a local variable
  from each slot of the parameter that the body reads (`Translate.bindUsed`,
  the rest of the body made first), then runs the body's declarations,
  which bind locals, not globals (`Elaborate.inBody`), and makes the
  result's record, a substructure that is a record in reach given as it is.
  Each call runs the body again: its exceptions and `ref`s are new (rule
  154). Simplify never puts a functor's function where it is called: that
  is the expansion's, with its budget (below).
* **An application** (`Elaborate.callCode`) is typed by the functor's
  summary alone (rule 54), the type names it made given fresh names, and its
  values and exceptions given fresh variables -- globals at the top level,
  each a definition of its own; in a body, locals, those the rest of the
  body reads -- which the call's result sets. The argument's record
  is made from the argument's environment thinned to the parameter's
  signature, unless a record of the same slots is in reach: a parameter's,
  an application's result or an argument made before, in the same
  top-level declaration (`Elaborate.inReach`), which every mode compiles as
  a whole.
* **Types.** The parameter's types are abstract in the function: `Con`s of
  their names, which `Lower.repOfTy` makes `RAny` (by stamp, not by name,
  for `array`, `vector` and `ref`), and `=` at one is `poly_eq`'s walk. A
  datatype the parameter specifies is given its constructors under the
  name the body sees (`Elaborate.specDatatypes`).
* **Tags by name** (decision D4): every datatype's constructors are
  numbered by their names sorted (`Types.tagNames`), so that a
  specification and the datatype that matches it agree on every tag; but
  `nil, ::` and `LESS, EQUAL, GREATER` keep their declarations' order, by
  their names, for the VM's C (`runtime/value.h`).
* **Open constructors** (D4). A constructor of a parameter's datatype whose
  argument is one of the parameter's abstract types may be laid out flat
  in the argument where the specification reads it boxed. Its descriptor,
  in the parameter's record, is the argument's number of fields (0 for
  boxed), worked out where the program is lowered (`open_layout` of the
  argument's datatype and the constructor's tag, `Elaborate.DescLayout`),
  from the layout the datatype has then, which the expansion may have
  given it since; `ToMid` makes or takes apart such a constructor as the
  specification reads it where the descriptor is 0 (the test is
  `open_boxed`, a primitive of its own), and otherwise calls the
  body's functions for it (`Translate.openFuns`), which see the object
  through `Ty.flat n`, a datatype of the basis whose constructors have `n`
  fields, by a cast of their own (`open_cast`, which Lower makes an
  `unsafe_cast`, and the lints hold to a flat side). Simplify's equality functions leave such a datatype to
  `poly_eq`. Only the constructors the body uses get the functions.
* **Layouts** (D5). A datatype a body declares has the layout its declared
  types give it there, a parameter's type boxed; an instance an
  application's summary names keeps it (`Ty.pinned`, `Ty.layoutOf`),
  whatever its realised types would say. `MidCanon` and a unit's Mid
  (`UnitMid`) carry the fixed layouts and the open datatypes (`Ty.openTypes`)
  with the datatypes they rename and keep.
* **The expansion** (`expand`, `Expand`; M6, decisions D1, D2 and D13)
  gives a program the copies static interpretation makes, in Mid: in a
  whole compile right after `midcanon`, in `--units --whole` right after
  the units' Mid is made one program (the same pass on the same Mid, so
  that the two give the same bytes, S42), and in a build in units on each
  unit, before it is kept for `--units --whole`, where only an application
  of a functor the unit declares is expanded (D2 A).
  - An application carries what a copy substitutes: before the call, a
    `functor_marker` of `()` at a pair of tuples of arrows, which nothing
    reads and Lower makes an `unsafe_cast` -- the
    parameter's type names applied to variables (`Ty.Var`), each to what
    the argument realises it as, and the body's datatypes to the
    application's instances (`Translate.functorTypes`). Being a type of the
    program, it is renamed with it by `MidCanon` and kept by `UnitMid`, and
    substituted in a copy like any other, for the applications inside it.
  - At an application of the top level whose function the program
    defines, the function's body is copied, its names fresh and its types
    substituted as the marker says; a datatype the body declares over
    what is substituted gets a name of its own (after `MidCanon`'s,
    `MidCanon.nextTycon`), and an instance the application named is
    entered again with the constructors the copy gives it, and an
    instance an application in the body makes is the copy's own, as each
    application makes new ones; an open constructor's test (`open_boxed`)
    keeps its first branch, which makes or takes the constructor apart as
    its datatype. The copy's bindings,
    groups of functions and the values its join points give the rest
    become definitions of the top level, as static interpretation's are
    (a local whose type names type variables it does not abstract over
    abstracting over them, so that an alias of it is one); what does not
    fit (a branch both of whose arms go on) stays one definition of the
    record (`--pass-stats=expand` counts them). A definition with an application
    among its steps (a `local` block's `Do`, whose globals it sets) is
    first made definitions the same way, so that the application is one.
  - A slot read from a record whose value is known is that value, and a
    cast through `unit` of it is what was cast, at an instance of its
    scheme for a polymorphic one (`Ty.match`): what substituting made
    trivial goes, in the copy and wherever the application's result is
    read. A value of the top level that is a copy's global at the same
    types gives that global its name, so that a later unit calls the
    copy's function by name.
  - The copies' applications are expanded in turn. A top-level
    application and those in its copies may copy `--functor-budget` Mid
    nodes, the sizes of the functions copied (and 64 deep); past it, an
    application stays a call (D13). The default, 1,000,000, is about
    twice the largest a program known needs (M8, measured whole with
    `--pass-stats=expand`): MLton's 606 files 508,928 (`structure Main =
    Main (...)`, 400 applications expanded), the benchmark set 29,322
    (`fxp`), the compiler 1,405. Within the budget a compile grows with
    the copies it makes, linearly; past it the copies stop. Functors
    nested `D` deep, each body applying the one below twice
    (`tests/perf/compile-funnest*`, whose `scale` lines hold the growth),
    are copied whole up to `D` = 12 (8,191 applications, 507,839 nodes),
    and from 13 on the copies stop at the budget (16,128 applications
    expanded at 13 and at 14); what grows after is the program's
    environment, whose structures nest as the applications do.
  - An instance of a body's datatype that an expanded application named
    is laid out from its realised types, unless an application left a
    call takes it; a datatype a copy declared that such an application
    takes keeps the body's layout. Either way a descriptor is the layout
    Lower gives the datatype (`open_layout`).
  - **Traces.** A copy leaves the frames its call leaves at `-O0`: what its
    declarations run is in a frame of the functor's function (`functor F`)
    called where the application is, and the body's functions keep the
    functor's names (`F.boom`) in a copy as in the function, not the
    applying structure's, so that traces are the same at every level (`make
    check-levels`; [plans/functors.md](plans/functors.md), *Names in
    traces*). A definition of the top level makes no tail call at any
    level (`Simplify`: its value is made with a continuation), so that a
    function inlined there keeps the frame of `<toplevel>`
    (`tests/lang/mod.functor.functions_trace`).
  - **Across units** (M6b). A functor marked to be inlined (`inline
    functor` in a build file, `--inline-functor=F`; docs/build.md) has its
    function's Mid kept in its unit's basis (`MidCodec`,
    `UnitBasis.funcode`), and a later unit expands an application of it
    as it expands its own functors' (`Expand.imported`). Such a unit has a
    usage `inl F`, which holds while the body's Mid is the same.
  - **What a later unit calls.** A unit's basis says which of its globals
    are another global at the same types (`val andb = Word.andb` in a
    copy: `Expand.globalAliases`), and which are functions that apply a
    primitive to their parameter (`val length = size`:
    `Expand.primGlobals`). A later unit's expansion uses the other global
    for the first kind. It makes a call of either kind the primitive's
    application, as `Translate` does for a name bound to a primitive. In a
    whole program the expansion's own aliases do the same, and `Simplify`
    inlines the functions.

## Mid

Mid (`lib/compiler/core/mid.sml`) is the representation the optimisations will work
on: A-normal form with join points, typed in the manner of System F, its
top level a list of definitions (decision D1 of the plan).

* **Atoms:** every operand of a call, a primitive, a constructor or a
  jump is a variable, a global or a constant, and the datatype says so. A
  step (`rhs`) makes one value from atoms; `Let` names it.
* **Join points:** `Join (j, params, body, scope)` binds a label that
  `scope` jumps to, in tail position only. A `Try` of `Lambda` is one
  without parameters, its `Fail` a jump to it; a `Join` of `Lambda` (a
  rule of a match) is one with its parameters; the rest of an expression
  that branches, where more follows it, is one whose parameter is the
  value.
* **`Handle`** is a region: its body and handler are in tail position of
  it, and a jump out of the body leaves it. A call in tail position of the
  body is no tail call.
* **The top level** is a list of definitions: `Val` (a global, the value of
  an expression), `Funs` (global functions) and `Do` (an expression run for
  its effect, which sets the globals it lists). `Translate` marks the rest
  of the program after each declaration of the top level (`Lambda.Rest`),
  and `ToMid` splits it there.
* **Functions** take a list of parameters. One of other than one
  parameter (a worker) is only called, with an argument for each, and
  never used as a value.

**Positions.** A `Mark` gives the place in the source of what follows it,
and the functions it was inlined from on the way (decision D7), innermost
first: each one's name and the place it was called from in the next, or in
the function the code is in, for the last -- or no place, where it was
called in tail position and so took the place of the next, as a tail
call's frame does. The line table carries them (the frames of
[bytecode.md](bytecode.md)), so that a trace shows the frames the calls
would have left.

**Types.** Every binder says its type, and a polymorphic one the type
variables it abstracts over; every use of a variable gives the types it is
used at, one for each. A binder abstracts over the generic variables of its
type that no binder around it abstracts over, where the elaborator could
have generalised them: a variable of the program or a function; a variable
`ToMid` makes never. `Lambda`'s `Inst` gives the types a use is at.

### What a `Mid` keeps

`MidLint` checks, after `mid`:

* **Scope:** every variable is used where its binder is in scope; every
  global used is defined, once, by a definition of the top level.
* **Unique stamps:** every binder's stamp is bound once in the program.
* **Join points:** a jump is to a join point in scope, never to one of a
  function around the jump's own, and with an argument for each parameter.
* **Types:** each expression is checked against the type its context wants
  -- the function's result, the global's type, `unit` for a `Do` -- and each
  step's type is found from its atoms, so nothing is inferred. A use of a
  variable gives as many types as its binder abstracts over, and has the
  type of its scheme at them. A type variable where nothing abstracts over
  it is a type of its own, equal only to itself: the lint does not check
  that type variables are in scope.
* **Calls:** a function of other than one parameter is only called, with
  an argument for each, and never used as a value.
* **What its types alone do not say:** constants, primitives, exceptions'
  payloads and the casts the compiler makes, as in `Lambda` (`IrRules`;
  above). An exception's copies keep their argument's type through every
  pass that copies code, so the payload's rule holds after the first.
* **A `Do`** sets each global it lists on every way of it that returns:
  one that always raises sets none (after `simplify`, a `Do` whose
  expression raises still lists them), and a handler's way is the
  handler's alone. A global a function sets is the exception: a dynamic
  module's slots are set by the function the runtime is given, at the load
  and at each reload (`Translate`, `RuneDynamic.take`; a `dynamic_cast` of
  each slot from `unit`), which `Lift` may take out of the `Do`.
* **Casts** (D3): no value cast to `unit` is
  cast back to another ground type. A record's slot is cast to `unit` and
  back; where the expansion knows the slot's value, a cast left between two
  ground types that differ is a bug of the expansion.

It keeps its tables in hash tables, and what is in scope in one table,
entered and left as it walks: stamps' being unique, which it checks, makes
that the same as a map for each scope, at about 40% of its cost
(plans/correctness/linting.md, M2). After `midcanon` it is not run again:
`MidCanon.checkRenaming` checks that what `midcanon` made is what it was
given with each name of each kind renamed by a bijection -- stamps, type
names that are not built in, type variables -- node for node, and each
datatype entered again under its new name, its constructors, layout and
openness the old one's; so it keeps what `MidLint` checked after `mid`. The
units' `Mid` that `--units --whole` concatenates is linted by `MidLint`
(`midconcat`), since a unit taken from the cache was not.

### Mid as text

`MidText.show` prints a program (`--dump-after=mid`), and `MidText.parse`
reads it back (`--read-mid`), so that a pass can be tested on a small
program written by hand. The grammar is at the head of
`lib/compiler/core/midtext.sml`:

* S-expressions, with types written as in SML; a record of one field is
  `{int}`.
* Variables, globals, join points and type variables are numbered afresh in
  the order they appear (`v1`, `g1`, `j1`, `'a`, and `'_a` for a type
  variable no type was found for).
* A type name is written as it is, with `/N` where two would clash; a
  datatype, or a type without constructors, that is not built in is
  declared at the head.
* A constant of the type its kind gives it is written bare; others as
  `(0w5 : word8)`.
* A type of more than `MidText.bigType` (1000) nodes as a tree is declared
  at the head as an abbreviation, `(type %N TYPE)`, after the
  abbreviations of its parts, and written `%N` where it is: a type of 2^n
  nodes as a tree, which the IR shares, is written in some n
  abbreviations (performance M4).
* Positions are written only with `--mid-roundtrip`, as `(at FILE START STOP
  FRAME ... EXP)`, where a frame is `(in "NAME" "FILE" START STOP)`, or `(in
  "NAME")` for one called in tail position; comments are SML's.

## Matches

The final `Match` raise carries a `Mark` for its `case` or `fn` expression,
or the declared function location; a `Bind` raise carries the binding pattern's
location. Both compilation strategies keep that mark, so failure locations and
inlined function frames agree across optimization levels.

`MatchComp` compiles a match two ways:

* **Rule by rule** (at `-O0`, for a match of one rule, and where a tree
  would grow too big): each rule's tests in turn, a failing one a `Fail`
  to the next rule's `Try`.
* **As a decision tree** (the optional pass `trees`, from `-O1`, after
  Maranget 2008): the rules are a matrix of patterns against the values in
  hand. The first row's first pattern that tests something picks the
  value to test; the rows are split by what the test finds -- by
  constructor for a datatype, yes or no for an exception or a constant,
  none for a tuple, a record or a `ref`, whose parts become values in hand
  -- and the first row whose patterns are all wild matches. No value is
  tested twice on a way through, and where the rows name every
  constructor of a datatype the last one is what is left, untested
  (decision D14). A column of strings written as constants, where it
  names six or more, is split by all of them at once: the value is found
  by its length (`string_size`, tests of `imm_eq`, halved by `int_lt` where
  there are many lengths), then compared with each string of that length,
  or, where they are eight or more, told apart by the character at the
  place they differ most (`string_sub`), and compared with the one left;
  the rows that name none are a join point the misses jump to
  ([plans/performance.md](plans/performance.md), M5). Each rule's body is a `Join` whose parameters are its
  variables, so that a body reached on several ways is not copied; the
  leaves `Jump` to it. An exception's constructor may be another's under
  another name, so a row of another constructor is still tested where
  one matched.

## The optimisations of Mid

Both keep what the program does -- what it prints, how it exits, which
exception it raises first -- but may allocate less. What a primitive may do
is in its description (`src/isa/stack.sml`): one that may raise, write the
heap, call the system, save an image or make a new world is not
`Prims.removable`, and is kept where nothing uses its value. An
application is never removable: nothing is known yet of what a function
does.

* **`shake`** (tree shaking): the roots are the `Do`s and every `Val` whose
  expression may do more than make its value (a call, a primitive that is
  not removable, a raise, a global set); every global a root uses is
  reached, and every one their definitions use. The rest goes, a function
  of a group alone. The whole pass is one rewrite for `--fuel`, since a
  definition kept of those that go would use one that went. Before it, a
  global bound to another -- `val foldl = foldl` in `structure List` -- is
  the other at every use, at the types the use gives it (M12), so that
  the passes that know a function of the top level know it through the
  alias: `List.foldl f b l` is then a call of the worker, which
  `specialise` copies for `f`.
* **`lift`** (lambda lifting): a group of local functions none of which
  escapes -- each is only ever called, by name -- becomes a group of the
  top level. What the group captured it is given instead, as parameters
  before its own, and every call passes it on; what a function of another
  lifted group is given counts as captured. What it is given must abstract
  over no type variables; the lifted functions abstract over the type
  variables of the functions around them that they name, and every call
  gives them as themselves. No closure of them is made, and every call of
  them is a known call.
* **`workers`** (workers and wrappers, decision D9): a function of the top
  level with a parameter that is a tuple it only takes apart, or whose
  body only makes a function and returns it, n deep (curried), becomes a
  worker,
  which takes all its arguments as parameters and does what the function
  did, and a wrapper -- the function as it was, which calls the worker --
  for its uses as a value. A call of a flattened function calls the worker
  with the fields of that argument, which `simplify` then finds where the
  tuple was made; a call of a curried one given all its arguments, each
  partial application used once, by the next, down the same straight line,
  calls the worker, and the partial applications, which only made
  closures, go. A worker is named as its function, for traces. A field of
  a flattened parameter that is itself a tuple the function only takes
  apart, wherever it takes it, is flattened too, and so on, and a variable
  bound to the parameter or to such a field is the same
  ([plans/performance.md](plans/performance.md), M8): a function of two
  vectors of three reals takes six reals.
* **`simplify`** (shrinking, after Appel and Jim): three rounds over each
  definition, each after a census of the uses of every variable and jumps
  to every join point. A variable bound to an atom is the atom, unless it
  abstracts over type variables; a step nothing uses goes where it is
  removable; a field of a tuple, the argument or tag of a constructor made
  in the same function, and an `If` on a known bool, are known; a primitive
  of int, word or char constants is folded at the target's precision
  (`Target.t`'s `intBits`), its divisions among them (functors-units M1),
  unless it would raise -- a division by 0, an overflow; `=` of a type whose
  values are never in the heap -- int, word, char, and a datatype whose
  constructors are all nullary -- is `imm_eq`, which compares tags and
  bits (M11); `=` of a ref or an array, or where one side is a nullary
  constructor (`l = []`), which no value in the heap equals, is `ptr_eq`,
  and `=` of strings `string_eq`, which compares lengths and bytes and
  walks nothing else ([plans/performance.md](plans/performance.md), M5); a join point nothing
  jumps to goes, and one jumped to once is put where the jump is, unless
  the jump is in a handler's region the join point is not; a function
  nothing uses goes, and one called once, where it is made and not from a
  function inside it, is put where the call is -- its returns jumps to a
  join point for what followed the call; a function that only calls
  another with its parameter is the other (eta). A join point that tests
  its one parameter, a bool, where a jump gives it a constant, becomes one
  for each branch, which those jumps go to (`andalso` and `orelse` as
  branches); one of one parameter whose body is small, where a jump gives
  it a nullary constructor, is copied there, where its tests of the tag
  then fold (a case of an inlined `compare`); a raise in a handler's
  region, in the region's own code, is a jump to the handler, made a join
  point. A join point of a parameter that is a tuple its body only takes
  apart, where some jump gives it a tuple made there, has the tuple's
  fields as its parameters instead: each jump gives the parts, or the
  fields of what it gives, and the tuple goes
  ([plans/performance.md](plans/performance.md), M8). A tuple or a
  constructor bound to a variable that is returned at once is made in the
  return, and a join point that only returns its parameter is a return at
  each jump to it, so that what a function returns is made in its returns
  (`lower`'s results in globals, below). What a rewrite makes is added to the round's census, rather than
  a census taken again of all around it -- a use counted more than there
  is only keeps what could go. Stamps being unique, the census and what a
  round knows are tables (`IntTable`), which forget nothing, and a round
  that rewrites nothing is the last.
* **`equality`** (in `simplify`, from `-O2`;
  [plans/performance.md](plans/performance.md), M5, D7 C): `=` of a
  datatype at a type with no type variable, or of a tuple of such parts, is
  a call of a function made for that type, as MLton's poly-equal pass makes
  them: identity first, in a wrapper small enough to be put where it is
  called, then in a worker the tags, then each field by its own type --
  `imm_eq`, `ptr_eq`, `string_eq`, the function of its type, or `poly_eq`
  where the type is not known. Such a comparison is compiled code: the
  limit of `--equality-work` on the runtime's walk does not stop it.
* **`refs`** ([plans/performance.md](plans/performance.md), M8): a
  parameter of a function of the top level that is a ref the function only
  reads and sets, and gives on as it is to its own calls of itself in tail
  position -- a loop's counter -- is its value in a copy of the function: a
  read is the value it holds there, a set the value from there on, a join
  point is given it as a parameter, and the call of itself gives what it
  holds then. A call that gives such parameters refs made for it alone --
  made in its function, not in a function inside, and used by that call
  only -- calls the copy for those parameters with what each was made of,
  and the refs are not made; the copies' own calls are rewritten so in
  turn. A ref used under a handler is left, since a raise would leave its
  value where the handler cannot see it.
* **`inline`** (in `simplify`, M10): a call of a function of the top level
  of no more than 12 nodes that does not call itself, and does not always
  raise -- a call on the way to an error costs nothing worth saving -- is
  its body, copied at the types of the call, within a budget of growth of
  each definition of about its own size; a function of the top level
  named once, by a call, is put there whatever its size, and what is left
  of it goes (`shake`, again). A call whose value goes on becomes a join
  point for what follows, which the body's returns jump to. The body's
  positions gain a frame of the function (see *Positions*): none where the
  call was in tail position and not in a handler's region -- a tail call
  -- and the place of the call elsewhere, where the calls in tail position
  of the body are then marked as made from that place, since their frames
  would have taken the place of the function's. Bodies are taken as they
  are once simplified, where the definition came first; a function that is
  small once simplified may be put where it is called too, whatever it was
  before (M8: a worker's body shrinks by the copies of its parameters).
  A function that makes functions and returns them, alone or in a tuple
  -- a record of closures made at each call -- may be of 24 nodes (M8):
  put where it is called, the functions it makes are known there. A local
  function
  small enough is put where it is called too, in the scope of its `Fun`,
  where what it names is in scope (M12).
* **`specialise`** (in `simplify`, M10): a function of the top level of no
  more than 64 nodes that calls itself, each time passing some parameters
  of function type on unchanged, is copied for a call that gives those
  functions of the top level, at types with no type variable of a scheme:
  in the copy they are known, so their calls are known calls, or inlined
  (item 6 of [plans/performance.md](plans/performance.md)). One copy for
  each function, types and functions given, made where the first such call
  is, simplified after the definition it is in and put before it. A local
  function given, alone in its group, of closed types, that does not name
  itself, where the copy only calls it, is given too (M8): its code becomes
  a function of the top level of what it captured and its parameter, the
  copy calls that, given what it captured as parameters after its own, and
  the call gives them, so that the closure is not made; such copies are
  made two deep at most, since two functions that give each other local
  functions of their own would make copies for ever. A copy may give such
  a function on, to a function that may be copied for it in turn and only
  calls it: there it is a local function again, of one line that calls
  the code made of it, which the copy made from the copy takes, whatever
  the budget, so that the copy never makes a closure the call did not. From a copy, a function that does not call
  itself is copied too, for all its parameters of function type (M8: the
  loop of MLton's `peek` calls a function with the closures it was given,
  and takes apart what it returns). A copy for local functions grows the
  definition the call is in, within the budget of `inline`; a call that
  finds its copy made already costs nothing.

## Low

Low (`lib/compiler/backend/low.sml`) is what the targets are made from: each
function is blocks with parameters in SSA form (decision D2), and what Mid
leaves implicit is explicit.

* **Closures:** `Lower` converts them as it goes. A function captures the
  variables free in the code it makes of it -- not those of a branch a
  `Switch` leaves out (*Blocks*) -- in the order of their stamps, less
  itself, which it reads as `Self`; captured values are read with `Env i`.
  The functions of a group capture each other, and those not made yet are
  set after (`SetEnv`): flat closures.
* **Constructors** (`Rep`, `lib/compiler/backend/rep.sml`, M11): one whose declared
  argument is a tuple of two or more is one object of those fields, its
  tag in the header -- `Con` of the fields, and `Field (tag, i, v)` to take
  field `i` -- and one of any other argument boxes it, `Con` of one and
  `Decon`. The choice is the datatype's, the same at every type it is used
  at, so every use of a constructor agrees; a list's `::` is of two fields,
  as the C of the VM makes and walks it. Mid's `Decon` says the datatype it
  takes apart, so that `Lower` can ask. What is made only to be taken apart
  is not made: a tuple used once, by a constructor made of its fields or a
  field taken of it, is its parts; the argument of such a constructor,
  each of whose uses in its function takes a field, is its fields; and a
  use that needs either whole makes it there -- the argument whole is then
  a copy. The parts are variables of the function that binds the tuple: a
  function that captures it is given it whole, made where its closure is,
  and takes it apart.
* **Blocks:** a join point of Mid is a block whose parameters are the join
  point's; an `If` two blocks; a match on a constructor's tag one `IfTag`,
  and three or more of the same value, each in the else of the one before,
  one `Switch` -- where the highest tag is no more than about four times
  their number.
  Every edge goes forward in the order of the blocks, but one: a function
  that calls itself in tail position, where no handler is pushed, is a
  loop -- its entry jumps to a head block whose parameters are the
  function's, and each such call jumps back to the head.
* **Handlers:** a `Handle` is a `Push` of the handler's block, the blocks of
  its region, and that block, whose one parameter is the exception; a jump
  or a return out of a region pops what it leaves, and a call in tail
  position of a region is no tail call.
* **Copies:** a variable Mid binds to another is the other, and one bound
  to a constant, a global or a captured value is read again where it is
  used.
* **Known calls:** a call of a function of the top level is `CallK` (and
  `TailCallK`), by the function's id, with an argument for each of its
  parameters and no closure: such a function captures nothing and names
  itself as its global. A function has a list of parameters; one of other
  than one parameter is only ever called so, and is made no closure.
* **Results in globals** (the optional pass `results`, from `-O1`, for the
  whole program and not where the debugger reads it;
  [plans/performance.md](plans/performance.md), M8): a function of the top
  level never used as a value, each of whose returns is a tuple made there
  or a tail call of another such function of as many fields, every call of
  which only takes its fields, returns the first field and sets a global
  to each of the others some call takes -- the same globals for every such
  function of as many fields -- which the call reads at once (`Slot`, an
  operation of Low that is read where it is, never again where it is
  used): the tuple is not made. Likewise a function of a datatype each of
  whose returns is a constructor made there or a tail call of another such
  function of the datatype, every call of which only asks the constructor
  (`ConTag`, `ptr_eq` with a nullary one) and takes its argument: it
  returns the constructor's tag as a nullary constructor's, and the
  argument, or its fields, in the datatype's globals, which the program
  sets to () before anything runs, since a call reads them whatever the
  constructor.

### What a `Low` keeps

After every `lower`, at level 0, always on (*Levels*), `LowLint.results` checks what results
in globals keep, from what `Lower` says of which functions return so
(`Pipeline.lowered`): a read of such a global (`Slot`) follows, in its
block, a known call of a function that leaves its results there, with
only other such reads and positions between; a function of n fields
returns, in each block, what the block's last call gave, a call of
another of n, or a value after which it has set, since that call, each
global of its fields that some call reads; and it calls in tail position
only another of n, never through a closure. It costs 0.1 to 0.6% of a
compile (plans/correctness/linting.md, E9).

`LowLint` checks, after `lower` (what is defined on every way to a use by
dominance, over a function's blocks cut at each push, a walk up the tree
of dominators from each use, where a map of what is available, filtered at
every join, cost blocks times variables: 26M instructions on HaMLet's Low
against 234M; plans/correctness/linting.md, M2):

* **SSA:** every variable is defined once in its function and on every way
  to each of its uses; a handler's block sees only what was defined where
  it was pushed, since its region may raise anywhere.
* **Blocks:** a jump goes to a block of its function, with an argument for
  each parameter, and forward -- but a jump back to the head of a loop,
  where everything that reaches the head is defined, so that only its
  parameters change on the way round; a handler's block has one parameter.
* **Handlers:** every way into a block has the same handlers pushed, and a
  function returns, or calls in tail position, with none.
* **Calls:** a known call is of a function of the program, with as many
  arguments as it has parameters; a closure is only of a function of one.
* **Closures:** a closure is given a value for each its function captures,
  and the function reads each of them (`Env i`, `i` below their number).
  Each function numbers its variables from 0, so one of another function
  is to *SSA* one of its own; a value captured and never read is what
  shows that it read the value so instead.
* **Representations:** a variable holds what its representation says,
  where something else says too: the operation that makes it, a primitive
  that takes it (`Prims.repsOf`, made from the primitive's type in
  `src/isa/prims.sml`, which `runeisa` reads as an SML type: `PrimTys`),
  a field of a tuple or a constructor made in the
  function, a block's or a known function's parameter it is passed to,
  what a closure's function reads of a value it captures, and an
  exception. A value goes from where it is made to where it is taken,
  under the order x <= x, x <= any, con0 <= con, ptr <= con: what is
  below is right; what is above is a downcast -- any into a typed
  representation, con into con0 or ptr -- which only ML's types justify,
  trusted and counted (`--pass-stats`: `, N downcasts` on the line of
  `lower`); anything else is a breach (plans/correctness/linting.md, D8
  and M6).

`LowShapes` (`lib/compiler/backend/lowshapes.sml`), after `lower` at
the same level (`shapes`; plans/correctness/linting.md, D14 and M6),
checks the shapes of the values: a tuple of n fields, a value of a
datatype (by its stamp), a closure, an object of another kind, no object,
or unknown. Each variable has the one its Mid type says, which `Lower`
keeps where the check runs (`Lower.lastTys`), but for one it shares
between types on purpose (`defAny`), or else the one the operation that
makes it says:

* what makes a variable agrees with its type, and what a jump, a known
  call, a closure's captured value or a field read of a tuple or
  constructor made in the function passes with where it goes;
* a `Select` is of a tuple of more fields than its index, a `Call` of a
  closure, `ConTag`, `IfTag` and `Switch` of a datatype's value;
* a `Field` and a `Decon` are of a datatype's value; every `Con` of one
  constructor in the program has one number of fields, which every
  `Field` of it is below, two or more, and every `Decon` is 1 of: the
  layout's producers held to its consumers, wherever they are -- what a
  constructor built boxed in one function and taken apart flat in another
  breaks -- and each field a `Con` makes, a `Field` reads or a `Decon`
  takes agrees with what the datatype declares of it;
* a `Field` and a `Decon` of a datatype of more than one constructor are
  of a value whose tag is known to be theirs where they are: a test of its
  tag comes first on every way there (`IfTag`, `Switch`, or `ConTag`
  compared with a constant or with another's `ConTag`), or that
  constructor made it, or every jump to the block's parameter it is passes
  such a value; a datatype whose layout a functor's argument gives is left
  out.

`--pass-stats` counts what it checked against a known shape and what it
did not (`, N shaped, M unshaped`); `RUNE_SHAPES=1` runs it at every
level, `0` at none.

Low carries no types, but what each variable holds, as a representation
(`Low.rep`, from Mid's types in `Lower.repOfTy`; plans/jit.md, M8): an
int, a word, a real, a char, a nullary constructor, a value in the heap,
either, unit, or anything (a polymorphic variable, or one nothing is said
of). The dump lists them after a function's header (`reps v3:int ...`),
the variables of representation anything left out.

### The stack target

`Stack` makes `runevm-stack`'s bytecode from Low (`Target.stack` says what the
middle end may ask of it):

* **Trees:** a value used once, by an instruction of its own block that
  takes it in the order the stack gives it, stays on the stack; it is
  computed where that instruction's operands are pushed, with nothing
  between them that has an effect. Constants, globals, captured values and
  the running closure are pushed where they are used.
* **Locals:** every other value has one, shared by linear scan: since every
  edge goes forward -- but the jump back to a loop's head, across which only
  the head's parameters live -- a value lives from where it is made to its
  last use in the order of the blocks. An argument of a jump already in
  its parameter's local is not moved. The parameters are locals 0 to n-1;
  a known call is its arguments pushed and `CALLK`; a `Switch` is `SWITCH`
  and its table of `JUMP`s, one for each tag below the highest it tests.
* **Jumps:** the arguments of a jump are pushed and stored into the block's
  parameters from the last, so they move in parallel; a jump to the next
  block falls through, one to a block that only jumps on goes on, and one
  to a block that only returns its parameter returns.
* **Positions** are noted where they change; a tree keeps the position it
  was made at. A position's frames are a row of the program's table of
  inlined frames, each made once (`Code.inlineIdx`).

**The check of the stack code** (`StackCheck`, `src/driver/stackcheck.sml`;
[plans/correctness/linting.md](plans/correctness/linting.md), D11 and M10)
runs from level 2 of the lint (*Levels*), after `stack` on a whole program
and on the program `Link` makes of units of stack code, or at every level
where `RUNE_RBCCHECK=1` says (`0`: at none): the code as its file has it (`Emit.serialize`), read back
as `runevm-stack`'s loader reads it, which refuses what the loader refuses
with its message (`Rbc.read`), and held to what `runeopt` relies on
(`RbcCheck`; [native.md](native.md), *What the translation relies on*):
the stack's height and the handlers' depth agree on every path into an
instruction, no path underflows, leaves its function or runs off its end,
no `RET` or `TAILCALL` has a handler of its function installed, and every
function is given one arity. `Rbc` and `RbcCheck` are `runeopt`'s, built
with the driver (`rune.build`) and not with the compiler library, which
runs no check of the stack code. A refusal is a bug of the compiler, "lint
after rbccheck: ..."; `--pass-stats` counts it as `rbccheck`.
`RUNE_RBCCHECK_INJECT=KIND` corrupts the code the check is given in one of
six ways, which its tests (`stack/@rbccheck-*`) hold it to refusing. Its
cost is linear in the code: about 85 of the VM's instructions for each byte
of the program's file, the file made included, 0.59G for MLton's 6.7 MB
(+14% of a compile of the bootstrap for the stack target).

### The register target

`Regs` makes the register bytecode of `runtime/register` from the same Low
([bytecode.md](bytecode.md), The register bytecode; decision D4):

* **Registers:** every variable has one, shared by linear scan as the
  stack target shares locals -- but only among variables of one
  representation, so that a register holds one kind of value throughout
  (M8); the parameters are registers 0 to n-1. One more, the scratch,
  takes what nothing reads and breaks a cycle of moves, and holds
  anything. What each register holds, the blocks with their parameters'
  registers and the loop heads go into the file's representations
  section ([bytecode.md](bytecode.md), The representations), which the
  VM holds to the code.
* **Calls and primitives:** a call is `CALL`, or `CALLK` with its
  arguments' registers, then `RESULT`; a primitive
  `PRIM` into its register, but one that saves or restores an image
  `PRIMPUSH` then `RESULT`, where an image resumes; a handler's block
  begins with `CATCH`.
* **Jumps** move their arguments into the block's parameters in parallel,
  fall through, or return as the stack target's do.

`make test-register` runs the suites through it and `runtime/register`'s first loop; see
[plans/middle-end.md](plans/middle-end.md), M5, for how it compares with the
stack target.

**`RegVerify`** (`lib/compiler/backend/regverify.sml`) checks the register
code from level 1 of the lint, the boundaries (*Levels*), by its cost: 4.4%
of compiling the compiler, 1.6% of HaMLet, 0.8% of MLton. It runs after
`registers` (`regverify`), so each unit once, when it is compiled
([plans/correctness/linting.md](plans/correctness/linting.md), M8); a unit
taken from the cache was checked when its entry was made, which the
entry's mark says, and `Link` checks the units' interfaces against each
other rather than the whole program again (M9; [units.md](units.md),
*Linking*), which `RUNE_REGVERIFY_LINK` set and not empty asks for too
(`regverify-link`). Its
rules are the tables `runeisa` writes from `src/isa/regs.sml` (`RegCodes`:
what each instruction reads and writes, what it leaves and takes, what
must follow it, which primitives it names), what Lower declares of the
program (each function's result and its closures' captures, each global's
representation, carried in `Code.meta`, `Code.program` and the unit's file),
and a dataflow, one pass over each function:

* **Representations:** a register holds its representation under the order
  x ≤ x, x ≤ any, con0 ≤ con, ptr ≤ con. A write of what is below the
  register's representation is right; of what is above it, a downcast,
  trusted and counted, since only ML's types say what a value read from the
  heap or returned by a polymorphic function is; of anything else, a
  breach. A read that wants a representation is judged the same.
* **Unset:** nothing reads a register not set on every way to the read; at a
  function's entry its parameters are set, and the scratch holds nothing at
  a label.
* **Labels:** a label's state is the meet of the ways in; a jump back goes to a
  loop head of the meta and sets what the head has set; at a loop head and
  a handler's block the registers are what they are declared; the handlers
  pushed are as many on every way in, and none where the frame is left.
* **The order the VM relies on:** `RESULT` right after `CALL`, `CALLK` and
  `PRIMPUSH`, `CATCH` at a handler's start, a `SWITCH`'s table of `JUMP`s,
  only image primitives in `PRIMPUSH` and none in `PRIM`.
* **Calls and closures:** a known call passes the callee's parameters, and
  a known tail call returns what its caller does; a closure is of a function
  of one parameter and captures what its closures do; `ENV` and `SELF` are
  only in a function closures are made of and no known call calls; a
  primitive's arguments and result are what its type says.
* **Tags:** a register's constructor, where a constructor made or a tag
  tested says, and a `FIELD` or `DECON` of another tag is a breach; a tag
  test whose answer is known leaves the other way untaken.

It checks `Regs` and `Link`, not that the code is safe for an untrusted
`.rbc`: that is the VM's ([plans/correctness/vm-verifier.md](plans/correctness/vm-verifier.md)).
`RUNE_REGVERIFY=1` runs it at every level, `off` too, `0` not at all, and `census`
prints what it counted; `RUNE_REGVERIFY_INJECT=KIND` corrupts the code
`Regs` made, before the check, in one of eleven ways, which its tests
(`register/@regverify-*`) hold it to refusing, or in three more what the
unit expects of its imports, which S78 of `tests/incremental/SCENARIOS.md`
holds the link to refusing; a unit so made is not stored in the cache.

## Tests

* **`make test-ir`** (`ir/*` of `tests/runner/tools.sml`): each `tests/ir/NAME.sml`
  is compiled without the Basis Library, and each `tests/ir/NAME.mid` read
  as Mid, with the lint at level 3, Mid's text read back after every stage. The first line asks for a dump
  (`(* dump: --dump-after=PASS *)`), which is compared with `NAME.expected`
  and reviewed line by line like any `.expected` file, or says with what
  the compiler must stop (`(* fail: MESSAGE *)`), for a program a lint must
  refuse.
* **`make check-levels`** (the oracle `levels` of `tests/runner/oracles.sml`): every program of
  `tests/lang` and `tests/perf` compiled to both bytecodes at `-O0` and at
  `-O2`, whole and whole of its units' Mid (`--units --whole`), and to the
  register bytecode in units linked by `Link` (`--units`, its unit files
  kept), with the lint at level 2, and on the stack bytecode Mid's text
  checked against itself (`--mid-roundtrip`). The register bytecode's
  builds at `-O2` and in units are compiled again at level 0: the two must
  be the same bytes, a unit's files and their bases too. Each runs under
  `--checked` (a `DECON` of another constructor than it names stops the
  program), the register bytecode's at tier 2 of the JIT too
  (`--jit=all --jit-tier=2`), and must print and exit as the stack
  bytecode's at `-O0` does, on both streams: traces too, where inlining has
  moved code into another function (`tests/lang/rt.trace_inlined.sml`).
* **The bootstrap** is compiled with `--lint --mid-roundtrip` whenever it is
  built (`bin/rune.rbc`).
* **The lints' negative tests** (plans/correctness/linting.md, M4): each
  rule of each lint refuses what breaks it. A fault made on purpose after a
  stage (`RUNE_FAULT=STAGE:KIND[@N]`, `lib/compiler/backend/fault.sml`, for
  the tests alone: the identity where it is unset) corrupts what the stage
  made, at the `N`-th place of the kind, before the stage's checks see it,
  and says on standard error what it did; the jobs `faults/STAGE:KIND` of
  `tests/runner/tools.sml` (tier `test-ir`) compile `tests/compiler/faults.sml`
  (or, built in units, `faults-dynamic.sml`) at level 2 and want the
  stage's lint to refuse it with the rule's message: a variable out of
  scope, a stamp bound twice, a jump given one argument more, a constant
  of another kind, a payload of another type, a cast of another kind, a
  `Do` that no longer sets a global, ... The rules no fault reaches, and
  the invariant of results, are refused on IR made by hand
  (`compiler/lint-rules`, `tests/compiler/lint-rules.sml`); `RegVerify`'s
  by its own switch (`register/@regverify-*`).
* **`bin/rune-measure bisect-fuel PROGRAM.sml`**: where a program runs otherwise
  at `-O2` than at `-O0`, halving `--fuel` finds the first rewrite that
  breaks it (after Whalley, "Automatic isolation of compiler errors").

## Adding a pass

A pass is a function from one representation to one, run through
`Pass.stage`. It comes with:

* its name, for the options;
* the printer of what it makes, for `--dump-after` (the representation's
  `show`), and its size, for `--pass-stats`;
* the lint of what it makes, and anything new it keeps written down here;
* `Pass.spend` before every rewrite, if it rewrites;
* `Pass.whole` asked before it deletes a binding of the top level or
  counts on seeing every use of one, since with `--units` a later unit may
  name it ([units.md](units.md));
* a test in `tests/ir`, whose expected dump shows what it does.
