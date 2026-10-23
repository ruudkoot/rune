# signature FOREIGN_POLICY

[Foreign binding model](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_POLICY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 15 of 15 entries documented |
| Tests | not listed |
| Source | [lib/ffi/model/policy\_sig.sml](../../../../../lib/ffi/model/policy_sig.sml) |

## Synopsis

```sml
signature FOREIGN_POLICY
structure ForeignPolicy : FOREIGN_POLICY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignPolicy`](../str/ForeignPolicy.md) |  | [lib/ffi/model/policy.sml](../../../../../lib/ffi/model/policy.sml) |

Declarative FFI policy; reading a sidecar never executes its adapters.

## Interface

<pre>
signature FOREIGN_POLICY =
sig
  datatype <a href="#type-encoding">encoding</a> = <a href="#con-bytes">Bytes</a> | <a href="#con-utf8">Utf8</a> | <a href="#con-wtf8">Wtf8</a> | <a href="#con-utf16">Utf16</a>
  datatype <a href="#type-direction">direction</a> = <a href="#con-in">In</a> | <a href="#con-out">Out</a> | <a href="#con-inout">InOut</a>
  datatype <a href="#type-ownership">ownership</a> = <a href="#con-borrowed">Borrowed</a> of string | <a href="#con-owned">Owned</a> of string
  datatype <a href="#type-extent">extent</a> = <a href="#con-parameterlength">ParameterLength</a> of string | <a href="#con-fixedlength">FixedLength</a> of IntInf.int
  datatype <a href="#type-smltype">smlType</a> = <a href="#con-scalar">Scalar</a> of string | <a href="#con-resource">Resource</a> of string | <a href="#con-option">Option</a> of smlType
    | <a href="#con-vector">Vector</a> of smlType | <a href="#con-array">Array</a> of smlType | <a href="#con-tuple">Tuple</a> of smlType list
    | <a href="#con-record">Record</a> of (string * smlType) list
  datatype <a href="#type-tree">tree</a> = <a href="#con-unit">Unit</a> | <a href="#con-value">Value</a> of string | <a href="#con-product">Product</a> of tree list | <a href="#con-fields">Fields</a> of (string * tree) list
  type <a href="#type-valuepolicy">valuePolicy</a> = {<a href="#fld-valuepolicy.name">name</a> : string option, <a href="#fld-valuepolicy.direction">direction</a> : direction option,
    <a href="#fld-valuepolicy.ownership">ownership</a> : ownership option, <a href="#fld-valuepolicy.nullable">nullable</a> : bool option, <a href="#fld-valuepolicy.encoding">encoding</a> : encoding option, <a href="#fld-valuepolicy.terminator">terminator</a> : bool option,
    <a href="#fld-valuepolicy.extent">extent</a> : extent option, <a href="#fld-valuepolicy.callback">callback</a> : string option, <a href="#fld-valuepolicy.projection">projection</a> : smlType option,
    <a href="#fld-valuepolicy.output">output</a> : string option, <a href="#fld-valuepolicy.consumes">consumes</a> : bool, <a href="#fld-valuepolicy.source">source</a> : ForeignModel.source}
  type <a href="#type-errorpolicy">errorPolicy</a> = {<a href="#fld-errorpolicy.predicate">predicate</a> : string, <a href="#fld-errorpolicy.capture">capture</a> : string, <a href="#fld-errorpolicy.getter">getter</a> : string option}
  type <a href="#type-functionpolicy">functionPolicy</a> = {<a href="#fld-functionpolicy.foreign">foreign</a> : string, <a href="#fld-functionpolicy.namespace">namespace</a> : string, <a href="#fld-functionpolicy.name">name</a> : string, <a href="#fld-functionpolicy.raw">raw</a> : string option,
    <a href="#fld-functionpolicy.parameters">parameters</a> : valuePolicy list, <a href="#fld-functionpolicy.result">result</a> : valuePolicy, <a href="#fld-functionpolicy.errors">errors</a> : errorPolicy,
    <a href="#fld-functionpolicy.variadic">variadic</a> : string, <a href="#fld-functionpolicy.unsaferaw">unsafeRaw</a> : bool, <a href="#fld-functionpolicy.adapter">adapter</a> : string option, <a href="#fld-functionpolicy.shim">shim</a> : string option,
    <a href="#fld-functionpolicy.input">input</a> : tree option, <a href="#fld-functionpolicy.returns">returns</a> : tree option,
    <a href="#fld-functionpolicy.source">source</a> : ForeignModel.source}
  datatype <a href="#type-failure">failure</a> = <a href="#con-constantfailure">ConstantFailure</a> of IntInf.int
    | <a href="#con-argumentfailure">ArgumentFailure</a> of {<a href="#fld-argumentfailure.parameter">parameter</a> : string, <a href="#fld-argumentfailure.cases">cases</a> : (string * IntInf.int) list,
                          <a href="#fld-argumentfailure.otherwise">otherwise</a> : IntInf.int}
  type <a href="#type-callbackpolicy">callbackPolicy</a> = {<a href="#fld-callbackpolicy.foreign">foreign</a> : string, <a href="#fld-callbackpolicy.lifetime">lifetime</a> : string, <a href="#fld-callbackpolicy.owner">owner</a> : string option,
    <a href="#fld-callbackpolicy.thread">thread</a> : string, <a href="#fld-callbackpolicy.failure">failure</a> : failure, <a href="#fld-callbackpolicy.source">source</a> : ForeignModel.source}
  type <a href="#type-policy">policy</a> = {<a href="#fld-policy.version">version</a> : int, <a href="#fld-policy.family">family</a> : string, <a href="#fld-policy.structurename">structureName</a> : string,
    <a href="#fld-policy.headers">headers</a> : string list, <a href="#fld-policy.libraries">libraries</a> : string list, <a href="#fld-policy.resources">resources</a> : string list, <a href="#fld-policy.functions">functions</a> : functionPolicy list,
    <a href="#fld-policy.callbacks">callbacks</a> : callbackPolicy list, <a href="#fld-policy.source">source</a> : ForeignModel.source}
  exception <a href="#exn-error">Error</a> of ForeignModel.source * string
  val <a href="#val-decode">decode</a> : {<a href="#fld-decode.file">file</a> : string, <a href="#fld-decode.text">text</a> : string} -&gt; policy
  val <a href="#val-rawname">rawName</a> : string -&gt; string
end
</pre>

### <a name="type-encoding"></a>`encoding`

```sml
datatype encoding = Bytes | Utf8 | Wtf8 | Utf16
```

Supported text encodings; raw buffers use bytes explicitly.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-bytes"></a>`Bytes` |  |  |
| <a name="con-utf8"></a>`Utf8` |  |  |
| <a name="con-wtf8"></a>`Wtf8` |  |  |
| <a name="con-utf16"></a>`Utf16` |  |  |

### <a name="type-direction"></a>`direction`

```sml
datatype direction = In | Out | InOut
```

Parameter movement and copy-back direction.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-in"></a>`In` |  |  |
| <a name="con-out"></a>`Out` |  |  |
| <a name="con-inout"></a>`InOut` |  |  |

### <a name="type-ownership"></a>`ownership`

```sml
datatype ownership = Borrowed of string | Owned of string
```

Ownership is separate from C pointer syntax.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-borrowed"></a>`Borrowed` | `string` |  |
| <a name="con-owned"></a>`Owned` | `string` |  |

### <a name="type-extent"></a>`extent`

```sml
datatype extent = ParameterLength of string | FixedLength of IntInf.int
```

Buffer extents name a parameter or a fixed element count.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-parameterlength"></a>`ParameterLength` | `string` |  |
| <a name="con-fixedlength"></a>`FixedLength` | `IntInf.int` |  |

### <a name="type-smltype"></a>`smlType`

```sml
datatype smlType = Scalar of string | Resource of string | Option of smlType
  | Vector of smlType | Array of smlType | Tuple of smlType list
  | Record of (string * smlType) list
```

A structured SML type, never an executable SML source fragment.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-scalar"></a>`Scalar` | `string` |  |
| <a name="con-resource"></a>`Resource` | `string` |  |
| <a name="con-option"></a>`Option` | `smlType` |  |
| <a name="con-vector"></a>`Vector` | `smlType` |  |
| <a name="con-array"></a>`Array` | `smlType` |  |
| <a name="con-tuple"></a>`Tuple` | `smlType list` |  |
| <a name="con-record"></a>`Record` | `(string * smlType) list` |  |

### <a name="type-tree"></a>`tree`

```sml
datatype tree = Unit | Value of string | Product of tree list | Fields of (string * tree) list
```

Structured input/output grouping; leaves refer to foreign parameters
or `$result`. It contains no SML expressions.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-unit"></a>`Unit` |  |  |
| <a name="con-value"></a>`Value` | `string` |  |
| <a name="con-product"></a>`Product` | `tree list` |  |
| <a name="con-fields"></a>`Fields` | `(string * tree) list` |  |

### <a name="type-valuepolicy"></a>`valuePolicy`

```sml
type valuePolicy = {name : string option, direction : direction option,
  ownership : ownership option, nullable : bool option, encoding : encoding option, terminator : bool option,
  extent : extent option, callback : string option, projection : smlType option,
  output : string option, consumes : bool, source : ForeignModel.source}
```

A parameter or returned-value annotation. Absence stays explicit until
declaration-aware validation; the decoder guesses no ownership.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-valuepolicy.name"></a>`name` | `string option` |  |
| <a name="fld-valuepolicy.direction"></a>`direction` | `direction option` |  |
| <a name="fld-valuepolicy.ownership"></a>`ownership` | `ownership option` |  |
| <a name="fld-valuepolicy.nullable"></a>`nullable` | `bool option` |  |
| <a name="fld-valuepolicy.encoding"></a>`encoding` | `encoding option` |  |
| <a name="fld-valuepolicy.terminator"></a>`terminator` | `bool option` |  |
| <a name="fld-valuepolicy.extent"></a>`extent` | `extent option` |  |
| <a name="fld-valuepolicy.callback"></a>`callback` | `string option` |  |
| <a name="fld-valuepolicy.projection"></a>`projection` | `smlType option` |  |
| <a name="fld-valuepolicy.output"></a>`output` | `string option` |  |
| <a name="fld-valuepolicy.consumes"></a>`consumes` | `bool` |  |
| <a name="fld-valuepolicy.source"></a>`source` | `ForeignModel.source` |  |

### <a name="type-errorpolicy"></a>`errorPolicy`

```sml
type errorPolicy = {predicate : string, capture : string, getter : string option}
```

Native error predicates and capture mechanisms are independent.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-errorpolicy.predicate"></a>`predicate` | `string` |  |
| <a name="fld-errorpolicy.capture"></a>`capture` | `string` |  |
| <a name="fld-errorpolicy.getter"></a>`getter` | `string option` |  |

### <a name="type-functionpolicy"></a>`functionPolicy`

```sml
type functionPolicy = {foreign : string, namespace : string, name : string, raw : string option,
  parameters : valuePolicy list, result : valuePolicy, errors : errorPolicy,
  variadic : string, unsafeRaw : bool, adapter : string option, shim : string option,
  input : tree option, returns : tree option,
  source : ForeignModel.source}
```

A selected function and its naming/marshalling policy.

An optional shim is one fixed C prototype, parsed as declaration data;
it supplies a macro ABI or an explicit variadic tail.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-functionpolicy.foreign"></a>`foreign` | `string` |  |
| <a name="fld-functionpolicy.namespace"></a>`namespace` | `string` |  |
| <a name="fld-functionpolicy.name"></a>`name` | `string` |  |
| <a name="fld-functionpolicy.raw"></a>`raw` | `string option` |  |
| <a name="fld-functionpolicy.parameters"></a>`parameters` | `valuePolicy list` |  |
| <a name="fld-functionpolicy.result"></a>`result` | `valuePolicy` |  |
| <a name="fld-functionpolicy.errors"></a>`errors` | `errorPolicy` |  |
| <a name="fld-functionpolicy.variadic"></a>`variadic` | `string` |  |
| <a name="fld-functionpolicy.unsaferaw"></a>`unsafeRaw` | `bool` |  |
| <a name="fld-functionpolicy.adapter"></a>`adapter` | `string option` |  |
| <a name="fld-functionpolicy.shim"></a>`shim` | `string option` |  |
| <a name="fld-functionpolicy.input"></a>`input` | `tree option` |  |
| <a name="fld-functionpolicy.returns"></a>`returns` | `tree option` |  |
| <a name="fld-functionpolicy.source"></a>`source` | `ForeignModel.source` |  |

### <a name="type-failure"></a>`failure`

```sml
datatype failure = ConstantFailure of IntInf.int
  | ArgumentFailure of {parameter : string, cases : (string * IntInf.int) list,
                        otherwise : IntInf.int}
```

A constant callback failure result, or a table keyed by one native
argument, such as a Win32 message identifier.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-constantfailure"></a>`ConstantFailure` | `IntInf.int` |  |
| <a name="con-argumentfailure"></a>`ArgumentFailure` | `{parameter : string, cases : (string * IntInf.int) list, otherwise : IntInf.int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-argumentfailure.parameter"></a>`parameter` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-argumentfailure.cases"></a>`cases` | `(string * IntInf.int) list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-argumentfailure.otherwise"></a>`otherwise` | `IntInf.int` |  |

### <a name="type-callbackpolicy"></a>`callbackPolicy`

```sml
type callbackPolicy = {foreign : string, lifetime : string, owner : string option,
  thread : string, failure : failure, source : ForeignModel.source}
```

Callback lifetime, thread and failure rules must be declared.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-callbackpolicy.foreign"></a>`foreign` | `string` |  |
| <a name="fld-callbackpolicy.lifetime"></a>`lifetime` | `string` |  |
| <a name="fld-callbackpolicy.owner"></a>`owner` | `string option` |  |
| <a name="fld-callbackpolicy.thread"></a>`thread` | `string` |  |
| <a name="fld-callbackpolicy.failure"></a>`failure` | `failure` |  |
| <a name="fld-callbackpolicy.source"></a>`source` | `ForeignModel.source` |  |

### <a name="type-policy"></a>`policy`

```sml
type policy = {version : int, family : string, structureName : string,
  headers : string list, libraries : string list, resources : string list, functions : functionPolicy list,
  callbacks : callbackPolicy list, source : ForeignModel.source}
```

Sidecar contents; paths and library names are data.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-policy.version"></a>`version` | `int` |  |
| <a name="fld-policy.family"></a>`family` | `string` |  |
| <a name="fld-policy.structurename"></a>`structureName` | `string` |  |
| <a name="fld-policy.headers"></a>`headers` | `string list` |  |
| <a name="fld-policy.libraries"></a>`libraries` | `string list` |  |
| <a name="fld-policy.resources"></a>`resources` | `string list` |  |
| <a name="fld-policy.functions"></a>`functions` | `functionPolicy list` |  |
| <a name="fld-policy.callbacks"></a>`callbacks` | `callbackPolicy list` |  |
| <a name="fld-policy.source"></a>`source` | `ForeignModel.source` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of ForeignModel.source * string
```

A source-located sidecar diagnostic.

### <a name="val-decode"></a>`decode`

```sml
val decode : {file : string, text : string} -> policy
```

`decode {file, text}` reads version one JSON policy, checking field
names, duplicates, names, enums and structured projection types.

**Raises** [`Error`](#exn-error) for malformed or unsupported policy.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-decode.file"></a>`file` | `string` |  |
| <a name="fld-decode.text"></a>`text` | `string` |  |

### <a name="val-rawname"></a>`rawName`

```sml
val rawName : string -> string
```

`rawName name` escapes foreign identifiers into legal SML value names.
A projection consumer must check collisions across its complete API.

---

<sub>Generated by runedoc from lib/ffi/model/policy\_sig.sml; do not edit.</sub>
