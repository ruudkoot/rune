# signature ZMTP_WIRE

[ZMTP](../README.md) &rsaquo; Networking &rsaquo; **ZMTP_WIRE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/zmtp/wire\_sig.sml](../../../../lib/zmtp/wire_sig.sml) |

## Synopsis

```sml
signature ZMTP_WIRE
structure ZmtpWire :> ZMTP_WIRE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ZmtpWire`](../str/ZmtpWire.md) | ZmtpWire: ZMTP 3.1's greeting, frames and metadata. | [lib/zmtp/wire.sml](../../../../lib/zmtp/wire.sml) |

ZMTP 3.1's bytes (rfc.zeromq.org/spec/37): the greeting, frames and
commands, and the metadata of READY.

A connection begins with a greeting of 64 bytes from each side, then
the handshake of the security mechanism -- for NULL, a READY command
each way, with the socket's type and identity -- and then frames: a
message is one or more data frames, all but the last flagged MORE.

## Interface

<pre>
signature ZMTP_WIRE =
sig
  val <a href="#val-greeting">greeting</a> : {<a href="#fld-greeting.mechanism">mechanism</a> : string, <a href="#fld-greeting.server">server</a> : bool} -&gt; string
  type <a href="#type-peer">peer</a> = {<a href="#fld-peer.major">major</a> : int, <a href="#fld-peer.minor">minor</a> : int, <a href="#fld-peer.mechanism">mechanism</a> : string, <a href="#fld-peer.server">server</a> : bool}
  val <a href="#val-readgreeting">readGreeting</a> : string -&gt; peer option
  datatype <a href="#type-frame">frame</a> = <a href="#con-data">Data</a> of {<a href="#fld-data.more">more</a> : bool, <a href="#fld-data.body">body</a> : string} | <a href="#con-command">Command</a> of {<a href="#fld-command.name">name</a> : string, <a href="#fld-command.data">data</a> : string}
  val <a href="#val-encode">encode</a> : frame -&gt; string
  val <a href="#val-message">message</a> : string list -&gt; string
  exception <a href="#exn-malformed">Malformed</a> of string
  type <a href="#type-reader">reader</a>
  val <a href="#val-reader">reader</a> : reader
  val <a href="#val-feed">feed</a> : reader * string -&gt; frame list * reader
  val <a href="#val-ready">ready</a> : (string * string) list -&gt; frame
  val <a href="#val-properties">properties</a> : string -&gt; (string * string) list
end
</pre>

### <a name="val-greeting"></a>`greeting`

```sml
val greeting : {mechanism : string, server : bool} -> string
```

`greeting {mechanism, server}` is the 64 bytes that begin a
connection.

They say ZMTP 3.1, the mechanism's name, and whether this side is the
server of the mechanism (NULL has none).

**Example** `size (greeting {mechanism = "NULL", server = false}) = 64`

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-greeting.mechanism"></a>`mechanism` | `string` |  |
| <a name="fld-greeting.server"></a>`server` | `bool` |  |

### <a name="type-peer"></a>`peer`

```sml
type peer = {major : int, minor : int, mechanism : string, server : bool}
```

What a peer's greeting says.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-peer.major"></a>`major` | `int` |  |
| <a name="fld-peer.minor"></a>`minor` | `int` |  |
| <a name="fld-peer.mechanism"></a>`mechanism` | `string` |  |
| <a name="fld-peer.server"></a>`server` | `bool` |  |

### <a name="val-readgreeting"></a>`readGreeting`

```sml
val readGreeting : string -> peer option
```

`readGreeting s` is what the greeting `s`, 64 bytes, says, or `NONE`
when it is not one: its signature wrong, or a version before 3.

**Example** `readGreeting (greeting {mechanism = "NULL", server = true}) = SOME {major = 3, minor = 1, mechanism = "NULL", server = true}`

### <a name="type-frame"></a>`frame`

```sml
datatype frame = Data of {more : bool, body : string} | Command of {name : string, data : string}
```

A frame: data, and whether more of the message follows, or a
command, its name and its data.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-data"></a>`Data` | `{more : bool, body : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-data.more"></a>`more` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-data.body"></a>`body` | `string` |  |
| <a name="con-command"></a>`Command` | `{name : string, data : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-command.name"></a>`name` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-command.data"></a>`data` | `string` |  |

### <a name="val-encode"></a>`encode`

```sml
val encode : frame -> string
```

`encode f` is the bytes of `f`: its flags, its size in one byte or
eight, and its body.

**Example** `encode (Data {more = true, body = "ab"}) = "\001\002ab"`

### <a name="val-message"></a>`message`

```sml
val message : string list -> string
```

`message parts` is the frames of a message of those parts.

**Example** `message ["a", "b"] = "\001\001a\000\001b"`

### <a name="exn-malformed"></a>`Malformed`

```sml
exception Malformed of string
```

What [`feed`](#val-feed) raises for bytes that are no frame: a size past what a
string holds, or a command whose name runs past its body.

### <a name="type-reader"></a>`reader`

```sml
type reader
```

A reader of frames: the bytes of a frame begun and not yet complete.

### <a name="val-reader"></a>`reader`

```sml
val reader : reader
```

The reader that has read nothing.

### <a name="val-feed"></a>`feed`

```sml
val feed : reader * string -> frame list * reader
```

`feed (r, s)` is the frames that `r`'s bytes and `s` complete, and the
reader that holds the rest.

**Raises** [`Malformed`](#exn-malformed) for bytes that are no frame.

### <a name="val-ready"></a>`ready`

```sml
val ready : (string * string) list -> frame
```

`ready props` is NULL's READY command with the metadata `props`,
such as `("Socket-Type", "ROUTER")`.

### <a name="val-properties"></a>`properties`

```sml
val properties : string -> (string * string) list
```

`properties d` is the metadata of a READY command's data.

**Raises** [`Malformed`](#exn-malformed) when `d` is not metadata.

**Example** `properties (case ready [("Socket-Type", "REQ")] of Command {data, ...} => data | _ => "") = [("Socket-Type", "REQ")]`

---

<sub>Generated by runedoc from lib/zmtp/wire\_sig.sml; do not edit.</sub>
