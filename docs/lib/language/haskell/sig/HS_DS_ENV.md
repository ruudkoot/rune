# signature HS_DS_ENV

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_DS_ENV**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 49 of 49 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/desugar\_env\_sig.sml](../../../../../lib/language/haskell/desugar_env_sig.sml) |

## Synopsis

```sml
signature HS_DS_ENV
structure HsDsEnv :> HS_DS_ENV
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsDsEnv`](../str/HsDsEnv.md) |  | [lib/language/haskell/desugar\_env.sml](../../../../../lib/language/haskell/desugar_env.sml) |

What desugaring knows of a checked program (the haskell98 roadmap's
M15): its names, types, records and dictionaries in Core.

It holds the names the program's entities have in Core, its types made
Core's, the checker's evidence records (D31) by node, its dictionaries,
and the primitives of rhc's library made functions of Haskell's types.

An entity of the top level is named in Core by its module's identity, a
dot and its name, haskell98:Prelude.map or Main.f; a local keeps the
renamer's unique name, x\#3. What desugaring makes has a name starting
with %: a class's dictionary constructor, %dict:C, an instance's
dictionary function, %inst:C@T, a superclass's selector, %super:C\>S, a
class's default method, %dm:m.

Types: a type constructor of the program is named as its entity; the
Prelude's [`Bool`](../../../basis/str/Bool.md) is Core's [`Bool`](../../../basis/str/Bool.md), and a type that a module of the
library declares with no constructor is Core's own ([`Int`](../../../basis/str/Int.md), `Integer`,
[`Char`](../../../basis/str/Char.md), `Float`, `Double`, `Str`, `Ref`), PreludeIO's `IOError` Core's
`Exn`, and [`IO`](../../../basis/sig/IO.md) the newtype [`IO`](../../../basis/sig/IO.md) over `World -> (utuple World a)` (D25),
a type constructor of its own so that `Monad IO` has a dictionary. A
class is the data type of its dictionaries, of the same name: its
direct superclasses' dictionaries, then its methods, each of the type
of its own scheme.

## Contents

[The program](#the-program) &middot;
[Names](#names) &middot;
[Scopes](#scopes) &middot;
[Types](#types) &middot;
[Records](#records) &middot;
[Expressions](#expressions)

## Interface

<pre>
signature HS_DS_ENV =
sig
  type <a href="#type-program">program</a> = {<a href="#fld-program.infer">infer</a> : HsInfer.env, <a href="#fld-program.evidence">evidence</a> : HsEvidence.table, <a href="#fld-program.prelude">prelude</a> : string * string -&gt; string option,
                  <a href="#fld-program.library">library</a> : string -&gt; bool, <a href="#fld-program.entity">entity</a> : string * string * string -&gt; string}
  val <a href="#val-start">start</a> : program -&gt; unit
  val <a href="#val-classes">classes</a> : unit -&gt; HsClasses.env
  val <a href="#val-valuescheme">valueScheme</a> : string -&gt; HsTypes.scheme option
  val <a href="#val-prelude">prelude</a> : string * string -&gt; string
  val <a href="#val-islibrary">isLibrary</a> : string -&gt; bool
  val <a href="#val-libraryentity">libraryEntity</a> : string * string * string -&gt; string
  val <a href="#val-setfields">setFields</a> : string * string list -&gt; unit
  val <a href="#val-fieldsof">fieldsOf</a> : string -&gt; string list
  val <a href="#val-corename">coreName</a> : string -&gt; string
  val <a href="#val-valuekey">valueKey</a> : HsAst.name -&gt; string
  val <a href="#val-homeof">homeOf</a> : string -&gt; string
  val <a href="#val-nameof">nameOf</a> : string -&gt; string
  val <a href="#val-tyconname">tyconName</a> : string -&gt; string
  val <a href="#val-conname">conName</a> : string -&gt; string
  val <a href="#val-primtype">primType</a> : string * string -&gt; unit
  val <a href="#val-isprimtype">isPrimType</a> : string -&gt; bool
  val <a href="#val-builtincon">builtinCon</a> : string * string -&gt; unit
  val <a href="#val-dictcon">dictCon</a> : string -&gt; string
  val <a href="#val-dfunname">dfunName</a> : string -&gt; string
  val <a href="#val-supername">superName</a> : string * string -&gt; string
  val <a href="#val-defaultname">defaultName</a> : string -&gt; string
  type <a href="#type-env">env</a>
  val <a href="#val-empty">empty</a> : env
  val <a href="#val-bind">bind</a> : env * string * Core.atom * Core.ty -&gt; env
  val <a href="#val-lookup">lookup</a> : env * string -&gt; (Core.atom * Core.ty) option
  val <a href="#val-bindtypes">bindTypes</a> : env * (string * Core.kind) list -&gt; env
  val <a href="#val-typevars">typeVars</a> : env -&gt; (string * Core.kind) list
  val <a href="#val-ty">ty</a> : env -&gt; HsTypes.ty -&gt; Core.ty
  val <a href="#val-tygen">tyGen</a> : env * Core.ty list -&gt; HsTypes.ty -&gt; Core.ty
  val <a href="#val-predty">predTy</a> : env -&gt; HsTypes.pred -&gt; Core.ty
  val <a href="#val-scheme">scheme</a> : env -&gt; HsEvidence.scheme -&gt; Core.ty * (string * Core.kind) list
  val <a href="#val-genscheme">genScheme</a> : HsTypes.scheme -&gt; Core.ty
  val <a href="#val-ioty">ioTy</a> : Core.ty -&gt; Core.ty
  val <a href="#val-records">records</a> : string * HsSource.span -&gt; HsEvidence.record list
  val <a href="#val-useof">useOf</a> : HsSource.span -&gt; {<a href="#fld-useof.tys">tys</a> : HsTypes.ty list, <a href="#fld-useof.dicts">dicts</a> : HsEvidence.dict list}
  val <a href="#val-bindof">bindOf</a> : HsSource.span -&gt; HsEvidence.record option
  val <a href="#val-overloadedof">overloadedOf</a> : string * HsSource.span -&gt; HsTypes.ty * (string * HsEvidence.dict) list
  val <a href="#val-dict">dict</a> : env -&gt; HsEvidence.dict -&gt; HsDsCore.texp
  val <a href="#val-instantiate">instantiate</a> : env -&gt; HsDsCore.texp * HsTypes.ty list * HsEvidence.dict list -&gt; HsDsCore.texp
  val <a href="#val-global">global</a> : string -&gt; HsDsCore.texp
  val <a href="#val-method">method</a> : env -&gt; string * Core.ty list * HsDsCore.texp list -&gt; HsDsCore.texp
  val <a href="#val-superdict">superDict</a> : env -&gt; HsEvidence.dict * string * string -&gt; HsEvidence.dict
  val <a href="#val-integerlit">integerLit</a> : env -&gt; IntInf.int * HsTypes.ty * HsEvidence.dict -&gt; HsDsCore.texp
  val <a href="#val-rationallit">rationalLit</a> : env -&gt; string * HsTypes.ty * HsEvidence.dict -&gt; HsDsCore.texp
  val <a href="#val-stringlit">stringLit</a> : int list -&gt; HsDsCore.texp
  val <a href="#val-tohaskell">toHaskell</a> : HsDsCore.texp * Core.ty -&gt; HsDsCore.texp
  val <a href="#val-matchtype">matchType</a> : Core.ty * string list * Core.ty -&gt; Core.ty list option
  val <a href="#val-haskellform">haskellForm</a> : Core.ty -&gt; Core.ty
end
</pre>

## The program

### <a name="type-program"></a>`program`

```sml
type program = {infer : HsInfer.env, evidence : HsEvidence.table, prelude : string * string -> string option,
                library : string -> bool, entity : string * string * string -> string}
```

What a desugaring is given: the checker's environment and records, and
how to find the entities the translations name.

They are the checker's environment after the last unit, its evidence
records, the key of what the Prelude exports by space (`"v"` or `"t"`)
and name, whether a module's identity is the library's, and the key of
an entity of a module of the library by its space, the module's name
and its name: Ratio's `:%`, which a floating literal is made of, though
the Prelude does not export it (E9).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-program.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-program.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-program.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-program.library"></a>`library` | `string -> bool` |  |
| <a name="fld-program.entity"></a>`entity` | `string * string * string -> string` |  |

### <a name="val-start"></a>`start`

```sml
val start : program -> unit
```

`start p` makes `p` the program desugared, forgetting the last.

### <a name="val-classes"></a>`classes`

```sml
val classes : unit -> HsClasses.env
```

`classes ()` is the program's classes and instances.

### <a name="val-valuescheme"></a>`valueScheme`

```sml
val valueScheme : string -> HsTypes.scheme option
```

`valueScheme key` is the type the checker gave the value `key`.

### <a name="val-prelude"></a>`prelude`

```sml
val prelude : string * string -> string
```

`prelude (space, name)` is the key of what the Prelude exports.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) where it exports no such name, a fault of the
library.

### <a name="val-islibrary"></a>`isLibrary`

```sml
val isLibrary : string -> bool
```

`isLibrary id` is whether the module of identity `id` is the
library's.

### <a name="val-libraryentity"></a>`libraryEntity`

```sml
val libraryEntity : string * string * string -> string
```

`libraryEntity (space, module, name)` is the key of an entity of a
module of the library.

### <a name="val-setfields"></a>`setFields`

```sml
val setFields : string * string list -> unit
```

`setFields (con, fields)` records the fields of the constructor
`con`, by their keys in order, `""` for one without a name.

### <a name="val-fieldsof"></a>`fieldsOf`

```sml
val fieldsOf : string -> string list
```

`fieldsOf con` is the fields of the constructor `con`.

## Names

### <a name="val-corename"></a>`coreName`

```sml
val coreName : string -> string
```

`coreName key` is the Core name of the entity `key`.

### <a name="val-valuekey"></a>`valueKey`

```sml
val valueKey : HsAst.name -> string
```

`valueKey n` is the key of the value the name `n` of the renamed tree
stands for.

It is a top-level entity's key, a local's own name, or a built-in
constructor's (`()`, `[]`, `:`, `(,)`).

### <a name="val-homeof"></a><a name="val-nameof"></a>`homeOf`, `nameOf`

```sml
val homeOf : string -> string
val nameOf : string -> string
```

`homeOf key` and `nameOf key` are the parts of an entity's key.

### <a name="val-tyconname"></a>`tyconName`

```sml
val tyconName : string -> string
```

`tyconName key` is the type constructor of Core that the type
constructor `key` is.

### <a name="val-conname"></a>`conName`

```sml
val conName : string -> string
```

`conName key` is the constructor of Core that the data constructor
`key` is.

### <a name="val-primtype"></a>`primType`

```sml
val primType : string * string -> unit
```

`primType (key, core)` makes the type `key`, which a module of the
library declares with no constructor, Core's type `core`.

### <a name="val-isprimtype"></a>`isPrimType`

```sml
val isPrimType : string -> bool
```

`isPrimType key` is whether the type `key` is Core's own.

### <a name="val-builtincon"></a>`builtinCon`

```sml
val builtinCon : string * string -> unit
```

`builtinCon (key, core)` makes the constructor `key` Core's `core`,
as the Prelude's `True` is Core's.

### <a name="val-dictcon"></a>`dictCon`

```sml
val dictCon : string -> string
```

`dictCon cls` is the constructor of the dictionaries of the class
`cls`.

### <a name="val-dfunname"></a>`dfunName`

```sml
val dfunName : string -> string
```

`dfunName id` is the dictionary function of the instance `id`.

### <a name="val-supername"></a>`superName`

```sml
val superName : string * string -> string
```

`superName (cls, super)` is the selector of the superclass `super`
from a dictionary of `cls`.

### <a name="val-defaultname"></a>`defaultName`

```sml
val defaultName : string -> string
```

`defaultName method` is the default of the method `method`.

## Scopes

### <a name="type-env"></a>`env`

```sml
type env
```

What is in scope where an expression is desugared.

It holds the variables, each the atom of Core it is and its type,
dictionary parameters among them, and the type variables with their
kinds.

### <a name="val-empty"></a>`empty`

```sml
val empty : env
```

[`empty`](#val-empty) is the scope of the top level.

### <a name="val-bind"></a>`bind`

```sml
val bind : env * string * Core.atom * Core.ty -> env
```

`bind (env, x, atom, t)` is `env` with `x` the atom `atom` of type
`t`.

### <a name="val-lookup"></a>`lookup`

```sml
val lookup : env * string -> (Core.atom * Core.ty) option
```

`lookup (env, x)` is the atom `x` is and its type.

### <a name="val-bindtypes"></a>`bindTypes`

```sml
val bindTypes : env * (string * Core.kind) list -> env
```

`bindTypes (env, vars)` is `env` with the type variables `vars`.

### <a name="val-typevars"></a>`typeVars`

```sml
val typeVars : env -> (string * Core.kind) list
```

`typeVars env` is the type variables in scope.

## Types

### <a name="val-ty"></a>`ty`

```sml
val ty : env -> HsTypes.ty -> Core.ty
```

`ty env t` is the Core type of `t`, a closed type of the records.

A rigid variable not in scope stands for nothing a value can be of, a
variable of another binding of a group that this one's type does not
hold, and is `()`.

### <a name="val-tygen"></a>`tyGen`

```sml
val tyGen : env * Core.ty list -> HsTypes.ty -> Core.ty
```

`tyGen (env, gens) t` is the Core type of `t`, whose `TGen i` is the
`i`th of `gens`.

### <a name="val-predty"></a>`predTy`

```sml
val predTy : env -> HsTypes.pred -> Core.ty
```

`predTy env p` is the type of the dictionaries of the predicate `p`.

### <a name="val-scheme"></a>`scheme`

```sml
val scheme : env -> HsEvidence.scheme -> Core.ty * (string * Core.kind) list
```

`scheme env s` is the type of a value of the scheme `s` of the
records, and its variables with their kinds.

The type is a forall over its variables, with their kinds, of a
function of its context's dictionaries, in order, giving its type.

### <a name="val-genscheme"></a>`genScheme`

```sml
val genScheme : HsTypes.scheme -> Core.ty
```

`genScheme s` is the type of a value of the checker's scheme `s`, its
variables named `g1`, `g2` and on.

### <a name="val-ioty"></a>`ioTy`

```sml
val ioTy : Core.ty -> Core.ty
```

`ioTy t` is `IO t`.

## Records

### <a name="val-records"></a>`records`

```sml
val records : string * HsSource.span -> HsEvidence.record list
```

`records (kind, span)` is the records at a node.

### <a name="val-useof"></a>`useOf`

```sml
val useOf : HsSource.span -> {tys : HsTypes.ty list, dicts : HsEvidence.dict list}
```

`useOf span` is the types and dictionaries of the variable or
constructor used at `span`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-useof.tys"></a>`tys` | `HsTypes.ty list` |  |
| <a name="fld-useof.dicts"></a>`dicts` | `HsEvidence.dict list` |  |

### <a name="val-bindof"></a>`bindOf`

```sml
val bindOf : HsSource.span -> HsEvidence.record option
```

`bindOf span` is the record of the binder at `span`.

### <a name="val-overloadedof"></a>`overloadedOf`

```sml
val overloadedOf : string * HsSource.span -> HsTypes.ty * (string * HsEvidence.dict) list
```

`overloadedOf (kind, span)` is the type and the dictionaries by class
of a construct the Report translates through a class.

## Expressions

### <a name="val-dict"></a>`dict`

```sml
val dict : env -> HsEvidence.dict -> HsDsCore.texp
```

`dict env d` is the dictionary `d`.

### <a name="val-instantiate"></a>`instantiate`

```sml
val instantiate : env -> HsDsCore.texp * HsTypes.ty list * HsEvidence.dict list -> HsDsCore.texp
```

`instantiate env (f, tys, dicts)` is `f` at the types `tys` and the
dictionaries `dicts`, as a use's record gives them.

### <a name="val-global"></a>`global`

```sml
val global : string -> HsDsCore.texp
```

`global key` is the value `key` of the top level, at its type, before
any is given it.

### <a name="val-method"></a>`method`

```sml
val method : env -> string * Core.ty list * HsDsCore.texp list -> HsDsCore.texp
```

`method env (key, tys, dicts)` is the value `key`, a method of the
Prelude's or a function, at the Core types `tys` and the dictionaries
`dicts`.

### <a name="val-superdict"></a>`superDict`

```sml
val superDict : env -> HsEvidence.dict * string * string -> HsEvidence.dict
```

`superDict env (d, cls, super)` is the dictionary of `super`, a
superclass of `cls`, taken from `d`, a dictionary of `cls`.

It goes by the path of direct superclasses between them.

### <a name="val-integerlit"></a>`integerLit`

```sml
val integerLit : env -> IntInf.int * HsTypes.ty * HsEvidence.dict -> HsDsCore.texp
```

`integerLit env (i, t, num)` is the integer literal `i` at the type
`t`, of which `num` is the `Num` dictionary.

It is `fromInteger i` (3.2), but an [`Int`](../../../basis/str/Int.md) in range or an `Integer`
itself, where `num` is the Prelude's instance at that type.

### <a name="val-rationallit"></a>`rationalLit`

```sml
val rationalLit : env -> string * HsTypes.ty * HsEvidence.dict -> HsDsCore.texp
```

`rationalLit env (text, t, fractional)` is the floating literal
written `text` at the type `t`.

It is `fromRational` of Ratio's `n :% d`, `n/d` its value in lowest
terms (3.2), but a `Double` or a `Float` itself where `fractional` is
the Prelude's instance at that type.

### <a name="val-stringlit"></a>`stringLit`

```sml
val stringLit : int list -> HsDsCore.texp
```

`stringLit chars` is a string literal of the code points `chars`.

Its bytes in UTF-8 are unpacked lazily by the runtime's
`primUnpackString` (D24's A).

### <a name="val-tohaskell"></a>`toHaskell`

```sml
val toHaskell : HsDsCore.texp * Core.ty -> HsDsCore.texp
```

`toHaskell (x, want)` is `x`, a value of a type of Core's own making,
as a value of `want`, the Core type of a Haskell type.

A primitive's [`!`](../../../basis/sig/GENERAL.md#val-op-bang) parameters are forced, and an action
`World -> (utuple World a)` is made `IO a`.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) where the two differ otherwise.

### <a name="val-matchtype"></a>`matchType`

```sml
val matchType : Core.ty * string list * Core.ty -> Core.ty list option
```

`matchType (pattern, vars, t)` is the types that `vars`, variables of
`pattern`, stand for where `pattern` is `t`.

The two are compared as [`toHaskell`](#val-tohaskell) sees them; `NONE` where they
differ.

### <a name="val-haskellform"></a>`haskellForm`

```sml
val haskellForm : Core.ty -> Core.ty
```

`haskellForm t` is the type of Core's own making `t` as Haskell sees
it: no [`!`](../../../basis/sig/GENERAL.md#val-op-bang), and `IO a` for `World -> (utuple World a)`.

---

<sub>Generated by runedoc from lib/language/haskell/desugar\_env\_sig.sml; do not edit.</sub>
