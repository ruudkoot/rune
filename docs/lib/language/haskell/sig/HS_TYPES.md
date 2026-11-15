# signature HS_TYPES

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_TYPES**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 43 of 43 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/types\_sig.sml](../../../../../lib/language/haskell/types_sig.sml) |

## Synopsis

```sml
signature HS_TYPES
structure HsTypes :> HS_TYPES
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsTypes`](../str/HsTypes.md) |  | [lib/language/haskell/types.sml](../../../../../lib/language/haskell/types.sml) |

The types of Haskell 98's checker (the haskell98 roadmap's M13, D31):
kinds, types with unification variables, predicates and schemes, and
first-order unification with levels.

A type constructor is named by the key of its entity ([`HsModules.key`](../sig/HS_MODULES.md#val-key)),
or is one of the built-in ones, named as the renamer leaves them: `()`,
`[]`, `->`, and the tuples' `(,)`, `(,,)` and on. A unification
variable is a cell, linked once it is solved; its level is the depth of
the binding group that made it, so that generalisation takes the
variables deeper than the group's level, and its home is the module
whose code made it, which Rule 2 in a cycle reads (D30). A variable of a
signature or of an instance head, fixed while it is checked, is rigid.

## Interface

<pre>
signature HS_TYPES =
sig
  datatype <a href="#type-kind">kind</a> = <a href="#con-kstar">KStar</a> | <a href="#con-kfun">KFun</a> of kind * kind | <a href="#con-kvar">KVar</a> of kvar ref
  and <a href="#type-kvar">kvar</a> = <a href="#con-kfree">KFree</a> of int | <a href="#con-klink">KLink</a> of kind
  val <a href="#val-newkind">newKind</a> : unit -&gt; kind
  val <a href="#val-kindrepr">kindRepr</a> : kind -&gt; kind
  val <a href="#val-defaultkind">defaultKind</a> : kind -&gt; kind
  val <a href="#val-showkind">showKind</a> : kind -&gt; string
  exception <a href="#exn-kindmismatch">KindMismatch</a> of kind * kind
  val <a href="#val-unifykind">unifyKind</a> : kind * kind -&gt; unit
  type <a href="#type-rigid">rigid</a> = {<a href="#fld-rigid.id">id</a> : int, <a href="#fld-rigid.name">name</a> : string}
  datatype <a href="#type-ty">ty</a> =
      <a href="#con-tcon">TCon</a> of string
    | <a href="#con-tap">TAp</a> of ty * ty
    | <a href="#con-tmeta">TMeta</a> of meta ref
    | <a href="#con-tgen">TGen</a> of int
    | <a href="#con-trigid">TRigid</a> of rigid
  and <a href="#type-meta">meta</a> =
      <a href="#con-free">Free</a> of {<a href="#fld-free.id">id</a> : int, <a href="#fld-free.level">level</a> : int, <a href="#fld-free.home">home</a> : string}
    | <a href="#con-link">Link</a> of ty
  type <a href="#type-pred">pred</a> = {<a href="#fld-pred.cls">cls</a> : string, <a href="#fld-pred.ty">ty</a> : ty}
  type <a href="#type-scheme">scheme</a> = {<a href="#fld-scheme.vars">vars</a> : int, <a href="#fld-scheme.ctx">ctx</a> : pred list, <a href="#fld-scheme.ty">ty</a> : ty}
  val <a href="#val-unitcon">unitCon</a> : string
  val <a href="#val-listcon">listCon</a> : string
  val <a href="#val-arrowcon">arrowCon</a> : string
  val <a href="#val-tuplecon">tupleCon</a> : int -&gt; string
  val <a href="#val-builtinkind">builtinKind</a> : string -&gt; kind option
  val <a href="#val-fn_">fn_</a> : ty * ty -&gt; ty
  val <a href="#val-list">list</a> : ty -&gt; ty
  val <a href="#val-tuple">tuple</a> : ty list -&gt; ty
  val <a href="#val-unit">unit</a> : ty
  val <a href="#val-apply">apply</a> : ty * ty list -&gt; ty
  val <a href="#val-spine">spine</a> : ty -&gt; ty * ty list
  val <a href="#val-newmeta">newMeta</a> : int * string -&gt; ty
  val <a href="#val-renumber">renumber</a> : int -&gt; unit
  val <a href="#val-numberfrom">numberFrom</a> : int -&gt; unit
  val <a href="#val-repr">repr</a> : ty -&gt; ty
  val <a href="#val-zonk">zonk</a> : ty -&gt; ty
  val <a href="#val-metas">metas</a> : ty -&gt; meta ref list
  val <a href="#val-metaid">metaId</a> : meta ref -&gt; int
  val <a href="#val-metalevel">metaLevel</a> : meta ref -&gt; int
  val <a href="#val-metahome">metaHome</a> : meta ref -&gt; string
  val <a href="#val-setlevel">setLevel</a> : meta ref * int -&gt; unit
  exception <a href="#exn-mismatch">Mismatch</a> of ty * ty
  exception <a href="#exn-occurs">Occurs</a> of ty * ty
  val <a href="#val-unify">unify</a> : (meta ref * ty -&gt; unit) -&gt; ty * ty -&gt; unit
  val <a href="#val-instantiate">instantiate</a> : scheme * int * string -&gt; ty list * pred list * ty
  val <a href="#val-substgen">substGen</a> : ty list * ty -&gt; ty
  val <a href="#val-nameofkey">nameOfKey</a> : string -&gt; string
  val <a href="#val-show">show</a> : ty -&gt; string
  val <a href="#val-showpred">showPred</a> : pred -&gt; string
  val <a href="#val-showscheme">showScheme</a> : scheme -&gt; string
end
</pre>

### <a name="type-kind"></a>`kind`

```sml
datatype kind = KStar | KFun of kind * kind | KVar of kvar ref
```

A kind, with variables that kind inference solves.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-kstar"></a>`KStar` |  |  |
| <a name="con-kfun"></a>`KFun` | `kind * kind` |  |
| <a name="con-kvar"></a>`KVar` | `kvar ref` |  |

### <a name="type-kvar"></a>`kvar`

```sml
datatype kvar = KFree of int | KLink of kind
```

A kind variable: unsolved, by its number, or linked to a kind.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-kfree"></a>`KFree` | `int` |  |
| <a name="con-klink"></a>`KLink` | `kind` |  |

### <a name="val-newkind"></a>`newKind`

```sml
val newKind : unit -> kind
```

`newKind ()` is a fresh kind variable.

### <a name="val-kindrepr"></a>`kindRepr`

```sml
val kindRepr : kind -> kind
```

`kindRepr k` follows the links of `k`'s variable, if it has one.

### <a name="val-defaultkind"></a>`defaultKind`

```sml
val defaultKind : kind -> kind
```

`defaultKind k` is `k` with every unsolved variable made `*`.

### <a name="val-showkind"></a>`showKind`

```sml
val showKind : kind -> string
```

`showKind k` is `k` as the Report writes one.

### <a name="exn-kindmismatch"></a>`KindMismatch`

```sml
exception KindMismatch of kind * kind
```

Two kinds that cannot be one.

### <a name="val-unifykind"></a>`unifyKind`

```sml
val unifyKind : kind * kind -> unit
```

`unifyKind (a, b)` makes `a` and `b` one kind.

**Raises** [`KindMismatch`](#exn-kindmismatch) where they cannot be.

### <a name="type-rigid"></a>`rigid`

```sml
type rigid = {id : int, name : string}
```

A rigid variable: a number for itself and its name as written.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-rigid.id"></a>`id` | `int` |  |
| <a name="fld-rigid.name"></a>`name` | `string` |  |

### <a name="type-ty"></a>`ty`

```sml
datatype ty =
    TCon of string
  | TAp of ty * ty
  | TMeta of meta ref
  | TGen of int
  | TRigid of rigid
```

A type. `TGen i` is the `i`th variable a scheme binds.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-tcon"></a>`TCon` | `string` |  |
| <a name="con-tap"></a>`TAp` | `ty * ty` |  |
| <a name="con-tmeta"></a>`TMeta` | `meta ref` |  |
| <a name="con-tgen"></a>`TGen` | `int` |  |
| <a name="con-trigid"></a>`TRigid` | `rigid` |  |

### <a name="type-meta"></a>`meta`

```sml
datatype meta =
    Free of {id : int, level : int, home : string}
  | Link of ty
```

A unification variable: unsolved, with its number, its level and its
home module, or linked to the type it was solved as.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-free"></a>`Free` | `{id : int, level : int, home : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-free.id"></a>`id` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-free.level"></a>`level` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-free.home"></a>`home` | `string` |  |
| <a name="con-link"></a>`Link` | `ty` |  |

### <a name="type-pred"></a>`pred`

```sml
type pred = {cls : string, ty : ty}
```

A predicate, `C t`: a class, by the key of its entity, and a type.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-pred.cls"></a>`cls` | `string` |  |
| <a name="fld-pred.ty"></a>`ty` | `ty` |  |

### <a name="type-scheme"></a>`scheme`

```sml
type scheme = {vars : int, ctx : pred list, ty : ty}
```

A scheme: the number of variables it binds, its context and its type,
over `TGen 0` to `TGen (vars - 1)`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-scheme.vars"></a>`vars` | `int` |  |
| <a name="fld-scheme.ctx"></a>`ctx` | `pred list` |  |
| <a name="fld-scheme.ty"></a>`ty` | `ty` |  |

### <a name="val-unitcon"></a>`unitCon`

```sml
val unitCon : string
```

The unit's type constructor, `()`.

### <a name="val-listcon"></a>`listCon`

```sml
val listCon : string
```

The list's type constructor, `[]`.

### <a name="val-arrowcon"></a>`arrowCon`

```sml
val arrowCon : string
```

The function's type constructor, `->`.

### <a name="val-tuplecon"></a>`tupleCon`

```sml
val tupleCon : int -> string
```

`tupleCon n` is the type constructor of the tuples of `n` components.

### <a name="val-builtinkind"></a>`builtinKind`

```sml
val builtinKind : string -> kind option
```

`builtinKind name` is the kind of a built-in type constructor.

### <a name="val-fn_"></a>`fn_`

```sml
val fn_ : ty * ty -> ty
```

`fn_ (a, b)` is the type `a -> b`.

### <a name="val-list"></a>`list`

```sml
val list : ty -> ty
```

`list t` is the type `[t]`.

### <a name="val-tuple"></a>`tuple`

```sml
val tuple : ty list -> ty
```

`tuple ts` is the tuple of the types `ts`.

### <a name="val-unit"></a>`unit`

```sml
val unit : ty
```

The unit's type, `()`.

### <a name="val-apply"></a>`apply`

```sml
val apply : ty * ty list -> ty
```

`apply (t, args)` is `t` applied to `args`, left to right.

### <a name="val-spine"></a>`spine`

```sml
val spine : ty -> ty * ty list
```

`spine t` is the head of `t` and its arguments.

### <a name="val-newmeta"></a>`newMeta`

```sml
val newMeta : int * string -> ty
```

`newMeta (level, home)` is a fresh unification variable.

### <a name="val-renumber"></a>`renumber`

```sml
val renumber : int -> unit
```

`renumber n` makes the next fresh unification and kind variables
number from `n`, where they have not passed it.

What follows is then numbered alike however much came before it below
`n` (rhc's saved world, a program checked by interfaces).

### <a name="val-numberfrom"></a>`numberFrom`

```sml
val numberFrom : int -> unit
```

`numberFrom n` makes the next fresh unification and kind variables
number from `n`, whatever came before.

The caller sees that no variable it numbered at or past `n` stands.

### <a name="val-repr"></a>`repr`

```sml
val repr : ty -> ty
```

`repr t` follows `t`'s links to its head.

### <a name="val-zonk"></a>`zonk`

```sml
val zonk : ty -> ty
```

`zonk t` is `t` with every solved variable replaced, through.

### <a name="val-metas"></a>`metas`

```sml
val metas : ty -> meta ref list
```

`metas t` is the unsolved variables of `t`, each once, in order.

### <a name="val-metaid"></a>`metaId`

```sml
val metaId : meta ref -> int
```

`metaId m` is the number of an unsolved variable.

### <a name="val-metalevel"></a>`metaLevel`

```sml
val metaLevel : meta ref -> int
```

`metaLevel m` is the level of an unsolved variable.

### <a name="val-metahome"></a>`metaHome`

```sml
val metaHome : meta ref -> string
```

`metaHome m` is the module whose code made an unsolved variable.

### <a name="val-setlevel"></a>`setLevel`

```sml
val setLevel : meta ref * int -> unit
```

`setLevel (m, l)` moves an unsolved variable to the level `l`.

### <a name="exn-mismatch"></a>`Mismatch`

```sml
exception Mismatch of ty * ty
```

Two types that differ, which unification cannot make one.

### <a name="exn-occurs"></a>`Occurs`

```sml
exception Occurs of ty * ty
```

A variable that occurs in the type unification would make it.

### <a name="val-unify"></a>`unify`

```sml
val unify : (meta ref * ty -> unit) -> ty * ty -> unit
```

`unify watch (a, b)` makes `a` and `b` one type, solving variables.

On each variable it solves, `watch` is told it and the type.

**Raises** [`Mismatch`](#exn-mismatch) where the types differ, and [`Occurs`](#exn-occurs) where a
variable would contain itself.

### <a name="val-instantiate"></a>`instantiate`

```sml
val instantiate : scheme * int * string -> ty list * pred list * ty
```

`instantiate (s, level, home)` is `s`'s type and context with fresh
variables for its own, and those variables.

### <a name="val-substgen"></a>`substGen`

```sml
val substGen : ty list * ty -> ty
```

`substGen (ts, t)` replaces `TGen i` by the `i`th of `ts`.

### <a name="val-nameofkey"></a>`nameOfKey`

```sml
val nameOfKey : string -> string
```

`nameOfKey k` is the name of the entity of key `k`, as a message shows
it; a built-in name is itself.

### <a name="val-show"></a>`show`

```sml
val show : ty -> string
```

`show t` is `t` as Haskell writes it.

Its unsolved variables are named `t1`, `t2` and on by their numbers,
a rigid variable by its name as written.

### <a name="val-showpred"></a>`showPred`

```sml
val showPred : pred -> string
```

`showPred p` is the predicate `p` as a context writes it.

### <a name="val-showscheme"></a>`showScheme`

```sml
val showScheme : scheme -> string
```

`showScheme s` is the scheme `s` as a signature writes it, its
variables `a`, `b` and on.

---

<sub>Generated by runedoc from lib/language/haskell/types\_sig.sml; do not edit.</sub>
