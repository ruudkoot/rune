# signature LSP_PROTOCOL

[Language Server Protocol](../README.md) &rsaquo; Protocols &rsaquo; **LSP_PROTOCOL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 29 of 29 entries documented |
| Tests | not listed |
| Source | [lib/lsp/protocol\_sig.sml](../../../../lib/lsp/protocol_sig.sml) |

## Synopsis

```sml
signature LSP_PROTOCOL
structure LspProtocol :> LSP_PROTOCOL
```

| Implementation |  | Source |
| --- | --- | --- |
| [`LspProtocol`](../str/LspProtocol.md) | LSP's envelope and common wire values over the JSON-RPC library. | [lib/lsp/protocol.sml](../../../../lib/lsp/protocol.sml) |

LSP 3.18 wire values, integer bounds and capability negotiation.

## Interface

<pre>
signature LSP_PROTOCOL =
sig
  type <a href="#type-integer">integer</a> = IntInf.int
  type <a href="#type-position">position</a> = {<a href="#fld-position.line">line</a> : integer, <a href="#fld-position.character">character</a> : integer}
  type <a href="#type-range">range</a> = {<a href="#fld-range.start">start</a> : position, <a href="#fld-range.stop">stop</a> : position}
  datatype <a href="#type-encoding">encoding</a> = <a href="#con-utf8">Utf8</a> | <a href="#con-utf16">Utf16</a> | <a href="#con-utf32">Utf32</a>
  type <a href="#type-capabilities">capabilities</a>
  datatype <a href="#type-decoded">decoded</a> = <a href="#con-message">Message</a> of JsonRpc.message
                   | <a href="#con-invalid">Invalid</a> of {<a href="#fld-invalid.error">error</a> : JsonRpc.error, <a href="#fld-invalid.id">id</a> : JsonRpc.id option, <a href="#fld-invalid.reply">reply</a> : bool}
  val <a href="#val-version">version</a> : string
  val <a href="#val-mininteger">minInteger</a> : integer
  val <a href="#val-maxinteger">maxInteger</a> : integer
  val <a href="#val-integer">integer</a> : Json.value -&gt; integer option
  val <a href="#val-uinteger">uinteger</a> : Json.value -&gt; integer option
  val <a href="#val-integertojson">integerToJson</a> : integer -&gt; Json.value
  val <a href="#val-idfromjson">idFromJson</a> : Json.value -&gt; JsonRpc.id option
  val <a href="#val-idtojson">idToJson</a> : JsonRpc.id -&gt; Json.value
  val <a href="#val-positionfromjson">positionFromJson</a> : Json.value -&gt; position option
  val <a href="#val-positiontojson">positionToJson</a> : position -&gt; Json.value
  val <a href="#val-rangefromjson">rangeFromJson</a> : Json.value -&gt; range option
  val <a href="#val-rangetojson">rangeToJson</a> : range -&gt; Json.value
  val <a href="#val-decode">decode</a> : string -&gt; decoded
  val <a href="#val-encode">encode</a> : JsonRpc.message -&gt; string
  val <a href="#val-capabilities">capabilities</a> : Json.value -&gt; capabilities option
  val <a href="#val-supports">supports</a> : capabilities * string list -&gt; bool
  val <a href="#val-positionencoding">positionEncoding</a> : capabilities -&gt; encoding
  val <a href="#val-encodingname">encodingName</a> : encoding -&gt; string
  val <a href="#val-rawcapabilities">rawCapabilities</a> : capabilities -&gt; Json.value
  val <a href="#val-servernotinitialized">serverNotInitialized</a> : integer
  val <a href="#val-contentmodified">contentModified</a> : integer
  val <a href="#val-servercancelled">serverCancelled</a> : integer
  val <a href="#val-requestfailed">requestFailed</a> : integer
end
</pre>

### <a name="type-integer"></a>`integer`

```sml
type integer = IntInf.int
```

An LSP integer, represented without dependence on the host's width.

### <a name="type-position"></a>`position`

```sml
type position = {line : integer, character : integer}
```

Zero-based line and character coordinates in the negotiated encoding.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-position.line"></a>`line` | `integer` |  |
| <a name="fld-position.character"></a>`character` | `integer` |  |

### <a name="type-range"></a>`range`

```sml
type range = {start : position, stop : position}
```

A half-open range, whose end is not before its start.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-range.start"></a>`start` | `position` |  |
| <a name="fld-range.stop"></a>`stop` | `position` |  |

### <a name="type-encoding"></a>`encoding`

```sml
datatype encoding = Utf8 | Utf16 | Utf32
```

The position encodings supported by the protocol adapter.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-utf8"></a>`Utf8` |  |  |
| <a name="con-utf16"></a>`Utf16` |  |  |
| <a name="con-utf32"></a>`Utf32` |  |  |

### <a name="type-capabilities"></a>`capabilities`

```sml
type capabilities
```

Validated capabilities and their selected position encoding.

### <a name="type-decoded"></a>`decoded`

```sml
datatype decoded = Message of JsonRpc.message
                 | Invalid of {error : JsonRpc.error, id : JsonRpc.id option, reply : bool}
```

A decoded message, or an error with its recoverable id.

Malformed responses and recognizable notifications have reply false,
preventing response loops and replies to notifications.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-message"></a>`Message` | `JsonRpc.message` |  |
| <a name="con-invalid"></a>`Invalid` | `{error : JsonRpc.error, id : JsonRpc.id option, reply : bool}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-invalid.error"></a>`error` | `JsonRpc.error` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-invalid.id"></a>`id` | `JsonRpc.id option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-invalid.reply"></a>`reply` | `bool` |  |

### <a name="val-version"></a>`version`

```sml
val version : string
```

The supported protocol version.

**Example** `version = "3.18.0"`

### <a name="val-mininteger"></a>`minInteger`

```sml
val minInteger : integer
```

The smallest signed LSP integer.

### <a name="val-maxinteger"></a>`maxInteger`

```sml
val maxInteger : integer
```

The largest signed or unsigned LSP integer.

### <a name="val-integer"></a>`integer`

```sml
val integer : Json.value -> integer option
```

`integer v` is the signed 32-bit integer represented by v.

### <a name="val-uinteger"></a>`uinteger`

```sml
val uinteger : Json.value -> integer option
```

`uinteger v` is the nonnegative LSP integer represented by v.

**Example** `uinteger (Json.int ~1) = NONE`

### <a name="val-integertojson"></a>`integerToJson`

```sml
val integerToJson : integer -> Json.value
```

`integerToJson n` is n as a signed LSP JSON integer.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) when n is outside the signed 32-bit range.

### <a name="val-idfromjson"></a>`idFromJson`

```sml
val idFromJson : Json.value -> JsonRpc.id option
```

`idFromJson v` reads a string id or signed LSP integer id.

### <a name="val-idtojson"></a>`idToJson`

```sml
val idToJson : JsonRpc.id -> Json.value
```

`idToJson id` writes an id or progress token.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) for an out-of-range number or ill-formed UTF-8.

### <a name="val-positionfromjson"></a>`positionFromJson`

```sml
val positionFromJson : Json.value -> position option
```

`positionFromJson v` reads a position with nonnegative coordinates.

### <a name="val-positiontojson"></a>`positionToJson`

```sml
val positionToJson : position -> Json.value
```

`positionToJson p` writes a position.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) when a coordinate is not an LSP unsigned integer.

### <a name="val-rangefromjson"></a>`rangeFromJson`

```sml
val rangeFromJson : Json.value -> range option
```

`rangeFromJson v` reads a well-ordered half-open range.

### <a name="val-rangetojson"></a>`rangeToJson`

```sml
val rangeToJson : range -> Json.value
```

`rangeToJson r` writes a range, using the wire member end for stop.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) when the range is reversed or a coordinate invalid.

### <a name="val-decode"></a>`decode`

```sml
val decode : string -> decoded
```

`decode text` reads one JSON-RPC message under LSP's rules.

Batches, ambiguous envelope members and out-of-range ids/codes are
invalid. Unknown extension members remain permitted.

### <a name="val-encode"></a>`encode`

```sml
val encode : JsonRpc.message -> string
```

`encode message` writes one LSP message, without transport framing.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) for invalid integer ranges, params or UTF-8 text.

### <a name="val-capabilities"></a>`capabilities`

```sml
val capabilities : Json.value -> capabilities option
```

`capabilities v` validates the capability object and encoding list.

### <a name="val-supports"></a>`supports`

```sml
val supports : capabilities * string list -> bool
```

`supports (caps, path)` is whether that capability is true.

### <a name="val-positionencoding"></a>`positionEncoding`

```sml
val positionEncoding : capabilities -> encoding
```

`positionEncoding caps` is the selected encoding: UTF-8 when offered,
then UTF-16 or UTF-32, with UTF-16 as the mandatory fallback.

### <a name="val-encodingname"></a>`encodingName`

```sml
val encodingName : encoding -> string
```

`encodingName encoding` is its protocol spelling.

**Example** `encodingName Utf16 = "utf-16"`

### <a name="val-rawcapabilities"></a>`rawCapabilities`

```sml
val rawCapabilities : capabilities -> Json.value
```

`rawCapabilities caps` is the original capability object.

### <a name="val-servernotinitialized"></a>`serverNotInitialized`

```sml
val serverNotInitialized : integer
```

The error code for a request before initialization.

### <a name="val-contentmodified"></a>`contentModified`

```sml
val contentModified : integer
```

The error code for a result invalidated by a changed context.

### <a name="val-servercancelled"></a>`serverCancelled`

```sml
val serverCancelled : integer
```

The error code for server cancellation where the method permits it.

### <a name="val-requestfailed"></a>`requestFailed`

```sml
val requestFailed : integer
```

The error code for a request that could not be completed.

---

<sub>Generated by runedoc from lib/lsp/protocol\_sig.sml; do not edit.</sub>
