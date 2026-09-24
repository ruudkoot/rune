# The intermediate representations

What the compiler's intermediate representations are, what every one it
makes keeps, and how to look at them. The plan they come from, and the
ones still to come, is [plans/middle-end.md](plans/middle-end.md).

## The pipeline

| Stage | From | To | Lint |
|---|---|---|---|
| `translate` | the elaborated syntax | `Lambda` (`src/core/lambda.sml`) | `LambdaLint` |
| `mid` | `Lambda` | `Mid` (`src/core/mid.sml`, by `ToMid`) | `MidLint` |
| `codegen` | `Lambda` | instruction lists (`src/backend/codegen.sml`) | none yet |
| emission | instruction lists | the `.rbc` | |

**Mid is launched dark** (the plan's M3): the code is still generated from
`Lambda`, and Mid is made only where it is checked (`--lint`, which
`make check` gives every program), printed, or named in `--passes`, and
never at `-O0`. Made on every compile, it cost 8% of the instructions of
compiling `hello.sml` on `runevm` and 13% of the bootstrap's; the back end
of M4 generates code from it.

Each stage runs through `Pass.stage` (`src/util/pass.sml`), which prints
what it is given or makes when asked, checks it with the lint of its
representation, and says what it cost. An optional pass, one that only
optimises, says from which level it runs (`Pass.enabled`); there is none
yet.

## Options

| Option | What it does |
|---|---|
| `-O0`, `-O1`, `-O2` | the level; `-O1` when none is given |
| `--passes=P,...` | run these optional passes, whatever the level |
| `--dump-before=P`, `--dump-after=P` | print what the pass `P` is given or makes (`all`: every pass); `--dump-lambda` and `--dump-code` are `--dump-after=translate` and `--dump-after=codegen` |
| `--lint` | check what every pass makes, and stop with `Error.Bug`, which names the pass, at the first breach |
| `--fuel=N` | make no more than `N` rewrites: a pass that rewrites asks `Pass.spend` before each |
| `--pass-stats` | the size of what every pass makes and its time, on standard error |
| `--read-mid FILE` | read a Mid program in the text a dump prints, and make and check it as the pass `mid` would (there is no bytecode from Mid yet) |
| `--mid-roundtrip` | check that Mid printed with its positions, read and printed again is the same |

**A dump** (`Lambda.show`) prints one node to a line, its parts indented
below it unless they are all atoms, and leaves positions out. Variables
and globals are numbered afresh (`v1`, `g1`, ...) in the order they appear,
so that an expected dump does not change with stamps made elsewhere.

## What a `Lambda` keeps

`LambdaLint` checks, after `translate`:

* **Scope:** every variable is used where a binder of it is in scope: a
  function's parameter, a `Let`, a `LetRec`, a `Handle`.
* **Unique stamps:** every binder's stamp is bound once in the whole
  program. The code generator relies on it, since its slots are by stamp.
* **`Fail`:** every `Fail` is in tail position of the body of a `Try` of the
  same function, where it jumps to the `Try`'s fallback with the stack as
  the `Try` found it. Tail position runs through a `Let`'s body, the second
  of a `Seq`, both arms of an `If`, the fallback of an inner `Try`, a
  handler and a mark.
* **`LetRec`:** every right-hand side is a function.
* **Types:** it is well typed, as below.

A breach is a bug of the compiler, never of the program.

### Types

`Lambda` is typed (decision D3 of the plan): the lint finds the type of
every node from its parts, and a mistake of the translation or the match
compiler shows as a node whose parts do not fit. The types are `Ty.ty`
(`src/core/ty.sml`), made from the elaborator's once it has finished:

* **Generic and free variables:** `Gen` is a variable of a scheme; `Var` one
  no type was ever found for, equal only to itself.
* **Records** are tuples of their fields in the order of their labels.
* **Abstract types** are what they stand for: an opaque signature hides a
  type from the program, not from the compiler.
* **`ExnCon`** is the type of an exception constructor; `exn` that of an
  exception.

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
(`tests/basis/host/gen-host-basis.sh`). A
`Raise` or a `Fail` never returns, and fits wherever a type is wanted. A
`Let` binds its variable at the type of what it binds; the variables of a
function, a letrec and a handler have the types their binders give them.

A dump shows each function's parameter and result types, `(fn (v1 : 'a
list) : int`, each use of a variable at an instance, `(inst g1 : int ->
int)`, and the type of each payload, `(exnarg v3 : int)`; type variables
are numbered afresh as `'a`, `'b`, ... like the program's.

## Mid

Mid (`src/core/mid.sml`) is the representation the optimisations will work
on: A-normal form with join points, typed in the manner of System F, its
top level a list of definitions (decision D1 of the plan).

* **Atoms:** every operand of a call, a primitive, a constructor or a
  jump is a variable, a global or a constant, and the datatype says so. A
  step (`rhs`) makes one value from atoms; `Let` names it.
* **Join points:** `Join (j, params, body, scope)` binds a label that
  `scope` jumps to, in tail position only. A `Try` of `Lambda` is one
  without parameters, its `Fail` a jump to it; the rest of an expression
  that branches, where more follows it, is one whose parameter is the
  value.
* **`Handle`** is a region: its body and handler are in tail position of
  it, and a jump out of the body leaves it. A call in tail position of the
  body is no tail call.
* **The top level** is a list of definitions: `Val` (a global, the value of
  an expression), `Funs` (global functions) and `Do` (an expression run for
  its effect, which sets the globals it lists). `Translate` marks the rest
  of the program after each declaration of the top level (`Lambda.Rest`,
  which the code generator passes through), and `ToMid` splits it there.
* **Functions** take a list of parameters; until the calling convention
  (M8) each takes one.

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

### Mid as text

`MidText.show` prints a program (`--dump-after=mid`), and `MidText.parse`
reads it back (`--read-mid`), so that a pass can be tested on a small
program written by hand. The grammar is at the head of
`src/core/midtext.sml`:

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
* Positions are written only with `--mid-roundtrip`, as `(at FILE START STOP
  EXP)`; comments are SML's.

## Tests

* **`make test-ir`** (`tests/ir/run-ir-tests.sh`): each `tests/ir/NAME.sml`
  is compiled without the Basis Library, and each `tests/ir/NAME.mid` read
  as Mid, with the lint on. The first line asks for a dump
  (`(* dump: --dump-after=PASS *)`), which is compared with `NAME.expected`
  and reviewed line by line like any `.expected` file, or says with what
  the compiler must stop (`(* fail: MESSAGE *)`), for a program a lint must
  refuse.
* **`make check-levels`** (`scripts/check-levels.sh`): every program of
  `tests/lang` and `tests/perf` compiled at `-O0` and at `-O2`, with the
  lint on and Mid's text checked against itself (`--mid-roundtrip`). Where
  the two bytecodes differ, both run and must print and exit the same.
* **The bootstrap** is compiled with `--lint --mid-roundtrip` whenever it is
  built (`bin/rune.rbc`).
* **`scripts/bisect-fuel.sh PROGRAM.sml`**: where a program runs otherwise
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
* a test in `tests/ir`, whose expected dump shows what it does.
