# signature ZMTP

[ZMTP](../README.md) &rsaquo; Networking &rsaquo; **ZMTP**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/zmtp/zmtp\_sig.sml](../../../../lib/zmtp/zmtp_sig.sml) |

## Synopsis

```sml
signature ZMTP
structure Zmtp :> ZMTP
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Zmtp`](../str/Zmtp.md) | Zmtp: ZeroMQ's sockets over the Basis's TCP sockets. | [lib/zmtp/zmtp.sml](../../../../lib/zmtp/zmtp.sml) |

ZeroMQ's sockets over ZMTP 3.1 with the NULL mechanism, on the Basis's
TCP sockets: the kinds a Jupyter kernel and its clients use.

A socket binds a port, where any number of peers connect, or connects
to one. Nothing runs behind the program's back: [`wait`](#val-wait) reads and writes
every connection of the sockets it is given until one of them has a
message or the time is up, and [`send`](#val-send) only queues what [`wait`](#val-wait) (or
[`flush`](#val-flush)) writes. A [`Router`](#con-router) receives each message with the identity of
the peer that sent it first, and sends to the peer a message's first
part names; a [`Dealer`](#con-dealer) sends to its peers in turn; a [`Rep`](#con-rep) answers the
peer of the last request with that request's envelope, and a [`Req`](#con-req)
puts the empty delimiter before what it sends and takes it off what it
receives; a [`Pub`](#con-pub) sends to every peer that subscribed to a prefix of a
message's first part, and a [`Sub`](#con-sub) subscribes.

## Interface

<pre>
signature ZMTP =
sig
  datatype <a href="#type-kind">kind</a> = <a href="#con-router">Router</a> | <a href="#con-dealer">Dealer</a> | <a href="#con-rep">Rep</a> | <a href="#con-req">Req</a> | <a href="#con-pub">Pub</a> | <a href="#con-sub">Sub</a>
  type <a href="#type-socket">socket</a>
  exception <a href="#exn-error">Error</a> of string
  val <a href="#val-bind">bind</a> : kind * {<a href="#fld-bind.host">host</a> : string, <a href="#fld-bind.port">port</a> : int} -&gt; socket
  val <a href="#val-connect">connect</a> : kind * {<a href="#fld-connect.host">host</a> : string, <a href="#fld-connect.port">port</a> : int} * {identity : string option} -&gt; socket
  val <a href="#val-port">port</a> : socket -&gt; int
  val <a href="#val-subscribe">subscribe</a> : socket * string -&gt; unit
  val <a href="#val-send">send</a> : socket * string list -&gt; unit
  val <a href="#val-receive">receive</a> : socket -&gt; string list option
  val <a href="#val-wait">wait</a> : socket list * Time.time option -&gt; socket list
  val <a href="#val-flush">flush</a> : socket * Time.time option -&gt; unit
  val <a href="#val-close">close</a> : socket -&gt; unit
end
</pre>

### <a name="type-kind"></a>`kind`

```sml
datatype kind = Router | Dealer | Rep | Req | Pub | Sub
```

The kinds of socket.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-router"></a>`Router` |  |  |
| <a name="con-dealer"></a>`Dealer` |  |  |
| <a name="con-rep"></a>`Rep` |  |  |
| <a name="con-req"></a>`Req` |  |  |
| <a name="con-pub"></a>`Pub` |  |  |
| <a name="con-sub"></a>`Sub` |  |  |

### <a name="type-socket"></a>`socket`

```sml
type socket
```

A socket of one of the kinds: its connections and what it has
received.

### <a name="exn-error"></a>`Error`

```sml
exception Error of string
```

What the operations raise when the system's sockets fail, or a
socket is asked for what its kind does not do.

### <a name="val-bind"></a>`bind`

```sml
val bind : kind * {host : string, port : int} -> socket
```

`bind (k, {host, port})` is a socket of kind `k` listening at `host`
(`"*"` for every address) and `port` (0 for one the system picks,
which `port` tells).

**Raises** [`Error`](#exn-error) when the port cannot be bound.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-bind.host"></a>`host` | `string` |  |
| <a name="fld-bind.port"></a>`port` | `int` |  |

### <a name="val-connect"></a>`connect`

```sml
val connect : kind * {host : string, port : int} * {identity : string option} -> socket
```

`connect (k, {host, port}, {identity})` is a socket of kind `k`
connected to a socket bound at `host` and `port`, with the identity
a [`Router`](#con-router) there knows it by.

**Raises** [`Error`](#exn-error) when the connection is refused.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-connect.host"></a>`host` | `string` |  |
| <a name="fld-connect.port"></a>`port` | `int` |  |

### <a name="val-port"></a>`port`

```sml
val port : socket -> int
```

`port s` is the port `s` is bound to or connected to.

### <a name="val-subscribe"></a>`subscribe`

```sml
val subscribe : socket * string -> unit
```

`subscribe (s, prefix)` asks the publishers `s` is connected to for
the messages whose first part begins with `prefix`; `""` is all.

**Raises** [`Error`](#exn-error) when `s` is not a [`Sub`](#con-sub).

### <a name="val-send"></a>`send`

```sml
val send : socket * string list -> unit
```

`send (s, parts)` queues the message of `parts` for the peers of
`s`, as its kind sends.

**Raises** [`Error`](#exn-error) when `s` is a [`Sub`](#con-sub), or a [`Rep`](#con-rep) that has no request
to answer.

### <a name="val-receive"></a>`receive`

```sml
val receive : socket -> string list option
```

`receive s` is the next message `s` has received, or `NONE`; it does
not wait.

### <a name="val-wait"></a>`wait`

```sml
val wait : socket list * Time.time option -> socket list
```

`wait (ss, t)` reads and writes the connections of `ss` until one of
them has a message, or `t` has passed (`NONE`: as long as it takes),
and is those that have one.

### <a name="val-flush"></a>`flush`

```sml
val flush : socket * Time.time option -> unit
```

`flush (s, t)` writes what is queued for the peers of `s`, waiting
at most `t` for them to take it.

### <a name="val-close"></a>`close`

```sml
val close : socket -> unit
```

`close s` closes `s` and its connections.

---

<sub>Generated by runedoc from lib/zmtp/zmtp\_sig.sml; do not edit.</sub>
