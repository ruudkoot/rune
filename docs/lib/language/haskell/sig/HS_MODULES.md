# signature HS_MODULES

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_MODULES**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/modules\_sig.sml](../../../../../lib/language/haskell/modules_sig.sml) |

## Synopsis

```sml
signature HS_MODULES
structure HsModules :> HS_MODULES
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsModules`](../str/HsModules.md) |  | [lib/language/haskell/modules.sml](../../../../../lib/language/haskell/modules.sml) |

The names of Haskell 98's modules (the Report's chapter 5; the haskell98
roadmap's D29, D30): what each module defines, what it exports, and what
is in scope in it, over a group of modules that import one another.

An entity is a thing a name can stand for: its name space, the module
that defines it, by that module's identity, and its name. A name stands
for zero, one or several entities, and is an error only where it is used
and stands for other than one, in the manner of Diatchki, Jones and
Hallgren 2002. Within a strongly connected group of modules the exports
and the scopes are defined by each other, and are solved by iteration:
from nothing, the least fixpoint (D29's A, the default), or from
everything, the greatest. Instances are not names, and every instance a
program declares is visible in all of it.

## Interface

<pre>
signature HS_MODULES =
sig
  datatype <a href="#type-space">space</a> = <a href="#con-value">Value</a> | <a href="#con-type">Type</a>
  type <a href="#type-entity">entity</a> = {<a href="#fld-entity.space">space</a> : space, <a href="#fld-entity.home">home</a> : string, <a href="#fld-entity.name">name</a> : string}
  val <a href="#val-key">key</a> : entity -&gt; string
  val <a href="#val-modulename">moduleName</a> : string -&gt; string
  datatype <a href="#type-sort">sort</a> =
      <a href="#con-var">Var</a>
    | <a href="#con-con">Con</a>
    | <a href="#con-field">Field</a>
    | <a href="#con-method">Method</a>
    | <a href="#con-tycon">TyCon</a>
    | <a href="#con-synonym">Synonym</a>
    | <a href="#con-class">Class</a>
  type <a href="#type-def">def</a> = {<a href="#fld-def.entity">entity</a> : entity, <a href="#fld-def.sort">sort</a> : sort, <a href="#fld-def.parent">parent</a> : entity option, <a href="#fld-def.arity">arity</a> : int, <a href="#fld-def.span">span</a> : HsSource.span}
  val <a href="#val-defs">defs</a> : string * HsAst.module -&gt; def list
  type <a href="#type-unit_">unit_</a> = {<a href="#fld-unit_.id">id</a> : string, <a href="#fld-unit_.name">name</a> : string, <a href="#fld-unit_.ast">ast</a> : HsAst.module, <a href="#fld-unit_.imports">imports</a> : (HsAst.import * string) list}
  type <a href="#type-scope">scope</a> = entity list HsStringMap.map
  val <a href="#val-scopekey">scopeKey</a> : space * string * string -&gt; string
  val <a href="#val-lookup">lookup</a> : scope * space * string * string -&gt; entity list
  datatype <a href="#type-fixpoint">fixpoint</a> = <a href="#con-least">Least</a> | <a href="#con-greatest">Greatest</a>
  type <a href="#type-solved">solved</a> = {<a href="#fld-solved.exports">exports</a> : entity list HsStringMap.map, <a href="#fld-solved.scopes">scopes</a> : scope HsStringMap.map,
                 <a href="#fld-solved.errors">errors</a> : (HsSource.span * string) list}
  val <a href="#val-solve">solve</a> : {<a href="#fld-solve.group">group</a> : unit_ list, <a href="#fld-solve.exportsof">exportsOf</a> : string -&gt; entity list, <a href="#fld-solve.defof">defOf</a> : string -&gt; def option,
               <a href="#fld-solve.universe">universe</a> : entity list, <a href="#fld-solve.fixpoint">fixpoint</a> : fixpoint} -&gt; solved
end
</pre>

### <a name="type-space"></a>`space`

```sml
datatype space = Value | Type
```

The two name spaces: values (variables, constructors, fields,
methods) and types (type constructors, synonyms, classes).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-value"></a>`Value` |  |  |
| <a name="con-type"></a>`Type` |  |  |

### <a name="type-entity"></a>`entity`

```sml
type entity = {space : space, home : string, name : string}
```

An entity: its space, the identity of the module that defines it, and
its name.

A module's identity is its name for a module of the program, and its
library's name, a colon and its name for a library's: a program's
[`Char`](../../../basis/str/Char.md) is not the library's.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-entity.space"></a>`space` | `space` |  |
| <a name="fld-entity.home"></a>`home` | `string` |  |
| <a name="fld-entity.name"></a>`name` | `string` |  |

### <a name="val-key"></a>`key`

```sml
val key : entity -> string
```

`key e` is `e` as a string, unique to it, for maps and sets.

### <a name="val-modulename"></a>`moduleName`

```sml
val moduleName : string -> string
```

`moduleName id` is the name of the module of identity `id`, without
its library.

### <a name="type-sort"></a>`sort`

```sml
datatype sort =
    Var
  | Con
  | Field
  | Method
  | TyCon
  | Synonym
  | Class
```

What a top-level definition is.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-var"></a>`Var` |  | a variable |
| <a name="con-con"></a>`Con` |  | a data constructor |
| <a name="con-field"></a>`Field` |  | a field of a record |
| <a name="con-method"></a>`Method` |  | a class's method |
| <a name="con-tycon"></a>`TyCon` |  | a type constructor of `data` or `newtype` |
| <a name="con-synonym"></a>`Synonym` |  | a type synonym |
| <a name="con-class"></a>`Class` |  | a class |

### <a name="type-def"></a>`def`

```sml
type def = {entity : entity, sort : sort, parent : entity option, arity : int, span : HsSource.span}
```

A top-level definition: its entity, what it is, and where it is.

With them, the type or class it belongs to, for a constructor, a field
or a method, and the number of arguments a constructor takes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-def.entity"></a>`entity` | `entity` |  |
| <a name="fld-def.sort"></a>`sort` | `sort` |  |
| <a name="fld-def.parent"></a>`parent` | `entity option` |  |
| <a name="fld-def.arity"></a>`arity` | `int` |  |
| <a name="fld-def.span"></a>`span` | `HsSource.span` |  |

### <a name="val-defs"></a>`defs`

```sml
val defs : string * HsAst.module -> def list
```

`defs (id, m)` is what the module `m` of identity `id` defines at its
top level, each once, in the order of the source.

### <a name="type-unit_"></a>`unit_`

```sml
type unit_ = {id : string, name : string, ast : HsAst.module, imports : (HsAst.import * string) list}
```

A module as resolution reads it: its identity, its name, its tree,
and its imports.

Each import has the identity of the module it names, the implicit
import of the Prelude among them where the module has one.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-unit_.id"></a>`id` | `string` |  |
| <a name="fld-unit_.name"></a>`name` | `string` |  |
| <a name="fld-unit_.ast"></a>`ast` | `HsAst.module` |  |
| <a name="fld-unit_.imports"></a>`imports` | `(HsAst.import * string) list` |  |

### <a name="type-scope"></a>`scope`

```sml
type scope = entity list HsStringMap.map
```

What is in scope in a module: the entities a name stands for, by
[`scopeKey`](#val-scopekey).

### <a name="val-scopekey"></a>`scopeKey`

```sml
val scopeKey : space * string * string -> string
```

`scopeKey (space, qual, name)` is the key of the name `name` qualified
by `qual`, `""` for none, in the space `space`.

### <a name="val-lookup"></a>`lookup`

```sml
val lookup : scope * space * string * string -> entity list
```

`lookup (scope, space, qual, name)` is the entities the name stands
for: none, one, or several.

### <a name="type-fixpoint"></a>`fixpoint`

```sml
datatype fixpoint = Least | Greatest
```

The fixpoint to take where a group's exports admit several.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-least"></a>`Least` |  |  |
| <a name="con-greatest"></a>`Greatest` |  |  |

### <a name="type-solved"></a>`solved`

```sml
type solved = {exports : entity list HsStringMap.map, scopes : scope HsStringMap.map,
               errors : (HsSource.span * string) list}
```

What [`solve`](#val-solve) makes of a group: each module's exports and scope, by
identity, and the errors of the group's export and import lists.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-solved.exports"></a>`exports` | `entity list HsStringMap.map` |  |
| <a name="fld-solved.scopes"></a>`scopes` | `scope HsStringMap.map` |  |
| <a name="fld-solved.errors"></a>`errors` | `(HsSource.span * string) list` |  |

### <a name="val-solve"></a>`solve`

```sml
val solve : {group : unit_ list, exportsOf : string -> entity list, defOf : string -> def option,
             universe : entity list, fixpoint : fixpoint} -> solved
```

`solve {group, exportsOf, defOf, universe, fixpoint}` solves the
exports and the scopes of the strongly connected group of modules
`group`.

`exportsOf id` gives the exports of a module outside the group,
solved before it, `defOf` gives the definition of every entity of the
program, by [`key`](#val-key), and `universe` is every entity of the program,
from which the greatest fixpoint starts. The errors are
those of chapter 5: an export of what is not in scope, of a module
that is not imported, two entities exported under one name, an import
of what a module does not export.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-solve.group"></a>`group` | `unit_ list` |  |
| <a name="fld-solve.exportsof"></a>`exportsOf` | `string -> entity list` |  |
| <a name="fld-solve.defof"></a>`defOf` | `string -> def option` |  |
| <a name="fld-solve.universe"></a>`universe` | `entity list` |  |
| <a name="fld-solve.fixpoint"></a>`fixpoint` | `fixpoint` |  |

---

<sub>Generated by runedoc from lib/language/haskell/modules\_sig.sml; do not edit.</sub>
