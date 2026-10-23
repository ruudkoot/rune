# signature FOREIGN_MODEL

[Foreign binding model](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_MODEL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 23 of 23 entries documented |
| Tests | not listed |
| Source | [lib/ffi/model/model\_sig.sml](../../../../../lib/ffi/model/model_sig.sml) |

## Synopsis

```sml
signature FOREIGN_MODEL
structure ForeignModel : FOREIGN_MODEL
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignModel`](../str/ForeignModel.md) |  | [lib/ffi/model/model.sml](../../../../../lib/ffi/model/model.sml) |

Foreign declarations, independent of target layout and SML projection.

## Interface

<pre>
signature FOREIGN_MODEL =
sig
  type <a href="#type-source">source</a> = {<a href="#fld-source.file">file</a> : string, <a href="#fld-source.line">line</a> : int, <a href="#fld-source.column">column</a> : int}
  type <a href="#type-identity">identity</a> = {<a href="#fld-identity.family">family</a> : string, <a href="#fld-identity.namespace">namespace</a> : string, <a href="#fld-identity.name">name</a> : string}
  type <a href="#type-expression">expression</a> = {<a href="#fld-expression.family">family</a> : string, <a href="#fld-expression.text">text</a> : string, <a href="#fld-expression.source">source</a> : source}
  datatype <a href="#type-foreigntype">foreignType</a> =
      <a href="#con-scalar">Scalar</a> of {<a href="#fld-scalar.family">family</a> : string, <a href="#fld-scalar.name">name</a> : string}
    | <a href="#con-named">Named</a> of identity
    | <a href="#con-pointer">Pointer</a> of {<a href="#fld-pointer.target">target</a> : foreignType, <a href="#fld-pointer.qualifiers">qualifiers</a> : string list}
    | <a href="#con-array">Array</a> of {<a href="#fld-array.element">element</a> : foreignType, <a href="#fld-array.bound">bound</a> : expression option}
    | <a href="#con-callable">Callable</a> of {<a href="#fld-callable.result">result</a> : foreignType, <a href="#fld-callable.parameters">parameters</a> : parameter list,
                   <a href="#fld-callable.variadic">variadic</a> : bool, <a href="#fld-callable.prototype">prototype</a> : bool}
    | <a href="#con-aggregate">Aggregate</a> of {<a href="#fld-aggregate.kind">kind</a> : string, <a href="#fld-aggregate.tag">tag</a> : identity option, <a href="#fld-aggregate.fields">fields</a> : field list option,
                    <a href="#fld-aggregate.packing">packing</a> : int option}
    | <a href="#con-enumeration">Enumeration</a> of {<a href="#fld-enumeration.tag">tag</a> : identity option, <a href="#fld-enumeration.values">values</a> : (string * expression option) list option}
    | <a href="#con-attributed">Attributed</a> of foreignType * expression list
    | <a href="#con-macro">Macro</a> of {<a href="#fld-macro.parameters">parameters</a> : string list option, <a href="#fld-macro.variadic">variadic</a> : bool, <a href="#fld-macro.body">body</a> : expression}
    | <a href="#con-backendtype">BackendType</a> of {<a href="#fld-backendtype.family">family</a> : string, <a href="#fld-backendtype.description">description</a> : string}
  and <a href="#type-parameter">parameter</a> = <a href="#con-parameter">Parameter</a> of {<a href="#fld-parameter.name">name</a> : string option, <a href="#fld-parameter.ty">ty</a> : foreignType}
  and <a href="#type-field">field</a> = <a href="#con-field">Field</a> of {<a href="#fld-field.name">name</a> : string option, <a href="#fld-field.ty">ty</a> : foreignType,
                        <a href="#fld-field.bits">bits</a> : expression option, <a href="#fld-field.source">source</a> : source}
  type <a href="#type-declaration">declaration</a> = {<a href="#fld-declaration.identity">identity</a> : identity, <a href="#fld-declaration.ty">ty</a> : foreignType,
                      <a href="#fld-declaration.storage">storage</a> : string list, <a href="#fld-declaration.source">source</a> : source}
  type <a href="#type-scalarlayout">scalarLayout</a> = {<a href="#fld-scalarlayout.size">size</a> : int, <a href="#fld-scalarlayout.alignment">alignment</a> : int, <a href="#fld-scalarlayout.signed">signed</a> : bool option}
  datatype <a href="#type-byteorder">byteOrder</a> = <a href="#con-little">Little</a> | <a href="#con-big">Big</a>
  type <a href="#type-target">target</a> = {<a href="#fld-target.name">name</a> : string, <a href="#fld-target.abi">abi</a> : string, <a href="#fld-target.byteorder">byteOrder</a> : byteOrder,
                 <a href="#fld-target.scalars">scalars</a> : (string * scalarLayout) list}
  type <a href="#type-layout">layout</a> = {<a href="#fld-layout.size">size</a> : IntInf.int, <a href="#fld-layout.alignment">alignment</a> : int,
                 <a href="#fld-layout.fields">fields</a> : (string * IntInf.int) list}
  type <a href="#type-capabilities">capabilities</a> = {<a href="#fld-capabilities.backend">backend</a> : string, <a href="#fld-capabilities.families">families</a> : string list,
                       <a href="#fld-capabilities.mechanisms">mechanisms</a> : string list, <a href="#fld-capabilities.callbacks">callbacks</a> : string list,
                       <a href="#fld-capabilities.unsupported">unsupported</a> : string list}
  exception <a href="#exn-error">Error</a> of source * string
  val <a href="#val-key">key</a> : identity -&gt; string
  val <a href="#val-fromc">fromC</a> : CParse.declaration list -&gt; declaration list
  val <a href="#val-fromcmacros">fromCMacros</a> : CPreprocess.macro list -&gt; declaration list
  val <a href="#val-canonical">canonical</a> : declaration list -&gt; declaration list
  val <a href="#val-reachable">reachable</a> : declaration list * identity list -&gt; declaration list
  type <a href="#type-environment">environment</a>
  val <a href="#val-index">index</a> : declaration list -&gt; environment
  val <a href="#val-lookup">lookup</a> : environment * identity -&gt; declaration option
  val <a href="#val-find">find</a> : declaration list * identity -&gt; declaration option
  val <a href="#val-libffi">libffi</a> : capabilities
end
</pre>

### <a name="type-source"></a>`source`

```sml
type source = {file : string, line : int, column : int}
```

An original description's physical source position.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-source.file"></a>`file` | `string` |  |
| <a name="fld-source.line"></a>`line` | `int` |  |
| <a name="fld-source.column"></a>`column` | `int` |  |

### <a name="type-identity"></a>`identity`

```sml
type identity = {family : string, namespace : string, name : string}
```

A stable source identity, including the foreign namespace.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-identity.family"></a>`family` | `string` |  |
| <a name="fld-identity.namespace"></a>`namespace` | `string` |  |
| <a name="fld-identity.name"></a>`name` | `string` |  |

### <a name="type-expression"></a>`expression`

```sml
type expression = {family : string, text : string, source : source}
```

An expression in its source language, before target evaluation.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-expression.family"></a>`family` | `string` |  |
| <a name="fld-expression.text"></a>`text` | `string` |  |
| <a name="fld-expression.source"></a>`source` | `source` |  |

### <a name="type-foreigntype"></a>`foreignType`

```sml
datatype foreignType =
    Scalar of {family : string, name : string}
  | Named of identity
  | Pointer of {target : foreignType, qualifiers : string list}
  | Array of {element : foreignType, bound : expression option}
  | Callable of {result : foreignType, parameters : parameter list,
                 variadic : bool, prototype : bool}
  | Aggregate of {kind : string, tag : identity option, fields : field list option,
                  packing : int option}
  | Enumeration of {tag : identity option, values : (string * expression option) list option}
  | Attributed of foreignType * expression list
  | Macro of {parameters : string list option, variadic : bool, body : expression}
  | BackendType of {family : string, description : string}
```

Foreign types. Backend-specific types stay explicit and cannot silently
become machine pointers or libffi scalars.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-scalar"></a>`Scalar` | `{family : string, name : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-scalar.family"></a>`family` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-scalar.name"></a>`name` | `string` |  |
| <a name="con-named"></a>`Named` | `identity` |  |
| <a name="con-pointer"></a>`Pointer` | `{target : foreignType, qualifiers : string list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-pointer.target"></a>`target` | `foreignType` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-pointer.qualifiers"></a>`qualifiers` | `string list` |  |
| <a name="con-array"></a>`Array` | `{element : foreignType, bound : expression option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-array.element"></a>`element` | `foreignType` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-array.bound"></a>`bound` | `expression option` |  |
| <a name="con-callable"></a>`Callable` | `{result : foreignType, parameters : parameter list, variadic : bool, prototype : bool}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-callable.result"></a>`result` | `foreignType` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-callable.parameters"></a>`parameters` | `parameter list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-callable.variadic"></a>`variadic` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-callable.prototype"></a>`prototype` | `bool` |  |
| <a name="con-aggregate"></a>`Aggregate` | `{kind : string, tag : identity option, fields : field list option, packing : int option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.kind"></a>`kind` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.tag"></a>`tag` | `identity option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.fields"></a>`fields` | `field list option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-aggregate.packing"></a>`packing` | `int option` |  |
| <a name="con-enumeration"></a>`Enumeration` | `{tag : identity option, values : (string * expression option) list option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-enumeration.tag"></a>`tag` | `identity option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-enumeration.values"></a>`values` | `(string * expression option) list option` |  |
| <a name="con-attributed"></a>`Attributed` | `foreignType * expression list` |  |
| <a name="con-macro"></a>`Macro` | `{parameters : string list option, variadic : bool, body : expression}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-macro.parameters"></a>`parameters` | `string list option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-macro.variadic"></a>`variadic` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-macro.body"></a>`body` | `expression` |  |
| <a name="con-backendtype"></a>`BackendType` | `{family : string, description : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-backendtype.family"></a>`family` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-backendtype.description"></a>`description` | `string` |  |

### <a name="type-parameter"></a>`parameter`

```sml
datatype parameter = Parameter of {name : string option, ty : foreignType}
```

A foreign parameter before naming, ownership or output projection.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-parameter"></a>`Parameter` | `{name : string option, ty : foreignType}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-parameter.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-parameter.ty"></a>`ty` | `foreignType` |  |

### <a name="type-field"></a>`field`

```sml
datatype field = Field of {name : string option, ty : foreignType,
                      bits : expression option, source : source}
```

A foreign aggregate member; bit widths remain source expressions.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-field"></a>`Field` | `{name : string option, ty : foreignType, bits : expression option, source : source}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.name"></a>`name` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.ty"></a>`ty` | `foreignType` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.bits"></a>`bits` | `expression option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-field.source"></a>`source` | `source` |  |

### <a name="type-declaration"></a>`declaration`

```sml
type declaration = {identity : identity, ty : foreignType,
                    storage : string list, source : source}
```

A declaration with source identity and linkage, separate from policy.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-declaration.identity"></a>`identity` | `identity` |  |
| <a name="fld-declaration.ty"></a>`ty` | `foreignType` |  |
| <a name="fld-declaration.storage"></a>`storage` | `string list` |  |
| <a name="fld-declaration.source"></a>`source` | `source` |  |

### <a name="type-scalarlayout"></a>`scalarLayout`

```sml
type scalarLayout = {size : int, alignment : int, signed : bool option}
```

Target scalar facts, separate from SML host arithmetic.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-scalarlayout.size"></a>`size` | `int` |  |
| <a name="fld-scalarlayout.alignment"></a>`alignment` | `int` |  |
| <a name="fld-scalarlayout.signed"></a>`signed` | `bool option` |  |

### <a name="type-byteorder"></a>`byteOrder`

```sml
datatype byteOrder = Little | Big
```

Target byte order.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-little"></a>`Little` |  |  |
| <a name="con-big"></a>`Big` |  |  |

### <a name="type-target"></a>`target`

```sml
type target = {name : string, abi : string, byteOrder : byteOrder,
               scalars : (string * scalarLayout) list}
```

Target facts do not add ownership or projection to declarations.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-target.name"></a>`name` | `string` |  |
| <a name="fld-target.abi"></a>`abi` | `string` |  |
| <a name="fld-target.byteorder"></a>`byteOrder` | `byteOrder` |  |
| <a name="fld-target.scalars"></a>`scalars` | `(string * scalarLayout) list` |  |

### <a name="type-layout"></a>`layout`

```sml
type layout = {size : IntInf.int, alignment : int,
               fields : (string * IntInf.int) list}
```

A checked native layout produced by the layout consumer.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-layout.size"></a>`size` | `IntInf.int` |  |
| <a name="fld-layout.alignment"></a>`alignment` | `int` |  |
| <a name="fld-layout.fields"></a>`fields` | `(string * IntInf.int) list` |  |

### <a name="type-capabilities"></a>`capabilities`

```sml
type capabilities = {backend : string, families : string list,
                     mechanisms : string list, callbacks : string list,
                     unsupported : string list}
```

Backends state which source families and mechanisms they implement.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-capabilities.backend"></a>`backend` | `string` |  |
| <a name="fld-capabilities.families"></a>`families` | `string list` |  |
| <a name="fld-capabilities.mechanisms"></a>`mechanisms` | `string list` |  |
| <a name="fld-capabilities.callbacks"></a>`callbacks` | `string list` |  |
| <a name="fld-capabilities.unsupported"></a>`unsupported` | `string list` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of source * string
```

A source-located model diagnostic.

### <a name="val-key"></a>`key`

```sml
val key : identity -> string
```

`key identity` encodes a source identity without delimiter collisions.

### <a name="val-fromc"></a>`fromC`

```sml
val fromC : CParse.declaration list -> declaration list
```

`fromC declarations` adapts parsed C declarations without applying
ownership, target widths or SML naming policy.

Unresolved redeclarations remain available for a selected consumer's
diagnostic; private declarations do not block unrelated selections.

### <a name="val-fromcmacros"></a>`fromCMacros`

```sml
val fromCMacros : CPreprocess.macro list -> declaration list
```

`fromCMacros macros` preserves macro source, parameters and body.
Macro identities occupy their own namespace; they are not functions.

### <a name="val-canonical"></a>`canonical`

```sml
val canonical : declaration list -> declaration list
```

`canonical declarations` sorts identities and physical source positions.
Input traversal order cannot affect reports or selected closures.

### <a name="val-reachable"></a>`reachable`

```sml
val reachable : declaration list * identity list -> declaration list
```

`reachable (declarations, selected)` resolves the transitive declaration
closure, including aliases, while retaining opaque aggregate pointers.

**Raises** [`Error`](#exn-error) for missing or ambiguous selected identities.

### <a name="type-environment"></a>`environment`

```sml
type environment
```

An immutable lookup index over one declaration collection.

### <a name="val-index"></a>`index`

```sml
val index : declaration list -> environment
```

`index declarations` prepares repeated identity lookups without
changing declaration/source information.

### <a name="val-lookup"></a>`lookup`

```sml
val lookup : environment * identity -> declaration option
```

`lookup (environment, identity)` resolves one indexed identity.

**Raises** [`Error`](#exn-error) for an ambiguous identity.

### <a name="val-find"></a>`find`

```sml
val find : declaration list * identity -> declaration option
```

`find (declarations, identity)` resolves an exact foreign identity.

**Raises** [`Error`](#exn-error) when that identity has incompatible redeclarations.

### <a name="val-libffi"></a>`libffi`

```sml
val libffi : capabilities
```

[`libffi`](#val-libffi) describes the dynamic C backend contract. Runtime availability
is checked separately; other families need explicit future backends.

---

<sub>Generated by runedoc from lib/ffi/model/model\_sig.sml; do not edit.</sub>
