# signature C_ANALYSIS

[C declaration frontend](../README.md) &rsaquo; Languages &rsaquo; **C_ANALYSIS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/language/c/analysis\_sig.sml](../../../../../lib/language/c/analysis_sig.sml) |

## Synopsis

```sml
signature C_ANALYSIS
structure CAnalysis :> C_ANALYSIS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CAnalysis`](../str/CAnalysis.md) |  | [lib/language/c/analysis.sml](../../../../../lib/language/c/analysis.sml) |

Typed declaration analysis over explicit target C facts.

## Interface

<pre>
signature C_ANALYSIS =
sig
  datatype <a href="#type-enumrule">enumRule</a> = <a href="#con-signedenums">SignedEnums</a> | <a href="#con-unsignednonnegative">UnsignedNonnegative</a>
  type <a href="#type-target">target</a> = {<a href="#fld-target.integers">integers</a> : CInteger.target, <a href="#fld-target.objects">objects</a> : CLayout.target,
    <a href="#fld-target.charsigned">charSigned</a> : bool, <a href="#fld-target.sizetype">sizeType</a> : CInteger.integerType, <a href="#fld-target.enumrule">enumRule</a> : enumRule}
  type <a href="#type-environment">environment</a>
  exception <a href="#exn-error">Error</a> of CLex.location * string
  val <a href="#val-create">create</a> : {<a href="#fld-create.target">target</a> : target, <a href="#fld-create.declarations">declarations</a> : CParse.declaration list} -&gt; environment
  val <a href="#val-lookup">lookup</a> : environment -&gt; {<a href="#fld-lookup.namespace">namespace</a> : string, <a href="#fld-lookup.name">name</a> : string} -&gt; CParse.ctype option
  val <a href="#val-resolve">resolve</a> : environment -&gt; CParse.ctype -&gt; CParse.ctype
  val <a href="#val-integer">integer</a> : environment -&gt; CParse.ctype -&gt; CInteger.integerType option
  val <a href="#val-expression">expression</a> : environment -&gt; CLex.token list -&gt; CInteger.value
  val <a href="#val-enumerator">enumerator</a> : environment -&gt; string -&gt; CInteger.value
  val <a href="#val-layout">layout</a> : environment -&gt; {<a href="#fld-layout.ty">ty</a> : CParse.ctype, <a href="#fld-layout.source">source</a> : CLex.location} -&gt; CLayout.layout
end
</pre>

### <a name="type-enumrule"></a>`enumRule`

```sml
datatype enumRule = SignedEnums | UnsignedNonnegative
```

Compiler enum policy for the supported full-int ABI profiles.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-signedenums"></a>`SignedEnums` |  |  |
| <a name="con-unsignednonnegative"></a>`UnsignedNonnegative` |  |  |

### <a name="type-target"></a>`target`

```sml
type target = {integers : CInteger.target, objects : CLayout.target,
  charSigned : bool, sizeType : CInteger.integerType, enumRule : enumRule}
```

All integer, object-layout and size-type facts for one target.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-target.integers"></a>`integers` | `CInteger.target` |  |
| <a name="fld-target.objects"></a>`objects` | `CLayout.target` |  |
| <a name="fld-target.charsigned"></a>`charSigned` | `bool` |  |
| <a name="fld-target.sizetype"></a>`sizeType` | `CInteger.integerType` |  |
| <a name="fld-target.enumrule"></a>`enumRule` | `enumRule` |  |

### <a name="type-environment"></a>`environment`

```sml
type environment
```

Indexed original declarations and lazily evaluated constants.

### <a name="exn-error"></a>`Error`

```sml
exception Error of CLex.location * string
```

An ambiguous, missing, cyclic or unsupported selected declaration.

### <a name="val-create"></a>`create`

```sml
val create : {target : target, declarations : CParse.declaration list} -> environment
```

`create {target, declarations}` indexes a translation unit.

Private unresolved declarations do not force evaluation. Duplicate
incompatible definitions are diagnosed only when selected.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-create.target"></a>`target` | `target` |  |
| <a name="fld-create.declarations"></a>`declarations` | `CParse.declaration list` |  |

### <a name="val-lookup"></a>`lookup`

```sml
val lookup : environment -> {namespace : string, name : string} -> CParse.ctype option
```

`lookup environment {namespace, name}` resolves an alias or tag.

Namespaces are typedef, struct, union and enum. Definitions take
precedence over incomplete declarations; ambiguous definitions fail.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-lookup.namespace"></a>`namespace` | `string` |  |
| <a name="fld-lookup.name"></a>`name` | `string` |  |

### <a name="val-resolve"></a>`resolve`

```sml
val resolve : environment -> CParse.ctype -> CParse.ctype
```

`resolve environment ty` removes outer aliases and qualifiers.

Pointer targets and aggregate fields remain separate type references.

### <a name="val-integer"></a>`integer`

```sml
val integer : environment -> CParse.ctype -> CInteger.integerType option
```

`integer environment ty` classifies a resolved standard integer type.

Extended enum representations require an explicit native adapter.

### <a name="val-expression"></a>`expression`

```sml
val expression : environment -> CLex.token list -> CInteger.value
```

`expression environment tokens` evaluates a typed integer expression.

Typedef casts, enumerators, object types and measurements use this
target's declarations, never the SML host's C widths.

### <a name="val-enumerator"></a>`enumerator`

```sml
val enumerator : environment -> string -> CInteger.value
```

`enumerator environment name` evaluates a declaration-order enum value.

Forward references and values outside the standard int range fail.

### <a name="val-layout"></a>`layout`

```sml
val layout : environment -> {ty : CParse.ctype, source : CLex.location} -> CLayout.layout
```

`layout environment {ty, source}` computes a selected object's layout.

**Raises** [`Error`](#exn-error), or [`CLayout.Shim`](../sig/C_LAYOUT.md#exn-shim) for a representation needing an adapter.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-layout.ty"></a>`ty` | `CParse.ctype` |  |
| <a name="fld-layout.source"></a>`source` | `CLex.location` |  |

---

<sub>Generated by runedoc from lib/language/c/analysis\_sig.sml; do not edit.</sub>
