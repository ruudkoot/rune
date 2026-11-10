# signature HS_INFER

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_INFER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 7 of 7 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/infer\_sig.sml](../../../../../lib/language/haskell/infer_sig.sml) |

## Synopsis

```sml
signature HS_INFER
structure HsInfer :> HS_INFER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsInfer`](../str/HsInfer.md) |  | [lib/language/haskell/infer.sml](../../../../../lib/language/haskell/infer.sml) |

Haskell 98's type checker (the haskell98 roadmap's M13, D30, D31, D32,
D33): one inference over the renamed, fixity-resolved trees of a unit,
the modules of one strongly connected group, joined, so that a binding
group or a type group may cross its modules, with what it chose
recorded by node in HsEvidence's table.

Types by first-order unification with levels; kinds by HsKinds;
classes, instances and the derived instances' contexts, by the fixpoint
10\.1 allows, in HsClasses; each overloaded use leaves a placeholder,
resolved at generalisation as a dictionary parameter, an instance's
dictionary, a superclass's, deferred outward, or defaulted. Declaration
groups by dependency, explicitly typed bindings apart (Typing Haskell in
Haskell's split, R21(c)), one context for each implicit group (R21(a)),
the contexts of a group's signatures identical up to renaming (R21(b)),
a signature on a pattern binding that is not simple refused (R19), and
the monomorphism restriction by 4.5.5's simple pattern binding (R18).
A restricted group's constrained variables stay open, and at the top
level are defaulted at the end of the module (R20), by the `default` of
the module their constraints arose in, refused where two modules'
differ, and refused where another module of the cycle fixes one (D30);
under `--cycle-default=scc`, by the group's one `default`, and closed at
the end of the group (an extension). Defaulting by 4.3.4's conditions
(R22).

## Interface

<pre>
signature HS_INFER =
sig
  type <a href="#type-env">env</a>
  val <a href="#val-initial">initial</a> : {<a href="#fld-initial.primitives">primitives</a> : string list} -&gt; env
  datatype <a href="#type-cycledefault">cycleDefault</a> = <a href="#con-permodule">PerModule</a> | <a href="#con-pergroup">PerGroup</a>
  type <a href="#type-module_">module_</a> = {<a href="#fld-module_.id">id</a> : string, <a href="#fld-module_.ast">ast</a> : HsAst.module, <a href="#fld-module_.library">library</a> : bool}
  val <a href="#val-check">check</a> : {<a href="#fld-check.env">env</a> : env, <a href="#fld-check.unit">unit</a> : module_ list, <a href="#fld-check.cycledefault">cycleDefault</a> : cycleDefault,
               <a href="#fld-check.prelude">prelude</a> : string * string -&gt; string option, <a href="#fld-check.evidence">evidence</a> : HsEvidence.table}
              -&gt; {env : env, errors : (HsSource.span * string) list}
  val <a href="#val-valuescheme">valueScheme</a> : env * string -&gt; HsTypes.scheme option
  val <a href="#val-classes">classes</a> : env -&gt; HsClasses.env
end
</pre>

### <a name="type-env"></a>`env`

```sml
type env
```

What the checker knows of the program before a unit: the types of
its values, its type constructors, classes and instances.

### <a name="val-initial"></a>`initial`

```sml
val initial : {primitives : string list} -> env
```

`initial {primitives}` is the environment with the built-in types and
constructors alone, and the values `primitives`.

Each primitive has the type `forall a. a`, until the overlay types
them (M17).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-initial.primitives"></a>`primitives` | `string list` |  |

### <a name="type-cycledefault"></a>`cycleDefault`

```sml
datatype cycleDefault = PerModule | PerGroup
```

Where Rule 2 closes and which `default` holds in a cycle (D30).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-permodule"></a>`PerModule` |  |  |
| <a name="con-pergroup"></a>`PerGroup` |  |  |

### <a name="type-module_"></a>`module_`

```sml
type module_ = {id : string, ast : HsAst.module, library : bool}
```

A module of a unit: its identity, its renamed and resolved tree, and
whether it is the library's.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-module_.id"></a>`id` | `string` |  |
| <a name="fld-module_.ast"></a>`ast` | `HsAst.module` |  |
| <a name="fld-module_.library"></a>`library` | `bool` |  |

### <a name="val-check"></a>`check`

```sml
val check : {env : env, unit : module_ list, cycleDefault : cycleDefault,
             prelude : string * string -> string option, evidence : HsEvidence.table}
            -> {env : env, errors : (HsSource.span * string) list}
```

`check {env, unit, cycleDefault, prelude, evidence}` checks the
modules of `unit`, recording into `evidence`.

It gives the environment with the unit's types, constructors,
classes, instances and values, and the errors. `prelude (space, name)` is the key of
the entity the Prelude exports under `name`, `"t"` for a type or
class and `"v"` for a value, for what the Report's translations
name: [`Bool`](../../../basis/str/Bool.md), [`Char`](../../../basis/str/Char.md), `Integer`, `Double`, `Num`, `Fractional`,
`Eq`, `Ord`, `Enum`, `Integral`, `Monad`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-check.env"></a>`env` | `env` |  |
| <a name="fld-check.unit"></a>`unit` | `module_ list` |  |
| <a name="fld-check.cycledefault"></a>`cycleDefault` | `cycleDefault` |  |
| <a name="fld-check.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-check.evidence"></a>`evidence` | `HsEvidence.table` |  |

### <a name="val-valuescheme"></a>`valueScheme`

```sml
val valueScheme : env * string -> HsTypes.scheme option
```

`valueScheme (env, key)` is the type of the value of `key`.

### <a name="val-classes"></a>`classes`

```sml
val classes : env -> HsClasses.env
```

`classes env` is the classes and instances of `env`.

---

<sub>Generated by runedoc from lib/language/haskell/infer\_sig.sml; do not edit.</sub>
