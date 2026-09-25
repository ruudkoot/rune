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

`-O0` is the same stages with no optional pass; `-O0` and `-O2` must give
programs that print and exit the same, traces included (`make
check-levels`). The first code generator, of `Lambda`, was `-O0` and the
reference the new back end was compared with until M10 (decision D10 of
the plan).

Each stage runs through `Pass.stage` (`src/util/pass.sml`), which prints
what it is given or makes when asked, checks it with the lint of its
representation, and says what it cost. An optional pass, one that only
optimises, says from which level it runs (`Pass.enabled`): `trees`, which
is how `translate` compiles a match (see *Matches*), then `shake`, `lift`,
`workers` and `simplify`, in that order, and `shake` again where `simplify`
inlined (see *The optimisations of Mid*); `inline` and `specialise` are
what `simplify` does besides shrinking, each of which may be left out.

## Options

| Option | What it does |
|---|---|
| `-O0`, `-O1`, `-O2` | the level; `-O1` when none is given |
| `--passes=P,...` | run these optional passes, whatever the level |
| `--dump-before=P`, `--dump-after=P` | print what the pass `P` is given or makes (`all`: every pass); `--dump-lambda` and `--dump-code` are `--dump-after=translate` and `--dump-after=stack` (`registers` with `--target=registers`) |
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
  FRAME ... EXP)`, where a frame is `(in "NAME" "FILE" START STOP)`, or `(in
  "NAME")` for one called in tail position; comments are SML's.

## Matches

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
  (decision D14). Each rule's body is a `Join` whose parameters are its
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
  (`Target.t`'s `intBits`), unless it would raise; `=` of a type whose
  values are never in the heap -- int, word, char, and a datatype whose
  constructors are all nullary -- is `imm_eq`, which compares tags and
  bits (M11); a join point nothing
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
  point. What a rewrite makes is added to the round's census, rather than
  a census taken again of all around it -- a use counted more than there
  is only keeps what could go. Stamps being unique, the census and what a
  round knows are tables (`IntTable`), which forget nothing, and a round
  that rewrites nothing is the last.
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
  are once simplified, where the definition came first.
* **`specialise`** (in `simplify`, M10): a function of the top level of no
  more than 64 nodes that calls itself, each time passing some parameters
  of function type on unchanged, is copied for a call that gives those
  functions of the top level, at types with no type variable of a scheme:
  in the copy they are known, so their calls are known calls, or inlined
  (item 6 of [plans/performance.md](plans/performance.md)). One copy for
  each function, types and functions given, made where the first such call
  is, simplified after the definition it is in and put before it. A
  closure given is left as it is.

## Low

Low (`src/backend/low.sml`) is what the targets are made from: each
function is blocks with parameters in SSA form (decision D2), and what Mid
leaves implicit is explicit.

* **Closures:** `Lower` converts them as it goes. A function captures the
  variables free in it, in the order of their stamps, less itself, which it
  reads as `Self`; captured values are read with `Env i`. The functions of
  a group capture each other, and those not made yet are set after
  (`SetEnv`): flat closures.
* **Constructors** (`Rep`, `src/backend/rep.sml`, M11): one whose declared
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
  a copy.
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
  `tests/lang` and `tests/perf` compiled at `-O0` and at `-O2`, with the
  lint on and Mid's text checked against itself (`--mid-roundtrip`). Both
  run under `runevm --checked` (a `DECON` of another constructor than it
  names stops the program), and must print and exit the same, on both
  streams: traces too, where inlining has moved code into another
  function (`tests/lang/rt.trace_inlined.sml`).
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
