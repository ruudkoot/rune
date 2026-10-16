# signature JSON_RPC

[JSON-RPC](../README.md) &rsaquo; Data formats &rsaquo; **JSON_RPC**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 20 of 20 entries documented |
| Tests | not listed |
| Source | [lib/jsonrpc/jsonrpc\_sig.sml](../../../../lib/jsonrpc/jsonrpc_sig.sml) |

## Synopsis

```sml
signature JSON_RPC
structure JsonRpc :> JSON_RPC
```

| Implementation |  | Source |
| --- | --- | --- |
| [`JsonRpc`](../str/JsonRpc.md) | JsonRpc: JSON-RPC 2.0's messages over Json. | [lib/jsonrpc/jsonrpc.sml](../../../../lib/jsonrpc/jsonrpc.sml) |

JSON-RPC 2.0: requests, notifications and responses as values, read
from JSON and written to it, with the errors of the specification and
the cancellation the Language Server Protocol adds.

## Interface

<pre>
signature JSON_RPC =
sig
  datatype <a href="#type-id">id</a> = <a href="#con-number">Number</a> of int | <a href="#con-string">String</a> of string
  type <a href="#type-error">error</a> = {<a href="#fld-error.code">code</a> : int, <a href="#fld-error.message">message</a> : string, <a href="#fld-error.data">data</a> : Json.value option}
  datatype <a href="#type-outcome">outcome</a> = <a href="#con-result">Result</a> of Json.value | <a href="#con-error">Error</a> of error
  datatype <a href="#type-message">message</a> =
      <a href="#con-request">Request</a> of {<a href="#fld-request.id">id</a> : id, <a href="#fld-request.method">method</a> : string, <a href="#fld-request.params">params</a> : Json.value option}
    | <a href="#con-notification">Notification</a> of {<a href="#fld-notification.method">method</a> : string, <a href="#fld-notification.params">params</a> : Json.value option}
    | <a href="#con-response">Response</a> of {<a href="#fld-response.id">id</a> : id option, <a href="#fld-response.outcome">outcome</a> : outcome}
  datatype <a href="#type-read">read</a> = <a href="#con-message">Message</a> of message | <a href="#con-invalid">Invalid</a> of error * id option
  val <a href="#val-parseerror">parseError</a> : int
  val <a href="#val-invalidrequest">invalidRequest</a> : int
  val <a href="#val-methodnotfound">methodNotFound</a> : int
  val <a href="#val-invalidparams">invalidParams</a> : int
  val <a href="#val-internalerror">internalError</a> : int
  val <a href="#val-requestcancelled">requestCancelled</a> : int
  val <a href="#val-tojson">toJson</a> : message -&gt; Json.value
  val <a href="#val-fromjson">fromJson</a> : Json.value -&gt; read
  val <a href="#val-decode">decode</a> : string -&gt; read list
  val <a href="#val-encode">encode</a> : message list -&gt; string
  exception <a href="#exn-unknown">Unknown</a>
  exception <a href="#exn-failed">Failed</a> of error
  val <a href="#val-answer">answer</a> : (string * Json.value option -&gt; Json.value) * message -&gt; message option
  val <a href="#val-cancel">cancel</a> : id -&gt; message
  val <a href="#val-cancelled">cancelled</a> : message -&gt; id option
end
</pre>

### <a name="type-id"></a>`id`

```sml
datatype id = Number of int | String of string
```

A request's id: a number or a string.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-number"></a>`Number` | `int` |  |
| <a name="con-string"></a>`String` | `string` |  |

### <a name="type-error"></a>`error`

```sml
type error = {code : int, message : string, data : Json.value option}
```

An error's code and message, and anything more about it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-error.code"></a>`code` | `int` |  |
| <a name="fld-error.message"></a>`message` | `string` |  |
| <a name="fld-error.data"></a>`data` | `Json.value option` |  |

### <a name="type-outcome"></a>`outcome`

```sml
datatype outcome = Result of Json.value | Error of error
```

What a request came to: its result, or an error.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-result"></a>`Result` | `Json.value` |  |
| <a name="con-error"></a>`Error` | `error` |  |

### <a name="type-message"></a>`message`

```sml
datatype message =
    Request of {id : id, method : string, params : Json.value option}
  | Notification of {method : string, params : Json.value option}
  | Response of {id : id option, outcome : outcome}
```

A message: a request, a notification, or a response.

A [`Request`](#con-request) asks for a [`Response`](#con-response) with its id; a [`Notification`](#con-notification) asks
for none; a [`Response`](#con-response) carries the outcome, its id `NONE` when the
request's could not be read.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-request"></a>`Request` | `{id : id, method : string, params : Json.value option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.id"></a>`id` | `id` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.method"></a>`method` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-request.params"></a>`params` | `Json.value option` |  |
| <a name="con-notification"></a>`Notification` | `{method : string, params : Json.value option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-notification.method"></a>`method` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-notification.params"></a>`params` | `Json.value option` |  |
| <a name="con-response"></a>`Response` | `{id : id option, outcome : outcome}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.id"></a>`id` | `id option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-response.outcome"></a>`outcome` | `outcome` |  |

### <a name="type-read"></a>`read`

```sml
datatype read = Message of message | Invalid of error * id option
```

A message read, or the error that answers what could not be read,
with the id of the request when it could be read.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-message"></a>`Message` | `message` |  |
| <a name="con-invalid"></a>`Invalid` | `error * id option` |  |

### <a name="val-parseerror"></a>`parseError`

```sml
val parseError : int
```

The code of an error: the text is no JSON.

**Example** `parseError = ~32700`

### <a name="val-invalidrequest"></a>`invalidRequest`

```sml
val invalidRequest : int
```

The code of an error: the JSON is no request.

**Example** `invalidRequest = ~32600`

### <a name="val-methodnotfound"></a>`methodNotFound`

```sml
val methodNotFound : int
```

The code of an error: the server has no such method.

**Example** `methodNotFound = ~32601`

### <a name="val-invalidparams"></a>`invalidParams`

```sml
val invalidParams : int
```

The code of an error: the parameters are not what the method takes.

**Example** `invalidParams = ~32602`

### <a name="val-internalerror"></a>`internalError`

```sml
val internalError : int
```

The code of an error: the server failed.

**Example** `internalError = ~32603`

### <a name="val-requestcancelled"></a>`requestCancelled`

```sml
val requestCancelled : int
```

The code of an error, the Language Server Protocol's: the request was
cancelled.

**Example** `requestCancelled = ~32800`

### <a name="val-tojson"></a>`toJson`

```sml
val toJson : message -> Json.value
```

`toJson m` is `m` as a JSON object, with `"jsonrpc": "2.0"`.

### <a name="val-fromjson"></a>`fromJson`

```sml
val fromJson : Json.value -> read
```

`fromJson v` is the message `v` is, or the error that answers it:
[`invalidRequest`](#val-invalidrequest), with the request's id when it has one it could
read.

**Example** `fromJson (Json.decode "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}") = Message (Notification {method = "exit", params = NONE})`

### <a name="val-decode"></a>`decode`

```sml
val decode : string -> read list
```

`decode s` is the messages of the text `s`, each read or answered as
[`fromJson`](#val-fromjson) reads or answers it.

The text is one message, or a batch, an array of them; a text that is
no JSON, or an empty batch, is one answer.

### <a name="val-encode"></a>`encode`

```sml
val encode : message list -> string
```

`encode ms` is the messages as text: one alone, a batch as an array.

**Example** `encode [Notification {method = "exit", params = NONE}] = "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}"`

### <a name="exn-unknown"></a>`Unknown`

```sml
exception Unknown
```

What a handler raises for a method it does not have.

### <a name="exn-failed"></a>`Failed`

```sml
exception Failed of error
```

What a handler raises to answer with an error.

### <a name="val-answer"></a>`answer`

```sml
val answer : (string * Json.value option -> Json.value) * message -> message option
```

`answer (serve, m)` is what a server answers `m` with, calling
`serve (method, params)`.

For a request it is the result of `serve`, an error when it raises
[`Failed`](#exn-failed), and [`methodNotFound`](#val-methodnotfound) when it raises [`Unknown`](#exn-unknown); for a
notification nothing, `serve` being called all the same; and nothing
for a response.

### <a name="val-cancel"></a>`cancel`

```sml
val cancel : id -> message
```

`cancel i` is the notification that asks the server to give up the
request `i` (`$/cancelRequest`).

**Example** `cancelled (cancel (Number 3)) = SOME (Number 3)`

### <a name="val-cancelled"></a>`cancelled`

```sml
val cancelled : message -> id option
```

`cancelled m` is the request `m` asks to cancel, if it is a
`$/cancelRequest`.

---

<sub>Generated by runedoc from lib/jsonrpc/jsonrpc\_sig.sml; do not edit.</sub>
