# signature HS_KINDS

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_KINDS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/kinds\_sig.sml](../../../../../lib/language/haskell/kinds_sig.sml) |

## Synopsis

```sml
signature HS_KINDS
structure HsKinds :> HS_KINDS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsKinds`](../str/HsKinds.md) |  | [lib/language/haskell/kinds.sml](../../../../../lib/language/haskell/kinds.sml) |

The type constructors of Haskell 98's checker and their kinds (the
haskell98 roadmap's M13; the Report's 4.6): kind inference over a
unit's `data`, `newtype`, `type` and `class` declarations by dependency
group, a kind left open defaulting to `*`, so that a type group may
cross the modules of a cycle (R28, D30); the kind checking of every
other type a program writes; and the types of the tree made the
checker's, synonyms expanded.

## Interface

<pre>
signature HS_KINDS =
sig
  type <a href="#type-tycon">tycon</a> = {<a href="#fld-tycon.key">key</a> : string, <a href="#fld-tycon.kind">kind</a> : HsTypes.kind, <a href="#fld-tycon.params">params</a> : int, <a href="#fld-tycon.synonym">synonym</a> : HsTypes.ty option,
                <a href="#fld-tycon.cons">cons</a> : string list, <a href="#fld-tycon.newtype">newtype</a> : bool}
  type <a href="#type-env">env</a> = tycon HsStringMap.map
  val <a href="#val-find">find</a> : env * string -&gt; tycon option
  val <a href="#val-keyof">keyOf</a> : HsAst.name -&gt; string
  val <a href="#val-infer">infer</a> : {<a href="#fld-infer.env">env</a> : env, <a href="#fld-infer.classkind">classKind</a> : string -&gt; HsTypes.kind option, <a href="#fld-infer.decls">decls</a> : (string * HsAst.decl) list}
              -&gt; {env : env, classKinds : (string * HsTypes.kind) list, errors : (HsSource.span * string) list}
  val <a href="#val-checktype">checkType</a> : {<a href="#fld-checktype.env">env</a> : env, <a href="#fld-checktype.classkind">classKind</a> : string -&gt; HsTypes.kind option, <a href="#fld-checktype.vars">vars</a> : HsTypes.kind HsStringMap.map ref}
                  -&gt; HsAst.ty * HsTypes.kind -&gt; unit
  val <a href="#val-checkcontext">checkContext</a> : {<a href="#fld-checkcontext.env">env</a> : env, <a href="#fld-checkcontext.classkind">classKind</a> : string -&gt; HsTypes.kind option, <a href="#fld-checkcontext.vars">vars</a> : HsTypes.kind HsStringMap.map ref}
                     -&gt; HsAst.ty option -&gt; unit
  val <a href="#val-convert">convert</a> : env * (string -&gt; HsTypes.ty) -&gt; HsAst.ty -&gt; HsTypes.ty
  val <a href="#val-contextpreds">contextPreds</a> : env * (string -&gt; HsTypes.ty) -&gt; HsAst.ty option -&gt; HsTypes.pred list
  val <a href="#val-tyvars">tyVars</a> : HsAst.ty -&gt; string list
end
</pre>

### <a name="type-tycon"></a>`tycon`

```sml
type tycon = {key : string, kind : HsTypes.kind, params : int, synonym : HsTypes.ty option,
              cons : string list, newtype : bool}
```

A type constructor: its key, its kind and the number of its
parameters.

With them, its right-hand side over `TGen 0` and on, for a synonym,
its constructors' keys, for `data` and `newtype`, and whether it is a
newtype.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-tycon.key"></a>`key` | `string` |  |
| <a name="fld-tycon.kind"></a>`kind` | `HsTypes.kind` |  |
| <a name="fld-tycon.params"></a>`params` | `int` |  |
| <a name="fld-tycon.synonym"></a>`synonym` | `HsTypes.ty option` |  |
| <a name="fld-tycon.cons"></a>`cons` | `string list` |  |
| <a name="fld-tycon.newtype"></a>`newtype` | `bool` |  |

### <a name="type-env"></a>`env`

```sml
type env = tycon HsStringMap.map
```

The type constructors of a program, by key.

### <a name="val-find"></a>`find`

```sml
val find : env * string -> tycon option
```

`find (env, key)` is the type constructor of `key`, the built-in
ones among them.

### <a name="val-keyof"></a>`keyOf`

```sml
val keyOf : HsAst.name -> string
```

`keyOf n` is the key of the type constructor or class the name `n`
of the renamed tree stands for.

### <a name="val-infer"></a>`infer`

```sml
val infer : {env : env, classKind : string -> HsTypes.kind option, decls : (string * HsAst.decl) list}
            -> {env : env, classKinds : (string * HsTypes.kind) list, errors : (HsSource.span * string) list}
```

`infer {env, classKind, decls}` infers the kinds of `decls`, the
type-level declarations of a unit, each with its module's identity.

It gives the environment with their type constructors, the kinds of
the unit's classes' variables, by the class's key, and the errors.
`classKind` gives the kind of a class of an earlier unit.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-infer.env"></a>`env` | `env` |  |
| <a name="fld-infer.classkind"></a>`classKind` | `string -> HsTypes.kind option` |  |
| <a name="fld-infer.decls"></a>`decls` | `(string * HsAst.decl) list` |  |

### <a name="val-checktype"></a>`checkType`

```sml
val checkType : {env : env, classKind : string -> HsTypes.kind option, vars : HsTypes.kind HsStringMap.map ref}
                -> HsAst.ty * HsTypes.kind -> unit
```

`checkType {env, classKind, vars} (t, want)` checks that the type `t`
is well kinded, of kind `want`.

Its variables' kinds are in `vars`, which it extends.

**Raises** [`HsSource.Error`](../sig/HS_SOURCE.md#exn-error) for a type ill kinded.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-checktype.env"></a>`env` | `env` |  |
| <a name="fld-checktype.classkind"></a>`classKind` | `string -> HsTypes.kind option` |  |
| <a name="fld-checktype.vars"></a>`vars` | `HsTypes.kind HsStringMap.map ref` |  |

### <a name="val-checkcontext"></a>`checkContext`

```sml
val checkContext : {env : env, classKind : string -> HsTypes.kind option, vars : HsTypes.kind HsStringMap.map ref}
                   -> HsAst.ty option -> unit
```

`checkContext {env, classKind, vars} ctx` checks each class
assertion of the context `ctx`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-checkcontext.env"></a>`env` | `env` |  |
| <a name="fld-checkcontext.classkind"></a>`classKind` | `string -> HsTypes.kind option` |  |
| <a name="fld-checkcontext.vars"></a>`vars` | `HsTypes.kind HsStringMap.map ref` |  |

### <a name="val-convert"></a>`convert`

```sml
val convert : env * (string -> HsTypes.ty) -> HsAst.ty -> HsTypes.ty
```

`convert (env, var) t` is the type `t` as the checker's, its
variables by `var`.

Its synonyms are expanded.

**Raises** [`HsSource.Error`](../sig/HS_SOURCE.md#exn-error) for a synonym not applied to all its
parameters.

### <a name="val-contextpreds"></a>`contextPreds`

```sml
val contextPreds : env * (string -> HsTypes.ty) -> HsAst.ty option -> HsTypes.pred list
```

`contextPreds (env, var) ctx` is the predicates of a context.

### <a name="val-tyvars"></a>`tyVars`

```sml
val tyVars : HsAst.ty -> string list
```

`tyVars t` is the type variables of `t`, each once, in order.

---

<sub>Generated by runedoc from lib/language/haskell/kinds\_sig.sml; do not edit.</sub>
