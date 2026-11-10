# signature HS_CLASSES

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_CLASSES**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/classes\_sig.sml](../../../../../lib/language/haskell/classes_sig.sml) |

## Synopsis

```sml
signature HS_CLASSES
structure HsClasses :> HS_CLASSES
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsClasses`](../str/HsClasses.md) |  | [lib/language/haskell/classes.sml](../../../../../lib/language/haskell/classes.sml) |

The classes and instances of Haskell 98's checker (the haskell98
roadmap's M13; the Report's 4.3): every class and instance of the
program, for entailment. Instances are not names: every instance a
program declares, or derives, is in force in all of it.

## Interface

<pre>
signature HS_CLASSES =
sig
  type <a href="#type-class">class</a> = {<a href="#fld-class.key">key</a> : string, <a href="#fld-class.supers">supers</a> : string list, <a href="#fld-class.methods">methods</a> : string list, <a href="#fld-class.kind">kind</a> : HsTypes.kind}
  type <a href="#type-instance">instance</a> = {<a href="#fld-instance.id">id</a> : string, <a href="#fld-instance.cls">cls</a> : string, <a href="#fld-instance.tycon">tycon</a> : string, <a href="#fld-instance.vars">vars</a> : int, <a href="#fld-instance.ctx">ctx</a> : HsTypes.pred list,
                   <a href="#fld-instance.derived">derived</a> : bool, <a href="#fld-instance.home">home</a> : string}
  type <a href="#type-env">env</a>
  val <a href="#val-empty">empty</a> : env
  val <a href="#val-addclass">addClass</a> : env * class -&gt; env
  val <a href="#val-addinstance">addInstance</a> : env * instance -&gt; env
  val <a href="#val-withcontext">withContext</a> : env * string * HsTypes.pred list -&gt; env
  val <a href="#val-findclass">findClass</a> : env * string -&gt; class option
  val <a href="#val-findinstance">findInstance</a> : env * string * string -&gt; instance option
  val <a href="#val-instances">instances</a> : env -&gt; instance list
  val <a href="#val-instanceid">instanceId</a> : string * string -&gt; string
  val <a href="#val-showinstance">showInstance</a> : string -&gt; string
  val <a href="#val-superpath">superPath</a> : env * string * string -&gt; string list option
  val <a href="#val-superclasses">superclasses</a> : env * string -&gt; string list
end
</pre>

### <a name="type-class"></a>`class`

```sml
type class = {key : string, supers : string list, methods : string list, kind : HsTypes.kind}
```

A class: its key, its direct superclasses, its methods' keys, in
order, and the kind of its variable.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-class.key"></a>`key` | `string` |  |
| <a name="fld-class.supers"></a>`supers` | `string list` |  |
| <a name="fld-class.methods"></a>`methods` | `string list` |  |
| <a name="fld-class.kind"></a>`kind` | `HsTypes.kind` |  |

### <a name="type-instance"></a>`instance`

```sml
type instance = {id : string, cls : string, tycon : string, vars : int, ctx : HsTypes.pred list,
                 derived : bool, home : string}
```

An instance `C (T a1 ... an)`: its identity, class, type constructor
and the number of its head's variables.

With them, its context over `TGen 0` to `TGen (n - 1)`, whether it is
derived, and the module that declares it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-instance.id"></a>`id` | `string` |  |
| <a name="fld-instance.cls"></a>`cls` | `string` |  |
| <a name="fld-instance.tycon"></a>`tycon` | `string` |  |
| <a name="fld-instance.vars"></a>`vars` | `int` |  |
| <a name="fld-instance.ctx"></a>`ctx` | `HsTypes.pred list` |  |
| <a name="fld-instance.derived"></a>`derived` | `bool` |  |
| <a name="fld-instance.home"></a>`home` | `string` |  |

### <a name="type-env"></a>`env`

```sml
type env
```

The classes and instances of a program.

### <a name="val-empty"></a>`empty`

```sml
val empty : env
```

No class and no instance.

### <a name="val-addclass"></a>`addClass`

```sml
val addClass : env * class -> env
```

`addClass (env, c)` is `env` with the class `c`.

### <a name="val-addinstance"></a>`addInstance`

```sml
val addInstance : env * instance -> env
```

`addInstance (env, i)` is `env` with the instance `i`.

### <a name="val-withcontext"></a>`withContext`

```sml
val withContext : env * string * HsTypes.pred list -> env
```

`withContext (env, id, ctx)` is `env` with the context of the
instance `id` replaced, as deriving's fixpoint does.

### <a name="val-findclass"></a>`findClass`

```sml
val findClass : env * string -> class option
```

`findClass (env, key)` is the class of `key`.

### <a name="val-findinstance"></a>`findInstance`

```sml
val findInstance : env * string * string -> instance option
```

`findInstance (env, cls, tycon)` is the instance of `cls` at `tycon`.

### <a name="val-instances"></a>`instances`

```sml
val instances : env -> instance list
```

`instances env` is every instance of `env`.

### <a name="val-instanceid"></a>`instanceId`

```sml
val instanceId : string * string -> string
```

`instanceId (cls, tycon)` is the identity of the instance of `cls`
at `tycon`.

### <a name="val-showinstance"></a>`showInstance`

```sml
val showInstance : string -> string
```

`showInstance id` is the instance `id` as a message names it: its
class and its type constructor.

### <a name="val-superpath"></a>`superPath`

```sml
val superPath : env * string * string -> string list option
```

`superPath (env, c, s)` is the classes from `c` to its superclass `s`,
`c` first and `s` last.

Each is the direct superclass of the one before; NONE where `s` is no
superclass of `c`.

### <a name="val-superclasses"></a>`superclasses`

```sml
val superclasses : env * string -> string list
```

`superclasses (env, c)` is every superclass of `c`, through.

---

<sub>Generated by runedoc from lib/language/haskell/classes\_sig.sml; do not edit.</sub>
