# The intermediate representations

What the compiler's intermediate representations are, what every one it
makes keeps, and how to look at them. The plan they come from, and the
ones still to come, is [plans/middle-end.md](plans/middle-end.md).

## The pipeline

| Stage | From | To | Lint |
|---|---|---|---|
| `translate` | the elaborated syntax | `Lambda` (`src/core/lambda.sml`) | `LambdaLint` |
| `mid` | `Lambda` | `Mid` (`src/core/mid.sml`, by `ToMid`) | `MidLint` |
| `shake` | `Mid` | `Mid`, what nothing reaches gone (`src/core/shake.sml`), from `-O1` | `MidLint` |
| `lift` | `Mid` | `Mid`, local functions that never escape made functions of the top level (`src/core/lift.sml`), from `-O1` | `MidLint` |
| `workers` | `Mid` | `Mid`, tupled and curried functions split into workers and wrappers (`src/core/workers.sml`), from `-O1` | `MidLint` |
| `simplify` | `Mid` | `Mid`, shrunk (`src/core/simplify.sml`), from `-O1` | `MidLint` |
| `lower` | `Mid` | `Low` (`src/backend/low.sml`, by `Lower`) | `LowLint` |
| `stack` | `Low` | instruction lists (`src/backend/stack.sml`) | none yet |
| `registers` | `Low` | instruction lists of the register bytecode (`src/backend/regs.sml`), with `--target=registers` | none yet |
| emission | instruction lists | the `.rbc` | |

At `-O0` the code is still generated from `Lambda`, by `Codegen` (stage
`codegen`), the reference the new back end is compared with (decision D10
of the plan): `-O0` and `-O2` must give programs that print, exit and
allocate the same (`make check-levels`).

Each stage runs through `Pass.stage` (`src/util/pass.sml`), which prints
what it is given or makes when asked, checks it with the lint of its
representation, and says what it cost. An optional pass, one that only
optimises, says from which level it runs (`Pass.enabled`): `shake`,
`lift`, `workers` and `simplify`, in that order (see *The optimisations of
Mid*).

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
* **Functions** take a list of parameters. One of other than one
  parameter (a worker) is only called, with an argument for each, and
  never used as a value.

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
  definition kept of those that go would use one that went.
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
  closures, go. A worker is named as its function, for traces.
* **`simplify`** (shrinking, after Appel and Jim): three rounds over each
  definition, each after a census of the uses of every variable and jumps
  to every join point. A variable bound to an atom is the atom, unless it
  abstracts over type variables; a step nothing uses goes where it is
  removable; a field of a tuple, the argument or tag of a constructor made
  in the same function, and an `If` on a known bool, are known; a primitive
  of int, word or char constants is folded at the target's precision
  (`Target.t`'s `intBits`), unless it would raise; a join point nothing
  jumps to goes, and one jumped to once is put where the jump is, unless
  the jump is in a handler's region the join point is not; a function
  nothing uses goes, and one called once, where it is made and not from a
  function inside it, is put where the call is -- its returns jumps to a
  join point for what followed the call; a function that only calls
  another with its parameter is the other (eta). A join point that tests
  its one parameter, a bool, where a jump gives it a constant, becomes one
  for each branch, which those jumps go to (`andalso` and `orelse` as
  branches); a raise in a handler's region, in the region's own code, is a
  jump to the handler, made a join point. What a rewrite makes anew is
  simplified after a census of its own: nothing it binds is used outside
  it, so that census is whole where the round's is stale. Stamps being
  unique, the census and what a round knows are tables (`IntTable`), which
  forget nothing, and a round that rewrites nothing is the last.

## Low

Low (`src/backend/low.sml`) is what the targets are made from: each
function is blocks with parameters in SSA form (decision D2), and what Mid
leaves implicit is explicit.

* **Closures:** `Lower` converts them as it goes. A function captures the
  variables free in it, in the order of their stamps, less itself, which it
  reads as `Self`; captured values are read with `Env i`. The functions of
  a group capture each other, and those not made yet are set after
  (`SetEnv`). These are `Codegen`'s flat closures, so a program allocates
  what it did.
* **Blocks:** a join point of Mid is a block whose parameters are the join
  point's; an `If` two blocks; a match on a constructor's tag one `IfTag`.
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

### What a `Low` keeps

`LowLint` checks, after `lower`:

* **SSA:** every variable is defined once in the program and on every way
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

Low is untyped: the types become representations after closure
conversion, which Low will carry when a target needs them (M11).

### The stack target

`Stack` makes `runevm`'s bytecode from Low (`Target.stack` says what the
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
  its parameter's local is not moved. The parameters are locals 0 to n-1; a known call
  is its arguments pushed and `CALLK`.
* **Jumps:** the arguments of a jump are pushed and stored into the block's
  parameters from the last, so they move in parallel; a jump to the next
  block falls through, one to a block that only jumps on goes on, and one
  to a block that only returns its parameter returns.
* **Positions** are noted where they change; a tree keeps the position it
  was made at.

### The register target

`Regs` makes the register bytecode of `vm/new` from the same Low
([bytecode.md](bytecode.md), The register bytecode; decision D4):

* **Registers:** every variable has one, shared by linear scan as the
  stack target shares locals; the parameters are registers 0 to n-1. One more, the
  scratch, takes what nothing reads and breaks a cycle of moves.
* **Calls and primitives:** a call is `CALL`, or `CALLK` with its
  arguments' registers, then `RESULT`; a primitive
  `PRIM` into its register, but one that saves or restores an image
  `PRIMPUSH` then `RESULT`, where an image resumes; a handler's block
  begins with `CATCH`.
* **Jumps** move their arguments into the block's parameters in parallel,
  fall through, or return as the stack target's do.

`make test-new` runs the suites through it and `vm/new`'s first loop; see
[plans/middle-end.md](plans/middle-end.md), M5, for how it compares with the
stack target.

## Tests

* **`make test-ir`** (`tests/ir/run-ir-tests.sh`): each `tests/ir/NAME.sml`
  is compiled without the Basis Library, and each `tests/ir/NAME.mid` read
  as Mid, with the lint on. The first line asks for a dump
  (`(* dump: --dump-after=PASS *)`), which is compared with `NAME.expected`
  and reviewed line by line like any `.expected` file, or says with what
  the compiler must stop (`(* fail: MESSAGE *)`), for a program a lint must
  refuse.
* **`make check-levels`** (`scripts/check-levels.sh`): every program of
  `tests/lang` and `tests/perf` compiled at `-O0` (`Codegen`), at `-O2`,
  and at `-O2` with no optional pass (`--passes=`, the new back end alone),
  with the lint on and Mid's text checked against itself
  (`--mid-roundtrip`). All three run, and must print and exit the same;
  the back end alone must also allocate what `-O0`'s code does (the bytes
  and objects of `runevm --count`), where the optimisations may allocate
  less. A program that allocates otherwise for a reason is listed with it
  in `scripts/check-levels.alloc`.
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
