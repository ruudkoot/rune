# signature JUPYTER

[Jupyter](../README.md) &rsaquo; Networking &rsaquo; **JUPYTER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 15 of 15 entries documented |
| Tests | not listed |
| Source | [lib/jupyter/jupyter\_sig.sml](../../../../lib/jupyter/jupyter_sig.sml) |

## Synopsis

```sml
signature JUPYTER
structure Jupyter :> JUPYTER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Jupyter`](../str/Jupyter.md) | Jupyter: a kernel's side of Jupyter's messaging protocol, over Zmtp. | [lib/jupyter/jupyter.sml](../../../../lib/jupyter/jupyter.sml) |

Jupyter's messaging protocol (5.4) for a kernel: the connection file,
the signed messages of the wire, and a kernel's loop on its five
channels, the language's part given as handlers.

A message on the wire is the identities of the peer, the delimiter
`<IDS|MSG>`, the HMAC-SHA256 of the next four parts in hexadecimal, the
header, the parent's header, the metadata and the content, each JSON,
and the binary buffers. A kernel binds the shell, control and stdin
channels as ROUTERs, iopub as a PUB and heartbeat as a REP; it says
`busy` on iopub before it handles a request and `idle` after, answers
`kernel_info_request` and `shutdown_request` itself, and gives the
other requests to the language.

## Interface

<pre>
signature JUPYTER =
sig
  type <a href="#type-connection">connection</a> = {<a href="#fld-connection.transport">transport</a> : string, <a href="#fld-connection.ip">ip</a> : string, <a href="#fld-connection.shell">shell</a> : int, <a href="#fld-connection.iopub">iopub</a> : int, <a href="#fld-connection.stdin">stdin</a> : int, <a href="#fld-connection.control">control</a> : int,
                     <a href="#fld-connection.heartbeat">heartbeat</a> : int, <a href="#fld-connection.key">key</a> : string, <a href="#fld-connection.scheme">scheme</a> : string}
  exception <a href="#exn-connection">Connection</a> of string
  val <a href="#val-readconnection">readConnection</a> : string -&gt; connection
  type <a href="#type-header">header</a> = {<a href="#fld-header.msgid">msgId</a> : string, <a href="#fld-header.session">session</a> : string, <a href="#fld-header.username">username</a> : string, <a href="#fld-header.date">date</a> : string, <a href="#fld-header.msgtype">msgType</a> : string,
                 <a href="#fld-header.version">version</a> : string}
  type <a href="#type-message">message</a> = {<a href="#fld-message.identities">identities</a> : string list, <a href="#fld-message.header">header</a> : header, <a href="#fld-message.parent">parent</a> : Json.value, <a href="#fld-message.metadata">metadata</a> : Json.value,
                  <a href="#fld-message.content">content</a> : Json.value, <a href="#fld-message.buffers">buffers</a> : string list}
  val <a href="#val-headerjson">headerJson</a> : header -&gt; Json.value
  val <a href="#val-headerof">headerOf</a> : Json.value -&gt; header option
  val <a href="#val-sign">sign</a> : string * string list -&gt; string
  val <a href="#val-encode">encode</a> : string -&gt; message -&gt; string list
  val <a href="#val-decode">decode</a> : string -&gt; string list -&gt; message option
  type <a href="#type-kernel">kernel</a>
  val <a href="#val-bind">bind</a> : connection -&gt; kernel
  type <a href="#type-request">request</a> = {<a href="#fld-request.msgtype">msgType</a> : string, <a href="#fld-request.content">content</a> : Json.value, <a href="#fld-request.publish">publish</a> : string * Json.value -&gt; unit,
                  <a href="#fld-request.input">input</a> : {prompt : string, password : bool} -&gt; string option, <a href="#fld-request.idle">idle</a> : unit -&gt; unit}
  val <a href="#val-serve">serve</a> : kernel * {<a href="#fld-serve.info">info</a> : (string * Json.value) list, <a href="#fld-serve.respond">respond</a> : request -&gt; Json.value option} -&gt; unit
  val <a href="#val-close">close</a> : kernel -&gt; unit
end
</pre>

### <a name="type-connection"></a>`connection`

```sml
type connection = {transport : string, ip : string, shell : int, iopub : int, stdin : int, control : int,
                   heartbeat : int, key : string, scheme : string}
```

The connection file a kernel is started with: where to bind, and the
key and scheme of the signatures.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-connection.transport"></a>`transport` | `string` |  |
| <a name="fld-connection.ip"></a>`ip` | `string` |  |
| <a name="fld-connection.shell"></a>`shell` | `int` |  |
| <a name="fld-connection.iopub"></a>`iopub` | `int` |  |
| <a name="fld-connection.stdin"></a>`stdin` | `int` |  |
| <a name="fld-connection.control"></a>`control` | `int` |  |
| <a name="fld-connection.heartbeat"></a>`heartbeat` | `int` |  |
| <a name="fld-connection.key"></a>`key` | `string` |  |
| <a name="fld-connection.scheme"></a>`scheme` | `string` |  |

### <a name="exn-connection"></a>`Connection`

```sml
exception Connection of string
```

What [`readConnection`](#val-readconnection) raises for a connection file it cannot read.

### <a name="val-readconnection"></a>`readConnection`

```sml
val readConnection : string -> connection
```

`readConnection text` is the connection file `text`.

**Raises** [`Connection`](#exn-connection) when it is not JSON with the fields of one.

### <a name="type-header"></a>`header`

```sml
type header = {msgId : string, session : string, username : string, date : string, msgType : string,
               version : string}
```

A message's header.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-header.msgid"></a>`msgId` | `string` |  |
| <a name="fld-header.session"></a>`session` | `string` |  |
| <a name="fld-header.username"></a>`username` | `string` |  |
| <a name="fld-header.date"></a>`date` | `string` |  |
| <a name="fld-header.msgtype"></a>`msgType` | `string` |  |
| <a name="fld-header.version"></a>`version` | `string` |  |

### <a name="type-message"></a>`message`

```sml
type message = {identities : string list, header : header, parent : Json.value, metadata : Json.value,
                content : Json.value, buffers : string list}
```

A message, with the identities that route it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-message.identities"></a>`identities` | `string list` |  |
| <a name="fld-message.header"></a>`header` | `header` |  |
| <a name="fld-message.parent"></a>`parent` | `Json.value` |  |
| <a name="fld-message.metadata"></a>`metadata` | `Json.value` |  |
| <a name="fld-message.content"></a>`content` | `Json.value` |  |
| <a name="fld-message.buffers"></a>`buffers` | `string list` |  |

### <a name="val-headerjson"></a><a name="val-headerof"></a>`headerJson`, `headerOf`

```sml
val headerJson : header -> Json.value
val headerOf : Json.value -> header option
```

`headerJson h` is `h` as JSON, and `headerOf v` the header that `v` is.

**Example** `headerOf (headerJson {msgId = "1", session = "s", username = "u", date = "d", msgType = "t", version = "5.4"}) = SOME {msgId = "1", session = "s", username = "u", date = "d", msgType = "t", version = "5.4"}`

### <a name="val-sign"></a>`sign`

```sml
val sign : string * string list -> string
```

`sign (key, parts)` is the signature of the four JSON parts of a
message under `key`: their HMAC-SHA256 in hexadecimal, or `""` when
the key is empty.

### <a name="val-encode"></a>`encode`

```sml
val encode : string -> message -> string list
```

`encode key m` is the parts of `m` on the wire, signed with `key`.

### <a name="val-decode"></a>`decode`

```sml
val decode : string -> string list -> message option
```

`decode key parts` is the message of the wire's `parts`, or `NONE`
when they are not one or their signature is not `key`'s.

What [`encode`](#val-encode) writes, [`decode`](#val-decode) reads back with the same key, when the
message's JSON is as lib/json reads it back; tests/lib/jupyter checks
that, and that another key or a changed part is refused.

### <a name="type-kernel"></a>`kernel`

```sml
type kernel
```

A kernel: its sockets, its session and the count of executions.

### <a name="val-bind"></a>`bind`

```sml
val bind : connection -> kernel
```

`bind c` is a kernel bound at the ports of `c`.

It raises lib/zmtp's error when a port cannot be bound.

### <a name="type-request"></a>`request`

```sml
type request = {msgType : string, content : Json.value, publish : string * Json.value -> unit,
                input : {prompt : string, password : bool} -> string option, idle : unit -> unit}
```

What a handler is given: the request, and what it may do while it
answers.

`publish (msgType, content)` says something on iopub as the
request's child, such as a `stream` or an `execute_result`.
`input {prompt, password}` asks the client for a line of input on the
stdin channel, where the request allows it (`NONE` where it does not
or the client gave none). `idle ()`, which a handler that takes long
calls now and then, writes what it published and answers the
heartbeat.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-request.msgtype"></a>`msgType` | `string` |  |
| <a name="fld-request.content"></a>`content` | `Json.value` |  |
| <a name="fld-request.publish"></a>`publish` | `string * Json.value -> unit` |  |
| <a name="fld-request.input"></a>`input` | `{prompt : string, password : bool} -> string option` |  |
| <a name="fld-request.idle"></a>`idle` | `unit -> unit` |  |

### <a name="val-serve"></a>`serve`

```sml
val serve : kernel * {info : (string * Json.value) list, respond : request -> Json.value option} -> unit
```

`serve (k, {info, respond})` is the kernel's loop, until a
`shutdown_request` ends it.

`info` is the fields of
`kernel_info_reply` that are the language's (`implementation`,
`language_info`, `banner`, ...); `respond r` is the content of the
reply to `r`, whose type is the request's with `_reply`, or `NONE`
for no reply (a request the kernel does not know).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-serve.info"></a>`info` | `(string * Json.value) list` |  |
| <a name="fld-serve.respond"></a>`respond` | `request -> Json.value option` |  |

### <a name="val-close"></a>`close`

```sml
val close : kernel -> unit
```

`close k` closes the kernel's sockets.

---

<sub>Generated by runedoc from lib/jupyter/jupyter\_sig.sml; do not edit.</sub>
