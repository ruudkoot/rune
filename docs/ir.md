# The intermediate representations

What the compiler's intermediate representations are, what every one it
makes keeps, and how to look at them. The plan they come from, and the
ones still to come, is [plans/middle-end.md](plans/middle-end.md).

## The pipeline

| Stage | From | To | Lint |
|---|---|---|---|
| `translate` | the elaborated syntax | `Lambda` (`src/core/lambda.sml`) | `LambdaLint` |
| `codegen` | `Lambda` | instruction lists (`src/backend/codegen.sml`) | none yet |
| emission | instruction lists | the `.rbc` | |

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

## Tests

* **`make test-ir`** (`tests/ir/run-ir-tests.sh`): each `tests/ir/NAME.sml`
  is compiled without the Basis Library, with the lint on, and the dump its
  first line asks for (`(* dump: --dump-after=PASS *)`) is compared with
  `NAME.expected`, which is reviewed line by line like any `.expected` file.
* **`make check-levels`** (`scripts/check-levels.sh`): every program of
  `tests/lang` and `tests/perf` compiled at `-O0` and at `-O2`, with the
  lint on. Where the two bytecodes differ, both run and must print and exit
  the same.
* **The bootstrap** is compiled with `--lint` whenever it is built
  (`bin/rune.rbc`).
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
