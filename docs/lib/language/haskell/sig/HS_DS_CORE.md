# signature HS_DS_CORE

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_DS_CORE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 46 of 46 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/desugar\_core\_sig.sml](../../../../../lib/language/haskell/desugar_core_sig.sml) |

## Synopsis

```sml
signature HS_DS_CORE
structure HsDsCore :> HS_DS_CORE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsDsCore`](../str/HsDsCore.md) |  | [lib/language/haskell/desugar\_core.sml](../../../../../lib/language/haskell/desugar_core.sml) |

Core as desugaring builds it (the haskell98 roadmap's M15): each
expression with its type.

An expression is made with its type, worked out from its parts as
CoreLint works it out, so that an argument that is not an atom can be
bound by a `let` of its type; and the declarations of the program being
built are kept, by which a constructor's fields and a newtype's
unfolding are known.

A name made here starts with `%`, which no name of Haskell's holds,
neither a top-level entity's nor a local's (`x#3`).

## Contents

[The declarations](#the-declarations) &middot;
[Types](#types) &middot;
[Expressions](#expressions)

## Interface

<pre>
signature HS_DS_CORE =
sig
  type <a href="#type-texp">texp</a> = Core.exp * Core.ty
  datatype <a href="#type-shape">shape</a> =
      <a href="#con-datas">DataS</a> of (string * Core.ty list) list
    | <a href="#con-news">NewS</a> of string * Core.ty
    | <a href="#con-prims">PrimS</a>
  val <a href="#val-reset">reset</a> : unit -&gt; unit
  val <a href="#val-fresh">fresh</a> : string -&gt; string
  type <a href="#type-saved">saved</a>
  val <a href="#val-save">save</a> : unit -&gt; saved
  val <a href="#val-restore">restore</a> : saved -&gt; unit
  val <a href="#val-canonical">canonical</a> : Core.exp -&gt; Core.exp
  val <a href="#val-declare">declare</a> : Core.decl -&gt; unit
  val <a href="#val-tuplearity">tupleArity</a> : string -&gt; int option
  val <a href="#val-tupledata">tupleData</a> : int -&gt; Core.decl
  val <a href="#val-tycon">tycon</a> : string -&gt; ((string * Core.kind) list * shape) option
  val <a href="#val-coninfo">conInfo</a> : string -&gt; {<a href="#fld-coninfo.tycon">tycon</a> : string, <a href="#fld-coninfo.params">params</a> : (string * Core.kind) list, <a href="#fld-coninfo.fields">fields</a> : Core.ty list} option
  val <a href="#val-fieldsat">fieldsAt</a> : string * Core.ty list -&gt; Core.ty list
  val <a href="#val-valuetype">valueType</a> : string -&gt; Core.ty option
  val <a href="#val-unfold">unfold</a> : Core.ty -&gt; Core.ty option
  val <a href="#val-dataargs">dataArgs</a> : Core.ty -&gt; (string * Core.ty list) option
  val <a href="#val-kindof">kindOf</a> : (string * Core.kind) list * Core.ty -&gt; Core.kind
  val <a href="#val-inferkinds">inferKinds</a> : string list * (string -&gt; Core.kind option) * Core.ty list -&gt; (string * Core.kind) list
  val <a href="#val-instantiate">instantiate</a> : Core.ty * Core.ty list -&gt; Core.ty
  val <a href="#val-applytype">applyType</a> : Core.ty * Core.arg list -&gt; Core.ty
  val <a href="#val-params">params</a> : Core.ty * int -&gt; Core.ty list * Core.ty
  val <a href="#val-lazyty">lazyTy</a> : Core.ty -&gt; Core.ty
  val <a href="#val-atom">atom</a> : texp * (Core.atom * Core.ty -&gt; texp) -&gt; texp
  val <a href="#val-atoms">atoms</a> : texp list * ((Core.atom * Core.ty) list -&gt; texp) -&gt; texp
  val <a href="#val-var">var</a> : string * Core.ty -&gt; texp
  val <a href="#val-app">app</a> : texp * Core.arg list -&gt; texp
  val <a href="#val-appatoms">appAtoms</a> : texp * texp list -&gt; texp
  val <a href="#val-lam">lam</a> : Core.binder list * texp -&gt; texp
  val <a href="#val-let_">let_</a> : string * Core.ty * texp * texp -&gt; texp
  val <a href="#val-letrec">letrec</a> : (string * Core.ty * texp) list * texp -&gt; texp
  val <a href="#val-force">force</a> : texp * (string * Core.ty -&gt; texp) -&gt; texp
  val <a href="#val-forcerep">forceRep</a> : texp * (unit -&gt; texp) -&gt; texp
  val <a href="#val-forced">forced</a> : string -&gt; bool list
  val <a href="#val-setforced">setForced</a> : string * bool list -&gt; unit
  val <a href="#val-forcedoverrides">forcedOverrides</a> : unit -&gt; (string * bool list) list
  val <a href="#val-casecon">caseCon</a> : Core.atom * Core.ty * (string * ((string * Core.ty) list -&gt; texp)) list * texp option -&gt; texp
  val <a href="#val-ifbool">ifBool</a> : texp * texp * texp -&gt; texp
  val <a href="#val-con">con</a> : string * Core.ty list * texp list -&gt; texp
  val <a href="#val-cast">cast</a> : texp * Core.ty -&gt; texp
  val <a href="#val-fail">fail</a> : string * string * Core.ty -&gt; texp
  val <a href="#val-mentions">mentions</a> : string * Core.exp -&gt; bool
  val <a href="#val-names">names</a> : Core.exp -&gt; string list
  val <a href="#val-raisers">raisers</a> : Core.decl list
  val <a href="#val-unitty">unitTy</a> : Core.ty
  val <a href="#val-unitval">unitVal</a> : unit -&gt; texp
end
</pre>

### <a name="type-texp"></a>`texp`

```sml
type texp = Core.exp * Core.ty
```

An expression and its type.

### <a name="type-shape"></a>`shape`

```sml
datatype shape =
    DataS of (string * Core.ty list) list
  | NewS of string * Core.ty
  | PrimS
```

What a type constructor of the program is.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-datas"></a>`DataS` | `(string * Core.ty list) list` | a data type: its constructors and their fields |
| <a name="con-news"></a>`NewS` | `string * Core.ty` | a newtype: its constructor and the type it wraps |
| <a name="con-prims"></a>`PrimS` |  | a type of Core's own: `Int`, `World`, ... |

### <a name="val-reset"></a>`reset`

```sml
val reset : unit -> unit
```

`reset ()` forgets every declaration and starts the names again.

### <a name="val-fresh"></a>`fresh`

```sml
val fresh : string -> string
```

`fresh base` is a new name, `%base` and a number.

### <a name="type-saved"></a>`saved`

```sml
type saved
```

What is known of the declarations, kept: so that a desugaring of the
library's modules, made once, is where each program's starts.

### <a name="val-save"></a>`save`

```sml
val save : unit -> saved
```

`save ()` is what is known now.

### <a name="val-restore"></a>`restore`

```sml
val restore : saved -> unit
```

`restore s` makes `s` what is known.

### <a name="val-canonical"></a>`canonical`

```sml
val canonical : Core.exp -> Core.exp
```

`canonical e` is `e` with each name made here that it binds numbered
again, from 1 in the order they are bound, its base kept.

So a value's Core is the same whatever was made before it.

## The declarations

### <a name="val-declare"></a>`declare`

```sml
val declare : Core.decl -> unit
```

`declare d` adds the data type, newtype, value or import `d` to what is
known.

A value is known by its type.

### <a name="val-tuplearity"></a>`tupleArity`

```sml
val tupleArity : string -> int option
```

`tupleArity c` is the number of components of the tuple whose type and
constructor are named `c`, `(,...,)`.

A tuple is of arbitrary length (3.8): one not declared is declared
where it is first wanted, by [`tycon`](#val-tycon), [`conInfo`](#val-coninfo) and the other lookups,
and [`valueType`](#val-valuetype) gives its constructor as a function its type.

### <a name="val-tupledata"></a>`tupleData`

```sml
val tupleData : int -> Core.decl
```

`tupleData n` is the declaration of the tuple of `n` components.

### <a name="val-tycon"></a>`tycon`

```sml
val tycon : string -> ((string * Core.kind) list * shape) option
```

`tycon c` is the parameters and the shape of the type constructor `c`,
Core's built-in ones among them.

### <a name="val-coninfo"></a>`conInfo`

```sml
val conInfo : string -> {tycon : string, params : (string * Core.kind) list, fields : Core.ty list} option
```

`conInfo k` is the type constructor of the constructor `k`, its
parameters and its fields' types over them.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-coninfo.tycon"></a>`tycon` | `string` |  |
| <a name="fld-coninfo.params"></a>`params` | `(string * Core.kind) list` |  |
| <a name="fld-coninfo.fields"></a>`fields` | `Core.ty list` |  |

### <a name="val-fieldsat"></a>`fieldsAt`

```sml
val fieldsAt : string * Core.ty list -> Core.ty list
```

`fieldsAt (k, args)` is the types of the fields of the constructor `k`
of a type applied to `args`.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) where `k` is not declared.

### <a name="val-valuetype"></a>`valueType`

```sml
val valueType : string -> Core.ty option
```

`valueType x` is the type of the value `x` of the top level, or of
rhc's runtime.

### <a name="val-unfold"></a>`unfold`

```sml
val unfold : Core.ty -> Core.ty option
```

`unfold t` is `t` unfolded once, where a newtype is at its head.

### <a name="val-dataargs"></a>`dataArgs`

```sml
val dataArgs : Core.ty -> (string * Core.ty list) option
```

`dataArgs t` is the type constructor at the head of `t`, a data type's
or a newtype's, and its arguments.

## Types

### <a name="val-kindof"></a>`kindOf`

```sml
val kindOf : (string * Core.kind) list * Core.ty -> Core.kind
```

`kindOf (vars, t)` is the kind of the type `t`, whose variables have
the kinds `vars` or are of `*`.

### <a name="val-inferkinds"></a>`inferKinds`

```sml
val inferKinds : string list * (string -> Core.kind option) * Core.ty list -> (string * Core.kind) list
```

`inferKinds (vars, known, tys)` is the kind of each of `vars`, which
the types `tys` of kind `*` hold.

Each is worked out from where it stands, and is `*` where nothing
says; `known` gives the kinds of the other variables.

### <a name="val-instantiate"></a>`instantiate`

```sml
val instantiate : Core.ty * Core.ty list -> Core.ty
```

`instantiate (t, tys)` is `t` without its first foralls, their
variables replaced by `tys`, in order.

### <a name="val-applytype"></a>`applyType`

```sml
val applyType : Core.ty * Core.arg list -> Core.ty
```

`applyType (t, args)` is the type of a function of type `t` given
`args`.

### <a name="val-params"></a>`params`

```sml
val params : Core.ty * int -> Core.ty list * Core.ty
```

`params (t, n)` is the types of the first `n` parameters of a
function of type `t`, and the type of what it gives then.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) where `t` takes fewer.

### <a name="val-lazyty"></a>`lazyTy`

```sml
val lazyTy : Core.ty -> Core.ty
```

`lazyTy t` is `t` as a lazy binding holds it: without [`!`](../../../basis/sig/GENERAL.md#val-op-bang).

## Expressions

### <a name="val-atom"></a>`atom`

```sml
val atom : texp * (Core.atom * Core.ty -> texp) -> texp
```

`atom (x, k)` gives `k` the atom of `x`: itself where it is one,
otherwise a variable bound to it by a lazy `let`.

### <a name="val-atoms"></a>`atoms`

```sml
val atoms : texp list * ((Core.atom * Core.ty) list -> texp) -> texp
```

`atoms (xs, k)` is [`atom`](#val-atom) over each of `xs`, left to right.

### <a name="val-var"></a>`var`

```sml
val var : string * Core.ty -> texp
```

`var (x, t)` is the variable `x` of type `t`.

### <a name="val-app"></a>`app`

```sml
val app : texp * Core.arg list -> texp
```

`app (f, args)` is `f` applied to `args`; `f` itself where there are
none.

### <a name="val-appatoms"></a>`appAtoms`

```sml
val appAtoms : texp * texp list -> texp
```

`appAtoms (f, xs)` is `f` applied to the atoms of `xs`, each bound by
[`atom`](#val-atom).

### <a name="val-lam"></a>`lam`

```sml
val lam : Core.binder list * texp -> texp
```

`lam (binders, body)` is a lambda of `binders`; `body` itself where
there are none.

### <a name="val-let_"></a>`let_`

```sml
val let_ : string * Core.ty * texp * texp -> texp
```

`let_ (x, t, rhs, body)` is `let x : t = rhs in body`, `t` lazy.

### <a name="val-letrec"></a>`letrec`

```sml
val letrec : (string * Core.ty * texp) list * texp -> texp
```

`letrec (bs, body)` binds `bs`, each with its lazy type, in each
other and in `body`; `body` itself where there are none.

### <a name="val-force"></a>`force`

```sml
val force : texp * (string * Core.ty -> texp) -> texp
```

`force (x, k)` evaluates `x` by a `case` and gives `k` the evaluated
variable and its type.

### <a name="val-forcerep"></a>`forceRep`

```sml
val forceRep : texp * (unit -> texp) -> texp
```

`forceRep (x, k)` evaluates `x`'s representation, through every newtype
at its head, by casts, before `k ()`: what a strict field of a newtype's
type forces.

### <a name="val-forced"></a>`forced`

```sml
val forced : string -> bool list
```

`forced k` is whether each field of the constructor `k` is forced where
it is applied: its [`!`](../../../basis/sig/GENERAL.md#val-op-bang), or a strict field of a newtype's type, lazy in
Core ([`setForced`](#val-setforced)).

### <a name="val-setforced"></a>`setForced`

```sml
val setForced : string * bool list -> unit
```

`setForced (k, flags)` gives the constructor `k` the fields it forces,
where they are not its fields' [`!`](../../../basis/sig/GENERAL.md#val-op-bang).

### <a name="val-forcedoverrides"></a>`forcedOverrides`

```sml
val forcedOverrides : unit -> (string * bool list) list
```

`forcedOverrides ()` is each constructor [`setForced`](#val-setforced) gave its flags.

### <a name="val-casecon"></a>`caseCon`

```sml
val caseCon : Core.atom * Core.ty * (string * ((string * Core.ty) list -> texp)) list * texp option -> texp
```

`caseCon (x, ty, alts, default)` is a `case` on the atom `x` of the
data type `ty`.

It has an alternative for each constructor of `alts`, made of its
fields' names and types, and `default` for the others, left out where
`alts` covers them all.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) where `ty` is not a data type.

### <a name="val-ifbool"></a>`ifBool`

```sml
val ifBool : texp * texp * texp -> texp
```

`ifBool (c, t, e)` is `case c of True -> t; False -> e`.

### <a name="val-con"></a>`con`

```sml
val con : string * Core.ty list * texp list -> texp
```

`con (k, tys, xs)` is the constructor `k` at the types `tys` applied
to the atoms of `xs`.

### <a name="val-cast"></a>`cast`

```sml
val cast : texp * Core.ty -> texp
```

`cast (x, t)` is `x` cast to the type `t`, into or out of a newtype.

### <a name="val-fail"></a>`fail`

```sml
val fail : string * string * Core.ty -> texp
```

`fail (kind, message, t)` is an expression of type `t` that raises
the exception the primitive `kind` makes of `message`.

`kind` is `exn_pattern` for a match that fails, `exn_error` for
`error`'s. It calls one of [`raisers`](#val-raisers), at `t`.

### <a name="val-mentions"></a>`mentions`

```sml
val mentions : string * Core.exp -> bool
```

`mentions (x, e)` is whether the variable `x` occurs in `e`, which
binds no other `x`.

### <a name="val-names"></a>`names`

```sml
val names : Core.exp -> string list
```

`names e` is every variable `e` holds, bound in it or not, and every
constructor, each once.

### <a name="val-raisers"></a>`raisers`

```sml
val raisers : Core.decl list
```

[`raisers`](#val-raisers) is the values [`fail`](#val-fail) calls, a declaration each, which a
program that uses [`fail`](#val-fail) holds.

### <a name="val-unitty"></a>`unitTy`

```sml
val unitTy : Core.ty
```

[`unitTy`](#val-unitty) is the type of Haskell's `()`, rhc's runtime's.

### <a name="val-unitval"></a>`unitVal`

```sml
val unitVal : unit -> texp
```

`unitVal ()` is the value `()`.

---

<sub>Generated by runedoc from lib/language/haskell/desugar\_core\_sig.sml; do not edit.</sub>
