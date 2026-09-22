# signature INET6_SOCK

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **INET6_SOCK**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 20 of 20 entries documented |
| Tests | 29 checks of 18 entries |
| Source | [lib/basis/inet6sock\_sig.sml](../../../../lib/basis/inet6sock_sig.sml) |

## Synopsis

```sml
signature INET6_SOCK
structure INet6Sock : INET6_SOCK  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `INet6Sock` |  | [lib/basis/inet6sock.sml](../../../../lib/basis/inet6sock.sml) |

Sockets of the Internet protocol version 6, as [`INET_SOCK`](../sig/INET_SOCK.md) describes them
for version 4.

The specification knows nothing of IPv6: it was written when the protocol
was new, and its [`NetHostDB`](../sig/NET_HOST_DB.md) is an IPv4 database whose [`toString`](#val-tostring) is
defined to give the four dotted numbers. So this signature is Rune's own,
and a program that uses it is not portable. It is as close to [`INET_SOCK`](../sig/INET_SOCK.md)
as it can be -- the same names, in the same order, for the same things --
so that the two read alike.

An address of this family is an [`in6_addr`](#type-in6_addr) and a port. [`toString`](#val-tostring) and
[`fromString`](#val-fromstring) write and read the text of `inet_ntop` and `inet_pton` \--
eight groups of up to four hexadecimal digits, at most one `::` for the
longest run of zeros, a dotted quad in place of the last two groups, and
no scope after `%` \-- and they do it here rather than asking the system,
as [`NetHostDB`](../sig/NET_HOST_DB.md) does for IPv4, so that a host compiling this library can
read and write addresses although it has no sockets. On 300 addresses
drawn at random the text is the same as `inet_ntop`'s, character for
character. The addresses of a host are not looked up here; [`NetHostDB`](../sig/NET_HOST_DB.md)
answers for IPv4 only.

> **Deviation** `INET6_SOCK/not-in-the-specification`. This signature is not in
> the specification, which has no IPv6 at all: it was written before the
> protocol, its [`NetHostDB`](../sig/NET_HOST_DB.md) is defined to give the four dotted numbers of
> IPv4, and it names no structure for anything else. A program that uses
> this one does not port. What the specification does allow is the family:
> AF.list "returns a list of all the available address families", so
> [`Socket.AF`](../sig/SOCKET.md#str-af) knowing `INET6` is not a departure and this signature is.

## Interface

<pre>
signature INET6_SOCK =
sig
  type <a href="#type-inet6">inet6</a>

  type 'sock_type <a href="#type-sock">sock</a> = (inet6, 'sock_type) Socket.sock

  type 'mode <a href="#type-stream_sock">stream_sock</a> = 'mode Socket.stream sock

  type <a href="#type-dgram_sock">dgram_sock</a> = Socket.dgram sock

  type <a href="#type-sock_addr">sock_addr</a> = inet6 Socket.sock_addr

  eqtype <a href="#type-in6_addr">in6_addr</a>

  val <a href="#val-tostring">toString</a> : in6_addr -&gt; string

  val <a href="#val-fromstring">fromString</a> : string -&gt; in6_addr option

  val <a href="#val-inet6af">inet6AF</a> : Socket.AF.addr_family

  val <a href="#val-toaddr">toAddr</a> : in6_addr * int -&gt; sock_addr

  val <a href="#val-any">any</a> : int -&gt; sock_addr

  val <a href="#val-fromaddr">fromAddr</a> : sock_addr -&gt; in6_addr * int

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

### <a name="type-inet6"></a>`inet6`

```sml
type inet6
```

The type that says a socket or an address is of this family.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `is-the-family-of-its-sockets`

</details>

### <a name="type-sock"></a>`sock`

```sml
type 'sock_type sock = (inet6, 'sock_type) Socket.sock
```

A socket of this family, carrying what it is.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `is-a-Socket.sock`

</details>

### <a name="type-stream_sock"></a>`stream_sock`

```sml
type 'mode stream_sock = 'mode Socket.stream sock
```

A stream socket of this family, passive or active.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `is-a-stream`

</details>

### <a name="type-dgram_sock"></a>`dgram_sock`

```sml
type dgram_sock = Socket.dgram sock
```

A datagram socket of this family.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `is-a-datagram`

</details>

### <a name="type-sock_addr"></a>`sock_addr`

```sml
type sock_addr = inet6 Socket.sock_addr
```

An address of this family.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `is-a-Socket.sock_addr`

</details>

### <a name="type-in6_addr"></a>`in6_addr`

```sml
eqtype in6_addr
```

The address of a host, 128 bits.

Two are equal when they are the same address, whatever text each was
read from: `fromString "::1"` and `fromString "0:0:0:0:0:0:0:1"` are
one address.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `admits-equality`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : in6_addr -> string
```

`toString a` is the text of `a` as `inet_ntop` writes it.

**Example** `toString (valOf (fromString "0:0:0:0:0:0:0:1")) = "::1"`

<details><summary>Tests (4)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `loopback` &middot; `canonical` &middot; `unspecified` &middot; `full`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> in6_addr option
```

`fromString s` is the address that the whole of `s` names, or `NONE`.

The forms are those of `inet_pton`, so `"::1"`, `"fe80::1"` and
`"::ffff:127.0.0.1"` are addresses and `"127.0.0.1"` is not.

**Example** `fromString "not an address" = NONE`

<details><summary>Tests (6)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `same-address` &middot; `other-address` &middot; `not-an-IPv4-address` &middot; `mapped-IPv4` &middot; `not-an-address` &middot; `trailing-text`

</details>

### <a name="val-inet6af"></a>`inet6AF`

```sml
val inet6AF : Socket.AF.addr_family
```

The address family of these sockets, `Socket.AF.fromString "INET6"`.

<details><summary>Tests (3)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `named-INET6` &middot; `fromString-INET6` &middot; `in-the-list`

</details>

### <a name="val-toaddr"></a>`toAddr`

```sml
val toAddr : in6_addr * int -> sock_addr
```

`toAddr (a, port)` is the address of that host and port.

**Raises** `SysErr` if the system will not make it.

<details><summary>Tests (2)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `round-trip` &middot; `family-is-INET6`

</details>

### <a name="val-any"></a>`any`

```sml
val any : int -> sock_addr
```

`any port` is the address of that port on every interface of the machine.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `no-host`

</details>

### <a name="val-fromaddr"></a>`fromAddr`

```sml
val fromAddr : sock_addr -> in6_addr * int
```

`fromAddr addr` is the host and the port of `addr`.

**Law** `fromAddr (toAddr (a, p)) = (a, p)`

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `host-and-port`

</details>

### <a name="str-udp"></a>`UDP`

Datagram sockets of this family.

#### <a name="val-udp.socket"></a>`socket`

```sml
val socket : unit -> dgram_sock
```

`socket ()` is a new datagram socket.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `datagram-to-itself`

</details>

#### <a name="val-udp.socket-prime"></a>`socket'`

```sml
val socket' : int -> dgram_sock
```

`socket' protocol` is the same for a protocol of the system's numbering.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `protocol-zero`

</details>

### <a name="str-tcp"></a>`TCP`

Stream sockets of this family.

#### <a name="val-tcp.socket"></a>`socket`

```sml
val socket : unit -> 'mode stream_sock
```

`socket ()` is a new stream socket.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `stream-both-ways`

</details>

#### <a name="val-tcp.socket-prime"></a>`socket'`

```sml
val socket' : int -> 'mode stream_sock
```

`socket' protocol` is the same for a protocol of the system's numbering.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `protocol-zero`

</details>

#### <a name="val-tcp.getnodelay"></a>`getNODELAY`

```sml
val getNODELAY : 'mode stream_sock -> bool
```

`getNODELAY sock` is whether small writes go out at once (`TCP_NODELAY`).

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `off-by-default`

</details>

#### <a name="val-tcp.setnodelay"></a>`setNODELAY`

```sml
val setNODELAY : 'mode stream_sock * bool -> unit
```

`setNODELAY (sock, b)` sets it.

<details><summary>Tests (1)</summary>

For `INet6Sock`, in [tests/basis/inet6sock.sml](../../../../tests/basis/inet6sock.sml): `takes`

</details>

## See also

[`INET_SOCK`](../sig/INET_SOCK.md), [`SOCKET`](../sig/SOCKET.md), [`NET_HOST_DB`](../sig/NET_HOST_DB.md), [`MONO_VECTOR_EQ`](../sig/MONO_VECTOR_EQ.md)

---

<sub>Generated by runedoc from lib/basis/inet6sock\_sig.sml; do not edit.</sub>
