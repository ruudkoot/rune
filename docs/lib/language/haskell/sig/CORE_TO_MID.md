# signature CORE_TO_MID

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **CORE_TO_MID**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 6 of 6 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/coretomid\_sig.sml](../../../../../lib/language/haskell/coretomid_sig.sml) |

## Synopsis

```sml
signature CORE_TO_MID
structure CoreToMid : CORE_TO_MID
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CoreToMid`](../str/CoreToMid.md) | Core to Mid (coretomid\_sig.sml): Mid's text written from Core, in A-normal form by continuations. An expression is translated with what is to be done with its value, a continuation, which knows the Core type it wants and whether it may be copied into each branch (a return or a jump) or needs a join point. A variable of Core is held in Mid as its value, a suspension of it, a cell holding the suspension (in a letrec), or nothing (the state token). | [lib/language/haskell/coretomid.sml](../../../../../lib/language/haskell/coretomid.sml) |

Core to Mid (the haskell98 roadmap, M10): a Core program as a program
of Mid's text, which rhc reads with Mid's own reader and gives to the
passes from Mid on (MidPipeline), its list without expand.

A lazy position of type T is `T susp` in Mid and an evaluated one `T`:
a binder, a parameter, a field and a component of an unboxed tuple of
type `!T` is the value, one of a lifted `T` a suspension. A function
takes each argument in its slot and returns its value evaluated, so a
datatype-typed variable of Mid is evaluated. A `let` of a value -- a
lambda, a constructor, a literal -- binds the value, and of anything else
a suspension, whose code says it is under evaluation first and updates
it with its value last. A `case` forces its scrutinee and tests its tag;
a value given to a lazy slot is cast into it. A `letrec` of values goes
through cells (D6's A), and a value of the top level that is no function
is a suspension in a global, a CAF. The state token is erased (D25): an
action of Core, `World -> (utuple World T)`, is `unit -> T` in Mid, its
order the order of its lets.

An `Integer` is Mid's [`IntInf.int`](../../../basis/sig/INTEGER.md#type-int), an immediate within 63 bits and a
sign and a magnitude past them (M31, D20's D), each literal a global made
once. A type variable applied and a forall inside a type are Mid's own
(M28): a lazy field of a forall holds a suspension at every type, the
forall outside it, and a newtype given fewer arguments than its
parameters is a box, as one that reaches itself is.

## Interface

<pre>
signature CORE_TO_MID =
sig
  datatype <a href="#type-fault">fault</a> = <a href="#con-thunkinslot">ThunkInSlot</a> | <a href="#con-forcebehindcast">ForceBehindCast</a>
  exception <a href="#exn-unsupported">Unsupported</a> of string
  val <a href="#val-program">program</a> : {<a href="#fld-program.fault">fault</a> : fault option} * Core.program -&gt; string
  datatype <a href="#type-abi">abi</a> = <a href="#con-function">Function</a> | <a href="#con-suspension">Suspension</a> | <a href="#con-literal">Literal</a>
  val <a href="#val-unit">unit</a> : {<a href="#fld-unit.fault">fault</a> : fault option, <a href="#fld-unit.imports">imports</a> : (string * abi) list, <a href="#fld-unit.makesshared">makesShared</a> : bool, <a href="#fld-unit.newtypes">newtypes</a> : (string * bool) list}
             * Core.program
             -&gt; {text : string, names : (string * string) list, abi : (string * abi) list, boxed : (string * bool) list}
  val <a href="#val-shared">shared</a> : string list
end
</pre>

### <a name="type-fault"></a>`fault`

```sml
datatype fault = ThunkInSlot | ForceBehindCast
```

A fault made on purpose, for the tests of what catches it.

They are the roadmap's rhc's mutants of Core to Mid: [`ThunkInSlot`](#con-thunkinslot), a
suspension used where its value is wanted, unforced; [`ForceBehindCast`](#con-forcebehindcast),
a force made a cast from the suspension to its value.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-thunkinslot"></a>`ThunkInSlot` |  |  |
| <a name="con-forcebehindcast"></a>`ForceBehindCast` |  |  |

### <a name="exn-unsupported"></a>`Unsupported`

```sml
exception Unsupported of string
```

A construct Core has and Core to Mid does not lower: what it is, and
where.

### <a name="val-program"></a>`program`

```sml
val program : {fault : fault option} * Core.program -> string
```

`program ({fault}, p)` is the text of Mid of the Core program `p`,
which CoreLint passed, with the fault made where it is `SOME`.

A suspension is form C's (the roadmap's M9): made by `thunk_make`,
forced by one `thunk_force` node, its code saying `thunk_blackhole`
first and `thunk_self_update` last.

The text's `do` calls `main`, and prints what an exception no handler
takes is, as Core's interpreter does, an IOError's text as the
library's Show IOError gives it, and ends with status 1.

**Raises** [`Unsupported`](#exn-unsupported) where `p` needs what Mid has not got.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-program.fault"></a>`fault` | `fault option` |  |

### <a name="type-abi"></a>`abi`

```sml
datatype abi = Function | Suspension | Literal
```

How a value of the top level is in Mid, an ABI fact of its interface.

A unit that imports it binds it so (H9): a function global, a
suspension in a global (a CAF), or a literal in a global.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-function"></a>`Function` |  |  |
| <a name="con-suspension"></a>`Suspension` |  |  |
| <a name="con-literal"></a>`Literal` |  |  |

### <a name="val-unit"></a>`unit`

```sml
val unit : {fault : fault option, imports : (string * abi) list, makesShared : bool, newtypes : (string * bool) list}
           * Core.program
           -> {text : string, names : (string * string) list, abi : (string * abi) list, boxed : (string * bool) list}
```

`unit ({fault, imports, makesShared}, p)` is the text of Mid of the
unit `p` (the haskell98 roadmap's M21).

Each import of another unit is bound as `imports` says that unit's
Core to Mid made it, and each newtype of another unit is a box where
`newtypes` says that unit made it one (an ABI fact, H9); its `boxed`
says so of each newtype the unit declares itself. Its `names` is the name in the text of each value of the top level,
the unit's own and its imports, by its Core name; its [`abi`](#type-abi) how each
of its own is made. An import is declared in the text as a global of
its scheme whose expression is a placeholder, which the client drops
after reading the text, its scheme MidLint's for the import
(MidLint.importedScheme). The text calls `main` where the unit
defines it, as [`program`](#val-program)'s does.

**Raises** [`Unsupported`](#exn-unsupported) where `p` needs what Mid has not got, or an
import `imports` does not give.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-unit.fault"></a>`fault` | `fault option` |  |
| <a name="fld-unit.imports"></a>`imports` | `(string * abi) list` |  |
| <a name="fld-unit.makesshared"></a>`makesShared` | `bool` |  |
| <a name="fld-unit.newtypes"></a>`newtypes` | `(string * bool) list` |  |

### <a name="val-shared"></a>`shared`

```sml
val shared : string list
```

[`shared`](#val-shared) is the globals of every text's prelude that have an
identity, Core's exceptions, which one unit of a program makes.

Each is in [`unit`](#val-unit)'s `names` by itself, and
in its [`abi`](#type-abi) where the unit makes them (makesShared), which one unit
of a program does; in the others' texts they are imports, which their
client reads as it reads an import's placeholder.

---

<sub>Generated by runedoc from lib/language/haskell/coretomid\_sig.sml; do not edit.</sub>
