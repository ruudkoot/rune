# signature LSP_METHODS

[Language Server Protocol](../README.md) &rsaquo; Protocols &rsaquo; **LSP_METHODS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/lsp/methods\_sig.sml](../../../../lib/lsp/methods_sig.sml) |

## Synopsis

```sml
signature LSP_METHODS
structure LspMethods :> LSP_METHODS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`LspMethods`](../str/LspMethods.md) | Generated from Microsoft's LSP 3.18.0 metamodel by tools/lsp/protocol-gen.sml. Attribution and CC BY 4.0 license: tools/lsp/protocol/NOTICE.md. | [lib/lsp/methods.sml](../../../../lib/lsp/methods.sml) |

The pinned Language Server Protocol method and property inventory.

## Interface

<pre>
signature LSP_METHODS =
sig
  datatype <a href="#type-direction">direction</a> = <a href="#con-clienttoserver">ClientToServer</a> | <a href="#con-servertoclient">ServerToClient</a> | <a href="#con-both">Both</a>
  datatype <a href="#type-kind">kind</a> = <a href="#con-request">Request</a> | <a href="#con-notification">Notification</a>
  type <a href="#type-method">method</a> = {<a href="#fld-method.name">name</a> : string, <a href="#fld-method.direction">direction</a> : direction, <a href="#fld-method.kind">kind</a> : kind,
                 <a href="#fld-method.clientcapability">clientCapability</a> : string option, <a href="#fld-method.servercapability">serverCapability</a> : string option,
                 <a href="#fld-method.since">since</a> : string option, <a href="#fld-method.proposed">proposed</a> : bool}
  type <a href="#type-property">property</a> = {<a href="#fld-property.owner">owner</a> : string, <a href="#fld-property.name">name</a> : string, <a href="#fld-property.optional">optional</a> : bool,
                   <a href="#fld-property.since">since</a> : string option, <a href="#fld-property.proposed">proposed</a> : bool}
  type <a href="#type-enumvalue">enumValue</a> = {<a href="#fld-enumvalue.owner">owner</a> : string, <a href="#fld-enumvalue.name">name</a> : string, <a href="#fld-enumvalue.value">value</a> : string,
                    <a href="#fld-enumvalue.since">since</a> : string option, <a href="#fld-enumvalue.proposed">proposed</a> : bool}
  val <a href="#val-version">version</a> : string
  val <a href="#val-sourcehash">sourceHash</a> : string
  val <a href="#val-all">all</a> : method list
  val <a href="#val-find">find</a> : string -&gt; method option
  val <a href="#val-properties">properties</a> : property list
  val <a href="#val-enumvalues">enumValues</a> : enumValue list
end
</pre>

### <a name="type-direction"></a>`direction`

```sml
datatype direction = ClientToServer | ServerToClient | Both
```

Which peer sends a protocol message.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-clienttoserver"></a>`ClientToServer` |  |  |
| <a name="con-servertoclient"></a>`ServerToClient` |  |  |
| <a name="con-both"></a>`Both` |  |  |

### <a name="type-kind"></a>`kind`

```sml
datatype kind = Request | Notification
```

A request expects a response; a notification does not.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-request"></a>`Request` |  |  |
| <a name="con-notification"></a>`Notification` |  |  |

### <a name="type-method"></a>`method`

```sml
type method = {name : string, direction : direction, kind : kind,
               clientCapability : string option, serverCapability : string option,
               since : string option, proposed : bool}
```

A method's name, direction, kind and capability/version metadata.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-method.name"></a>`name` | `string` |  |
| <a name="fld-method.direction"></a>`direction` | `direction` |  |
| <a name="fld-method.kind"></a>`kind` | `kind` |  |
| <a name="fld-method.clientcapability"></a>`clientCapability` | `string option` |  |
| <a name="fld-method.servercapability"></a>`serverCapability` | `string option` |  |
| <a name="fld-method.since"></a>`since` | `string option` |  |
| <a name="fld-method.proposed"></a>`proposed` | `bool` |  |

### <a name="type-property"></a>`property`

```sml
type property = {owner : string, name : string, optional : bool,
                 since : string option, proposed : bool}
```

A declared wire property, including properties of anonymous objects.
Its owner names the declaring type or nested type path.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-property.owner"></a>`owner` | `string` |  |
| <a name="fld-property.name"></a>`name` | `string` |  |
| <a name="fld-property.optional"></a>`optional` | `bool` |  |
| <a name="fld-property.since"></a>`since` | `string option` |  |
| <a name="fld-property.proposed"></a>`proposed` | `bool` |  |

### <a name="type-enumvalue"></a>`enumValue`

```sml
type enumValue = {owner : string, name : string, value : string,
                  since : string option, proposed : bool}
```

An enumeration member and its literal value, written as JSON.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-enumvalue.owner"></a>`owner` | `string` |  |
| <a name="fld-enumvalue.name"></a>`name` | `string` |  |
| <a name="fld-enumvalue.value"></a>`value` | `string` |  |
| <a name="fld-enumvalue.since"></a>`since` | `string option` |  |
| <a name="fld-enumvalue.proposed"></a>`proposed` | `bool` |  |

### <a name="val-version"></a>`version`

```sml
val version : string
```

The metamodel's protocol version.

**Example** `version = "3.18.0"`

### <a name="val-sourcehash"></a>`sourceHash`

```sml
val sourceHash : string
```

The SHA-256 of the unmodified upstream metamodel.

### <a name="val-all"></a>`all`

```sml
val all : method list
```

All methods, sorted by their names.

### <a name="val-find"></a>`find`

```sml
val find : string -> method option
```

`find name` is the declared method of that name, when it exists.

**Example** `isSome (find "initialize") andalso not (isSome (find "rune/unknown"))`

### <a name="val-properties"></a>`properties`

```sml
val properties : property list
```

All declared wire properties, including nested anonymous objects.

### <a name="val-enumvalues"></a>`enumValues`

```sml
val enumValues : enumValue list
```

All declared enumeration members.

---

<sub>Generated by runedoc from lib/lsp/methods\_sig.sml; do not edit.</sub>
