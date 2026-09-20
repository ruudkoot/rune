# signature UNIX_SOCK

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **UNIX_SOCK**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | 18 checks of 7 entries |
| Source | [lib/basis/sig\_unix\_sock.sml](../../../../lib/basis/sig_unix_sock.sml) |

## Synopsis

```sml
signature UNIX_SOCK
structure UnixSock : UNIX_SOCK  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `UnixSock` |  | [lib/basis/inetsock.sml](../../../../lib/basis/inetsock.sml) |

Sockets of the Unix family: an address is a path in the file system, and
the connection never leaves the machine.

This is [`SOCKET`](../sig/SOCKET.md) with the address family fixed. An address is made from a
path with [`toAddr`](#val-toaddr); binding to it creates that entry in the file system,
and removing the entry is the program's own business.

[`Strm`](#str-strm) and [`DGrm`](#str-dgrm) also offer `socketPair`, which makes two sockets already
connected to each other -- the usual way to give a child process a channel
to its parent.

## Interface

<pre>
signature UNIX_SOCK =
sig
  type <a href="#type-unix">unix</a>

  type 'sock_type <a href="#type-sock">sock</a> = (unix, 'sock_type) Socket.sock

  type 'mode <a href="#type-stream_sock">stream_sock</a> = 'mode Socket.stream sock

  type <a href="#type-dgram_sock">dgram_sock</a> = Socket.dgram sock

  type <a href="#type-sock_addr">sock_addr</a> = unix Socket.sock_addr

  val <a href="#val-unixaf">unixAF</a> : Socket.AF.addr_family

  val <a href="#val-toaddr">toAddr</a> : string -&gt; sock_addr

  val <a href="#val-fromaddr">fromAddr</a> : sock_addr -&gt; string

  structure <a href="#str-strm">Strm</a> :
  sig
    val <a href="#val-strm.socket">socket</a> : unit -&gt; 'mode stream_sock

    val <a href="#val-strm.socketpair">socketPair</a> : unit -&gt; 'mode stream_sock * 'mode stream_sock
  end

  structure <a href="#str-dgrm">DGrm</a> :
  sig
    val <a href="#val-dgrm.socket">socket</a> : unit -&gt; dgram_sock

    val <a href="#val-dgrm.socketpair">socketPair</a> : unit -&gt; dgram_sock * dgram_sock
  end
end
</pre>

### <a name="type-unix"></a>`unix`

```sml
type unix
```

The type that marks the Unix family, and holds nothing.

### <a name="type-sock"></a>`sock`

```sml
type 'sock_type sock = (unix, 'sock_type) Socket.sock
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
type sock_addr = unix Socket.sock_addr
```

The type of an address of this family: a path.

### <a name="val-unixaf"></a>`unixAF`

```sml
val unixAF : Socket.AF.addr_family
```

The address family of the Unix sockets, for [`Socket.familyOfAddr`](../sig/SOCKET.md#val-familyofaddr) to give back.

<details><summary>Tests (2)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `named-UNIX` &middot; `fromString-UNIX`

</details>

### <a name="val-toaddr"></a>`toAddr`

```sml
val toAddr : string -> sock_addr
```

`toAddr p` is the address of the socket at the path `p`.

<details><summary>Tests (3)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `fromAddr` &middot; `not-checked` &middot; `bind-creates-the-file`

</details>

### <a name="val-fromaddr"></a>`fromAddr`

```sml
val fromAddr : sock_addr -> string
```

`fromAddr a` is the path that `a` names.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the Unix-domain address recvVecFromNB gives is garbled: UnixSock.fromAddr of it is not the sender's path

</details>

<details><summary>Tests (2)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `bound-socket` &middot; `sender-of-a-message`

</details>

### <a name="str-strm"></a>`Strm`

Sockets of this family that carry a stream.

#### <a name="val-strm.socket"></a>`socket`

```sml
val socket : unit -> 'mode stream_sock
```

`socket ()` is a new stream socket of this family.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

<details><summary>Tests (2)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `stream` &middot; `listen-connect-accept`

</details>

#### <a name="val-strm.socketpair"></a>`socketPair`

```sml
val socketPair : unit -> 'mode stream_sock * 'mode stream_sock
```

`socketPair ()` is two stream sockets already connected to each other.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no pair can be made.

<details><summary>Tests (4)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `bidirectional` &middot; `stream` &middot; `two-sockets` &middot; `connected-to-each-other`

</details>

### <a name="str-dgrm"></a>`DGrm`

Sockets of this family that send messages.

#### <a name="val-dgrm.socket"></a>`socket`

```sml
val socket : unit -> dgram_sock
```

`socket ()` is a new message socket of this family.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no socket can be made.

<details><summary>Tests (2)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `dgram` &middot; `to-a-name`

</details>

#### <a name="val-dgrm.socketpair"></a>`socketPair`

```sml
val socketPair : unit -> dgram_sock * dgram_sock
```

`socketPair ()` is two message sockets already connected to each other.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no pair can be made.

<details><summary>Tests (3)</summary>

For `UnixSock`, in [tests/basis/inetsock\_unix.sml](../../../../tests/basis/inetsock_unix.sml): `dgram` &middot; `connected-to-each-other` &middot; `named-peer`

</details>

## See also

[`SOCKET`](../sig/SOCKET.md), [`INET_SOCK`](../sig/INET_SOCK.md), [`GENERIC_SOCK`](../sig/GENERIC_SOCK.md), [`UNIX`](../sig/UNIX.md)

---

<sub>Generated by runedoc from lib/basis/sig\_unix\_sock.sml; do not edit.</sub>
