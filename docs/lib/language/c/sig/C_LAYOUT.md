# signature C_LAYOUT

[C declaration frontend](../README.md) &rsaquo; Languages &rsaquo; **C_LAYOUT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/language/c/layout\_sig.sml](../../../../../lib/language/c/layout_sig.sml) |

## Synopsis

```sml
signature C_LAYOUT
structure CLayout : C_LAYOUT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CLayout`](../str/CLayout.md) |  | [lib/language/c/layout.sml](../../../../../lib/language/c/layout.sml) |

Explicit target layouts for reusable C declaration consumers.

## Interface

<pre>
signature C_LAYOUT =
sig
  type <a href="#type-source">source</a> = CLex.location
  type <a href="#type-scalar">scalar</a> = {<a href="#fld-scalar.size">size</a> : int, <a href="#fld-scalar.alignment">alignment</a> : int, <a href="#fld-scalar.signed">signed</a> : bool option}
  type <a href="#type-target">target</a> = {<a href="#fld-target.name">name</a> : string, <a href="#fld-target.pointer">pointer</a> : scalar, <a href="#fld-target.enumeration">enumeration</a> : scalar,
    <a href="#fld-target.scalars">scalars</a> : (string * scalar) list, <a href="#fld-target.maximumobject">maximumObject</a> : IntInf.int}
  datatype <a href="#type-layout">layout</a> = <a href="#con-atom">Atom</a> of {<a href="#fld-atom.size">size</a> : IntInf.int, <a href="#fld-atom.alignment">alignment</a> : int}
    | <a href="#con-sequence">Sequence</a> of {<a href="#fld-sequence.size">size</a> : IntInf.int, <a href="#fld-sequence.alignment">alignment</a> : int, <a href="#fld-sequence.count">count</a> : IntInf.int, <a href="#fld-sequence.element">element</a> : layout}
    | <a href="#con-aggregate">Aggregate</a> of {<a href="#fld-aggregate.size">size</a> : IntInf.int, <a href="#fld-aggregate.alignment">alignment</a> : int, <a href="#fld-aggregate.union">union</a> : bool, <a href="#fld-aggregate.packed">packed</a> : bool, <a href="#fld-aggregate.fields">fields</a> : field list}
  and <a href="#type-field">field</a> = <a href="#con-fieldlayout">FieldLayout</a> of {<a href="#fld-fieldlayout.name">name</a> : string option, <a href="#fld-fieldlayout.offset">offset</a> : IntInf.int, <a href="#fld-fieldlayout.layout">layout</a> : layout, <a href="#fld-fieldlayout.source">source</a> : source}
  exception <a href="#exn-error">Error</a> of source * string
  exception <a href="#exn-shim">Shim</a> of source * string
  val <a href="#val-size">size</a> : layout -&gt; IntInf.int
  val <a href="#val-alignment">alignment</a> : layout -&gt; int
  val <a href="#val-compute">compute</a> : {<a href="#fld-compute.target">target</a> : target, <a href="#fld-compute.source">source</a> : source, <a href="#fld-compute.ty">ty</a> : CParse.ctype,
    <a href="#fld-compute.lookup">lookup</a> : {namespace : string, name : string} -&gt; CParse.ctype option,
    <a href="#fld-compute.constant">constant</a> : CLex.token list -&gt; IntInf.int} -&gt; layout
  val <a href="#val-member">member</a> : layout * string list -&gt; {<a href="#fld-member.offset">offset</a> : IntInf.int, <a href="#fld-member.layout">layout</a> : layout}
end
</pre>

### <a name="type-source"></a>`source`

```sml
type source = CLex.location
```

A physical source position in an original declaration.

### <a name="type-scalar"></a>`scalar`

```sml
type scalar = {size : int, alignment : int, signed : bool option}
```

Size/alignment in bytes; signedness remains explicit where meaningful.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-scalar.size"></a>`size` | `int` |  |
| <a name="fld-scalar.alignment"></a>`alignment` | `int` |  |
| <a name="fld-scalar.signed"></a>`signed` | `bool option` |  |

### <a name="type-target"></a>`target`

```sml
type target = {name : string, pointer : scalar, enumeration : scalar,
  scalars : (string * scalar) list, maximumObject : IntInf.int}
```

Target facts, independent of the generator host's arithmetic width.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-target.name"></a>`name` | `string` |  |
| <a name="fld-target.pointer"></a>`pointer` | `scalar` |  |
| <a name="fld-target.enumeration"></a>`enumeration` | `scalar` |  |
| <a name="fld-target.scalars"></a>`scalars` | `(string * scalar) list` |  |
| <a name="fld-target.maximumobject"></a>`maximumObject` | `IntInf.int` |  |

### <a name="type-layout"></a>`layout`

```sml
datatype layout = Atom of {size : IntInf.int, alignment : int}
  | Sequence of {size : IntInf.int, alignment : int, count : IntInf.int, element : layout}
  | Aggregate of {size : IntInf.int, alignment : int, union : bool, packed : bool, fields : field list}
```

Sized atoms, arrays and aggregates. FieldLayouts retain their own layouts.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-atom"></a>`Atom` | `{size : IntInf.int, alignment : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-atom.size"></a>`size` | `IntInf.int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-atom.alignment"></a>`alignment` | `int` |  |
| <a name="con-sequence"></a>`Sequence` | `{size : IntInf.int, alignment : int, count : IntInf.int, element : layout}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-sequence.size"></a>`size` | `IntInf.int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-sequence.alignment"></a>`alignment` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-sequence.count"></a>`count` | `IntInf.int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-sequence.element"></a>`element` | `layout` |  |
| <a name="con-aggregate"></a>`Aggregate` | `{size : IntInf.int, alignment : int, union : bool, packed : bool, fields : field list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.size"></a>`size` | `IntInf.int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.alignment"></a>`alignment` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.union"></a>`union` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.packed"></a>`packed` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.fields"></a>`fields` | `field list` |  |

### <a name="type-field"></a>`field`

```sml
datatype field = FieldLayout of {name : string option, offset : IntInf.int, layout : layout, source : source}
```

A named or anonymous member's byte offset and original source.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-fieldlayout"></a>`FieldLayout` | `{name : string option, offset : IntInf.int, layout : layout, source : source}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fieldlayout.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fieldlayout.offset"></a>`offset` | `IntInf.int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fieldlayout.layout"></a>`layout` | `layout` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fieldlayout.source"></a>`source` | `source` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of source * string
```

An incomplete, invalid, cyclic or oversized selected layout.

### <a name="exn-shim"></a>`Shim`

```sml
exception Shim of source * string
```

A layout/access operation requiring a verified native adapter.

### <a name="val-size"></a>`size`

```sml
val size : layout -> IntInf.int
```

`size layout` returns its target byte size.

### <a name="val-alignment"></a>`alignment`

```sml
val alignment : layout -> int
```

`alignment layout` returns its target byte alignment.

### <a name="val-compute"></a>`compute`

```sml
val compute : {target : target, source : source, ty : CParse.ctype,
  lookup : {namespace : string, name : string} -> CParse.ctype option,
  constant : CLex.token list -> IntInf.int} -> layout
```

`compute {target, source, ty, lookup, constant}` lays out a C object.

The caller resolves aliases/tags and evaluates typed constant bounds.
Bitfields and unsupported representations require explicit adapters.

**Raises** [`Error`](#exn-error) or [`Shim`](#exn-shim) rather than guessing an ABI layout.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-compute.target"></a>`target` | `target` |  |
| <a name="fld-compute.source"></a>`source` | `source` |  |
| <a name="fld-compute.ty"></a>`ty` | `CParse.ctype` |  |
| <a name="fld-compute.lookup"></a>`lookup` | `{namespace : string, name : string} -> CParse.ctype option` |  |
| <a name="fld-compute.constant"></a>`constant` | `CLex.token list -> IntInf.int` |  |

### <a name="val-member"></a>`member`

```sml
val member : layout * string list -> {offset : IntInf.int, layout : layout}
```

`member (layout, path)` resolves named and anonymous aggregate fields.

**Raises** [`Error`](#exn-error) for missing or ambiguous members.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-member.offset"></a>`offset` | `IntInf.int` |  |
| <a name="fld-member.layout"></a>`layout` | `layout` |  |

---

<sub>Generated by runedoc from lib/language/c/layout\_sig.sml; do not edit.</sub>
