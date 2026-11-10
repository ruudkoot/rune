# signature CORE_TO_MID

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **CORE_TO_MID**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 4 of 4 entries documented |
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
  datatype <a href="#type-form">form</a> = <a href="#con-formc">FormC</a> | <a href="#con-runtime">Runtime</a>
  datatype <a href="#type-fault">fault</a> = <a href="#con-thunkinslot">ThunkInSlot</a> | <a href="#con-forcebehindcast">ForceBehindCast</a>
  exception <a href="#exn-unsupported">Unsupported</a> of string
  val <a href="#val-program">program</a> : {<a href="#fld-program.form">form</a> : form, <a href="#fld-program.fault">fault</a> : fault option} * Core.program -&gt; string
end
</pre>

### <a name="type-form"></a>`form`

```sml
datatype form = FormC | Runtime
```

How suspensions are made and forced: by form C's primitives, or by
functions of E1's runtime in today's Mid.

[`FormC`](#con-formc) is the roadmap's M9: `thunk_make`, `thunk_force`,
`thunk_blackhole` and `thunk_self_update`, force one primitive node.
[`Runtime`](#con-runtime) is for a tree that has not got them.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-formc"></a>`FormC` |  |  |
| <a name="con-runtime"></a>`Runtime` |  |  |

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

A construct Core has and the Mid of this tree cannot say yet: what it
waits on, and where.

### <a name="val-program"></a>`program`

```sml
val program : {form : form, fault : fault option} * Core.program -> string
```

`program ({form, fault}, p)` is the text of Mid of the Core program
`p`, which CoreLint passed, with the fault made where it is `SOME`.

The text's `do` calls `main`, and prints what an exception no handler
takes is, as Core's interpreter does, an IOError's text as the
library's Show IOError gives it, and ends with status 1.

**Raises** [`Unsupported`](#exn-unsupported) where `p` needs what Mid has not got.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-program.form"></a>`form` | `form` |  |
| <a name="fld-program.fault"></a>`fault` | `fault option` |  |

---

<sub>Generated by runedoc from lib/language/haskell/coretomid\_sig.sml; do not edit.</sub>
