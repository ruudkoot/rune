# signature INET_SOCK

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **INET_SOCK**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 17 of 17 entries documented |
| Tests | 29 checks of 10 entries |
| Source | [lib/basis/sig\_inet\_sock.sml](../../../../lib/basis/sig_inet_sock.sml) |

## Synopsis

```sml
signature INET_SOCK
structure INetSock : INET_SOCK  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `INetSock` |  | [lib/basis/inetsock.sml](../../../../lib/basis/inetsock.sml) |

Sockets of the internet family: an address is a host and a port.

This is [`SOCKET`](../sig/SOCKET.md) with the address family fixed, so `('mode) stream_sock`
and [`dgram_sock`](#type-dgram_sock) are the sockets of it and [`sock_addr`](#type-sock_addr) its addresses.
[`toAddr`](#val-toaddr) builds one from a host address and a port number, and [`any`](#val-any) an
address on every interface of this machine.

[`UDP`](#str-udp) makes sockets that send messages, [`TCP`](#str-tcp) sockets that carry a stream.

> **Limitation** `INET_SOCK/ipv4-only`. There is no IPv6: an address here is
> an IPv4 address and a port.

## Interface

<pre>
signature INET_SOCK =
sig
  type <a href="#type-inet">inet</a>

  type 'sock_type <a href="#type-sock">sock</a> = (inet, 'sock_type) Socket.sock

  type 'mode <a href="#type-stream_sock">stream_sock</a> = 'mode Socket.stream sock

  type <a href="#type-dgram_sock">dgram_sock</a> = Socket.dgram sock

  type <a href="#type-sock_addr">sock_addr</a> = inet Socket.sock_addr

  val <a href="#val-inetaf">inetAF</a> : Socket.AF.addr_family

  val <a href="#val-toaddr">toAddr</a> : NetHostDB.in_addr * int -&gt; sock_addr

  val <a href="#val-fromaddr">fromAddr</a> : sock_addr -&gt; NetHostDB.in_addr * int

  val <a href="#val-any">any</a> : int -&gt; sock_addr

  structure <a href="#str-udp">UDP</a> :
  sig
    val <a href="#val-udp.socket">socket</a> : unit -&gt; dgram_sock

    val <a href="#val-udp.socket-prime">socket'</a> : int -&gt; dgram_sock
  end

  structure <a href="#str-tcp">TCP</a> :
  sig
    val <a href="#val-tcp.socket">socket</a> : unit -&gt; 'mode stream_sock

    val <a href="#val-tcp.socket-prime">socket'</a> : int -&gt; 'mode stream_sock

    val <a href="#val-tcp.getnodelay">getNODELAY</a> : 'mode stream_sock -&gt; bool

    val <a href="#val-tcp.setnodelay">setNODELAY</a> : 'mode stream_sock * bool -&gt; unit
  end
end
</pre>

### <a name="type-inet"></a>`inet`

```sml
type inet
```

The type that marks the internet family, and holds nothing.

### <a name="type-sock"></a>`sock`

```sml
type 'sock_type sock = (inet, 'sock_type) Socket.sock
```

The type of a socket of this family.

### <a name="type-stream_sock"></a>`stream_sock`

```sml
type 'mode stream_sock = 'mode Socket.stream sock
```

The type of a stream socket of this family, listening or connected.

### <a name="type-dgram_sock"></a>`dgram_sock`

```sml
type dgram_sock = Socket.dgram sock
```

The type of a message socket of this family.

### <a name="type-sock_addr"></a>`sock_addr`

```sml
type sock_addr = inet Socket.sock_addr
```

The type of an address of this family: a host and a port.

### <a name="val-inetaf"></a>`inetAF`

```sml
val inetAF : Socket.AF.addr_family
```

The address family of the internet sockets, for [`Socket.familyOfAddr`](../sig/SOCKET.md#val-familyofaddr) to give back.

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `named-INET` &middot; `fromString-INET`

</details>

### <a name="val-toaddr"></a>`toAddr`

```sml
val toAddr : NetHostDB.in_addr * int -> sock_addr
```

`toAddr (a, port)` is the address of the port `port` at the host address `a`.

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `fromAddr` &middot; `round-trip` &middot; `connect-to-it`

</details>

### <a name="val-fromaddr"></a>`fromAddr`

```sml
val fromAddr : sock_addr -> NetHostDB.in_addr * int
```

`fromAddr a` is the host address and the port that `a` names.

**Example** `(fn (a, p) => (NetHostDB.toString a, p)) (fromAddr (toAddr (valOf (NetHostDB.fromString "127.0.0.1"), 80))) = ("127.0.0.1", 80)`

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `ports` &middot; `hosts` &middot; `bound-socket`

</details>

### <a name="val-any"></a>`any`

```sml
val any : int -> sock_addr
```

`any port` is the address of `port` on every interface of this machine.

It is what a program binds to when it will answer on whichever
interface a connection arrives at; a port of 0 asks the system to choose
one.

<details><summary>Tests (5)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `fromAddr` &middot; `port-0` &middot; `is-0.0.0.0` &middot; `bind` &middot; `reached-through-loopback`

</details>

### <a name="str-udp"></a>`UDP`

Sockets that send messages, over UDP.

#### <a name="val-udp.socket"></a>`socket`

```sml
val socket : unit -> dgram_sock
```

`socket ()` is a new message socket, with the protocol the system picks for messages.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `dgram` &middot; `works` &middot; `new-each-time`

</details>

#### <a name="val-udp.socket-prime"></a>`socket'`

```sml
val socket' : int -> dgram_sock
```

`socket' n` is a new message socket using the protocol numbered `n`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

> **Implementation** `INetSock.UDP.socket'/protocol-numbers`. The numbers
> are IANA's, so 17 is UDP; 0 asks the system to choose, which makes it
> the same as `socket ()`.

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `zero-dgram` &middot; `zero-works` &middot; `udp-protocol`

</details>

### <a name="str-tcp"></a>`TCP`

Sockets that carry a stream, over TCP.

#### <a name="val-tcp.socket"></a>`socket`

```sml
val socket : unit -> 'mode stream_sock
```

`socket ()` is a new stream socket, with the protocol the system picks for streams.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `stream` &middot; `works`

</details>

#### <a name="val-tcp.socket-prime"></a>`socket'`

```sml
val socket' : int -> 'mode stream_sock
```

`socket' n` is a new stream socket using the protocol numbered `n`; 6 is TCP.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `zero-stream` &middot; `zero-works` &middot; `tcp-protocol`

</details>

#### <a name="val-tcp.getnodelay"></a>`getNODELAY`

```sml
val getNODELAY : 'mode stream_sock -> bool
```

`getNODELAY sock` is `true` when small writes go out at once rather than being gathered.

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `default` &middot; `listener-default`

</details>

#### <a name="val-tcp.setnodelay"></a>`setNODELAY`

```sml
val setNODELAY : 'mode stream_sock * bool -> unit
```

`setNODELAY (sock, b)` sends small writes at once, or lets them be gathered.

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `on` &middot; `off-again` &middot; `connected`

</details>

## See also

[`SOCKET`](../sig/SOCKET.md), [`NET_HOST_DB`](../sig/NET_HOST_DB.md), [`UNIX_SOCK`](../sig/UNIX_SOCK.md), [`GENERIC_SOCK`](../sig/GENERIC_SOCK.md)

---

<sub>Generated by runedoc from lib/basis/sig\_inet\_sock.sml; do not edit.</sub>
