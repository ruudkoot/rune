# signature HS_USAGE

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_USAGE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 5 of 5 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/usage\_sig.sml](../../../../../lib/language/haskell/usage_sig.sml) |

## Synopsis

```sml
signature HS_USAGE
structure HsUsage :> HS_USAGE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsUsage`](../str/HsUsage.md) |  | [lib/language/haskell/usage.sml](../../../../../lib/language/haskell/usage.sml) |

What a compile of a unit reads of the units it imports (the haskell98
roadmap's M21, E13's obligations H1, H2, H7 and H9), noted where the
renamer, the checker and the translations read it, so that a store's
entry of the unit is used only where each read gives now what it gave
then. A read is noted found or not: a name a module looks up and does
not find is read too, since an import that comes to export it changes
the module (5.5.2). The note is a no-op until a driver sets it (rhc's,
src/rhc/iface.sml).

## Interface

<pre>
signature HS_USAGE =
sig
  datatype <a href="#type-read">read</a> =
      <a href="#con-name">Name</a> of {<a href="#fld-name.within">within</a> : string, <a href="#fld-name.space">space</a> : string, <a href="#fld-name.qual">qual</a> : string, <a href="#fld-name.name">name</a> : string}
    | <a href="#con-item">Item</a> of {<a href="#fld-item.from">from</a> : string, <a href="#fld-item.space">space</a> : string, <a href="#fld-item.name">name</a> : string}
    | <a href="#con-exports">Exports</a> of string
    | <a href="#con-instance">Instance</a> of {<a href="#fld-instance.cls">cls</a> : string, <a href="#fld-instance.tycon">tycon</a> : string}
    | <a href="#con-standard">Standard</a> of {<a href="#fld-standard.space">space</a> : string, <a href="#fld-standard.name">name</a> : string}
    | <a href="#con-entity">Entity</a> of string
  val <a href="#val-setnote">setNote</a> : (read -&gt; unit) -&gt; (read -&gt; unit)
  val <a href="#val-read">read</a> : read -&gt; unit
  val <a href="#val-key">key</a> : read -&gt; string
  val <a href="#val-fromkey">fromKey</a> : string -&gt; read option
end
</pre>

### <a name="type-read"></a>`read`

```sml
datatype read =
    Name of {within : string, space : string, qual : string, name : string}
  | Item of {from : string, space : string, name : string}
  | Exports of string
  | Instance of {cls : string, tycon : string}
  | Standard of {space : string, name : string}
  | Entity of string
```

A read. Spaces are `"v"` for a value and `"t"` for a type or class,
and entities, classes and type constructors are by their keys
(HsModules.key).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-name"></a>`Name` | `{within : string, space : string, qual : string, name : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-name.within"></a>`within` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-name.space"></a>`space` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-name.qual"></a>`qual` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-name.name"></a>`name` | `string` |  |
| <a name="con-item"></a>`Item` | `{from : string, space : string, name : string}` | a name looked up in the scope of the module of identity `within`, by the renamer or by its export list, qualified by `qual` or not (`""`), found or not (H1) |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-item.from"></a>`from` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-item.space"></a>`space` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-item.name"></a>`name` | `string` |  |
| <a name="con-exports"></a>`Exports` | `string` | an item of an import list, a name of what the module of identity `from` exports (H1) |
| <a name="con-instance"></a>`Instance` | `{cls : string, tycon : string}` | every export of the module of that identity, as `module M` in an export list reads them (H7) |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.cls"></a>`cls` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.tycon"></a>`tycon` | `string` |  |
| <a name="con-standard"></a>`Standard` | `{space : string, name : string}` | the instance of a class at a type constructor, looked up by the checker or by deriving's fixpoint, found or not (H2) |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-standard.space"></a>`space` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-standard.name"></a>`name` | `string` |  |
| <a name="con-entity"></a>`Entity` | `string` | what the Prelude exports under a name the translations of the Report name, `Bool` or `>>=` (H9) |

an entity the translations name by its key, a program unable to
shadow it, as Ratio's % (H9)

### <a name="val-setnote"></a>`setNote`

```sml
val setNote : (read -> unit) -> (read -> unit)
```

`setNote f` makes `f` the recorder, called with each read as it is
made, and is the recorder before it: until a driver sets one, a no-op.

### <a name="val-read"></a>`read`

```sml
val read : read -> unit
```

`read r` notes `r`.

### <a name="val-key"></a>`key`

```sml
val key : read -> string
```

`key r` is `r` as one line of text, its fields apart by spaces, the
name of a store's usage.

**Example** `key (Exports "M") = "exports M"`

### <a name="val-fromkey"></a>`fromKey`

```sml
val fromKey : string -> read option
```

`fromKey s` is the read whose key is `s`, NONE for none.

---

<sub>Generated by runedoc from lib/language/haskell/usage\_sig.sml; do not edit.</sub>
