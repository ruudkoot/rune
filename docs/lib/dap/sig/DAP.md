# signature DAP

[Debug Adapter Protocol](../README.md) &rsaquo; Data formats &rsaquo; **DAP**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/dap/dap\_sig.sml](../../../../lib/dap/dap_sig.sml) |

## Synopsis

```sml
signature DAP
structure Dap :> DAP
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Dap`](../str/Dap.md) | Dap: the Debug Adapter Protocol's messages over Json. | [lib/dap/dap.sml](../../../../lib/dap/dap.sml) |

The Debug Adapter Protocol's messages: requests, responses and events
as values, read from JSON and written to it, framed as the protocol
frames them (`Content-Length`, `Framing`), and the events an adapter
sends most.

Every message has a sequence number, which the side that sends it
counts from 1; a response names the request it answers by its number.

## Interface

<pre>
signature DAP =
sig
  datatype <a href="#type-message">message</a> =
      <a href="#con-request">Request</a> of {<a href="#fld-request.seq">seq</a> : int, <a href="#fld-request.command">command</a> : string, <a href="#fld-request.arguments">arguments</a> : Json.value option}
    | <a href="#con-response">Response</a> of {<a href="#fld-response.seq">seq</a> : int, <a href="#fld-response.requestseq">requestSeq</a> : int, <a href="#fld-response.success">success</a> : bool, <a href="#fld-response.command">command</a> : string,
                   <a href="#fld-response.message">message</a> : string option, <a href="#fld-response.body">body</a> : Json.value option}
    | <a href="#con-event">Event</a> of {<a href="#fld-event.seq">seq</a> : int, <a href="#fld-event.event">event</a> : string, <a href="#fld-event.body">body</a> : Json.value option}
  val <a href="#val-tojson">toJson</a> : message -&gt; Json.value
  val <a href="#val-fromjson">fromJson</a> : Json.value -&gt; message option
  val <a href="#val-encode">encode</a> : message -&gt; string
  val <a href="#val-decode">decode</a> : string -&gt; message option
  val <a href="#val-reply">reply</a> : {<a href="#fld-reply.seq">seq</a> : int, <a href="#fld-reply.request">request</a> : message, <a href="#fld-reply.body">body</a> : Json.value option} -&gt; message option
  val <a href="#val-refuse">refuse</a> : {<a href="#fld-refuse.seq">seq</a> : int, <a href="#fld-refuse.request">request</a> : message, <a href="#fld-refuse.message">message</a> : string} -&gt; message option
  val <a href="#val-initialized">initialized</a> : int -&gt; message
  val <a href="#val-stopped">stopped</a> : {<a href="#fld-stopped.seq">seq</a> : int, <a href="#fld-stopped.reason">reason</a> : string, <a href="#fld-stopped.threadid">threadId</a> : int, <a href="#fld-stopped.text">text</a> : string option} -&gt; message
  val <a href="#val-output">output</a> : {<a href="#fld-output.seq">seq</a> : int, <a href="#fld-output.category">category</a> : string, <a href="#fld-output.output">output</a> : string} -&gt; message
  val <a href="#val-terminated">terminated</a> : int -&gt; message
  val <a href="#val-exited">exited</a> : {<a href="#fld-exited.seq">seq</a> : int, <a href="#fld-exited.exitcode">exitCode</a> : int} -&gt; message
end
</pre>

### <a name="type-message"></a>`message`

```sml
datatype message =
    Request of {seq : int, command : string, arguments : Json.value option}
  | Response of {seq : int, requestSeq : int, success : bool, command : string,
                 message : string option, body : Json.value option}
  | Event of {seq : int, event : string, body : Json.value option}
```

A message of the protocol.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-request"></a>`Request` | `{seq : int, command : string, arguments : Json.value option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.seq"></a>`seq` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.command"></a>`command` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.arguments"></a>`arguments` | `Json.value option` |  |
| <a name="con-response"></a>`Response` | `{seq : int, requestSeq : int, success : bool, command : string, message : string option, body : Json.value option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.seq"></a>`seq` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.requestseq"></a>`requestSeq` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.success"></a>`success` | `bool` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.command"></a>`command` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.message"></a>`message` | `string option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.body"></a>`body` | `Json.value option` |  |
| <a name="con-event"></a>`Event` | `{seq : int, event : string, body : Json.value option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-event.seq"></a>`seq` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-event.event"></a>`event` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-event.body"></a>`body` | `Json.value option` |  |

### <a name="val-tojson"></a>`toJson`

```sml
val toJson : message -> Json.value
```

`toJson m` is `m` as the protocol writes it, with its `type`.

### <a name="val-fromjson"></a>`fromJson`

```sml
val fromJson : Json.value -> message option
```

`fromJson v` is the message `v` is, or `NONE` when it is not one of
the protocol's.

**Example** `fromJson (Json.decode "{\"seq\":1,\"type\":\"request\",\"command\":\"threads\"}") = SOME (Request {seq = 1, command = "threads", arguments = NONE})`

### <a name="val-encode"></a>`encode`

```sml
val encode : message -> string
```

`encode m` is `m` framed for the wire: its header and its JSON.

**Example** `String.isPrefix "Content-Length: " (encode (Event {seq = 1, event = "initialized", body = NONE}))`

### <a name="val-decode"></a>`decode`

```sml
val decode : string -> message option
```

`decode s` is the message whose body, its framing taken off, is `s`,
or `NONE` when it is no message.

### <a name="val-reply"></a>`reply`

```sml
val reply : {seq : int, request : message, body : Json.value option} -> message option
```

`reply {seq, request, body}` is the successful response numbered
`seq` to `request`, or `NONE` when `request` is no request.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-reply.seq"></a>`seq` | `int` |  |
| <a name="fld-reply.request"></a>`request` | `message` |  |
| <a name="fld-reply.body"></a>`body` | `Json.value option` |  |

### <a name="val-refuse"></a>`refuse`

```sml
val refuse : {seq : int, request : message, message : string} -> message option
```

`refuse {seq, request, message}` is the failed response numbered `seq`
to `request`, saying `message`, or `NONE` when `request` is no
request.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-refuse.seq"></a>`seq` | `int` |  |
| <a name="fld-refuse.request"></a>`request` | `message` |  |
| <a name="fld-refuse.message"></a>`message` | `string` |  |

### <a name="val-initialized"></a>`initialized`

```sml
val initialized : int -> message
```

`initialized seq` is the event that the adapter is ready to be
configured.

### <a name="val-stopped"></a>`stopped`

```sml
val stopped : {seq : int, reason : string, threadId : int, text : string option} -> message
```

`stopped {seq, reason, threadId, text}` is the event that a thread
stopped, for a reason such as `"breakpoint"`, `"step"`, `"exception"`
or `"pause"`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-stopped.seq"></a>`seq` | `int` |  |
| <a name="fld-stopped.reason"></a>`reason` | `string` |  |
| <a name="fld-stopped.threadid"></a>`threadId` | `int` |  |
| <a name="fld-stopped.text"></a>`text` | `string option` |  |

### <a name="val-output"></a>`output`

```sml
val output : {seq : int, category : string, output : string} -> message
```

`output {seq, category, output}` is the event of the program's or the
adapter's output, of a category such as `"stdout"`, `"stderr"` or
`"console"`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-output.seq"></a>`seq` | `int` |  |
| <a name="fld-output.category"></a>`category` | `string` |  |
| <a name="fld-output.output"></a>`output` | `string` |  |

### <a name="val-terminated"></a>`terminated`

```sml
val terminated : int -> message
```

`terminated seq` is the event that the session has ended.

### <a name="val-exited"></a>`exited`

```sml
val exited : {seq : int, exitCode : int} -> message
```

`exited {seq, exitCode}` is the event that the program has exited,
with its status.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-exited.seq"></a>`seq` | `int` |  |
| <a name="fld-exited.exitcode"></a>`exitCode` | `int` |  |

---

<sub>Generated by runedoc from lib/dap/dap\_sig.sml; do not edit.</sub>
