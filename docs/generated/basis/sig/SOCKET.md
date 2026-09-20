# signature SOCKET

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **SOCKET**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 93 of 93 entries documented |
| Tests | 298 checks of 78 entries |
| Source | [lib/basis/sig\_socket.sml](../../../../lib/basis/sig_socket.sml) |

## Synopsis

```sml
signature SOCKET
structure Socket : SOCKET  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Socket` |  | [lib/basis/socket.sml](../../../../lib/basis/socket.sml) |

Sockets: connections between processes, on one machine or across a
network.

A socket carries two type variables that hold nothing but say what may be
done with it. The first is its address family, so that an address of one
family cannot be given to a socket of another; the second is what kind of
socket it is -- [`dgram`](#type-dgram) for one that sends messages, `passive stream` for
one that is waiting for connections, `active stream` for one that is
connected. [`listen`](#val-listen) needs a passive socket, [`accept`](#val-accept) turns one into an
active one, and the send and receive functions need an active one. A
program that gets the family or the mode wrong does not compile.

[`INET_SOCK`](../sig/INET_SOCK.md) and [`UNIX_SOCK`](../sig/UNIX_SOCK.md) make the sockets of the two families;
[`GENERIC_SOCK`](../sig/GENERIC_SOCK.md) makes one of any family.

The operations come in families of their own. [`sendVec`](#val-sendvec) and [`sendArr`](#val-sendarr)
differ in where the bytes come from, the primed forms take flags, and the
ones whose names end in `NB` never wait and answer `NONE` or `false`
instead. [`Ctl`](#str-ctl) reads and sets the options of a socket.

> **Erratum** `SOCKET/recvVecFrom-type-variable`. The page gives
> [`recvVecFrom`](#val-recvvecfrom) and the three like it the result `Word8Vector.vector * 'sock_type sock_addr`, a type variable that occurs nowhere else in the
> type. That is a slip for `'af`: the address a message came from is in the
> family of the socket, as it is for [`recvArrFrom`](#val-recvarrfrom), and as the description
> says. It is written `'af` here.

> **Limitation** `SOCKET/no-ipv6`. There is no IPv6: [`INetSock`](../sig/INET_SOCK.md) is IPv4 only,
> and an `in_addr` is the dotted text of an IPv4 address.

> **Implementation** `Socket.sock/is-a-descriptor`. A socket is the system's
> descriptor and a [`sock_addr`](#type-sock_addr) the bytes of a `sockaddr`; the type variables
> are phantoms and hold nothing. The `NB` forms put the descriptor into
> non-blocking mode for the call and back afterwards. Sending to a peer that
> has gone fails with the condition `pipe` rather than raising the signal of
> that name.

## Interface

<pre>
signature SOCKET =
sig
  type ('af, 'sock_type) <a href="#type-sock">sock</a>

  type 'af <a href="#type-sock_addr">sock_addr</a>

  type <a href="#type-dgram">dgram</a>

  type 'mode <a href="#type-stream">stream</a>

  type <a href="#type-passive">passive</a>

  type <a href="#type-active">active</a>

  structure <a href="#str-af">AF</a> :
  sig
    type <a href="#type-af.addr_family">addr_family</a> = NetHostDB.addr_family

    val <a href="#val-af.list">list</a> : unit -&gt; (string * addr_family) list

    val <a href="#val-af.tostring">toString</a> : addr_family -&gt; string

    val <a href="#val-af.fromstring">fromString</a> : string -&gt; addr_family option
  end

  structure <a href="#str-sock">SOCK</a> :
  sig
    eqtype <a href="#type-sock.sock_type">sock_type</a>

    val <a href="#val-sock.stream">stream</a> : sock_type

    val <a href="#val-sock.dgram">dgram</a> : sock_type

    val <a href="#val-sock.list">list</a> : unit -&gt; (string * sock_type) list

    val <a href="#val-sock.tostring">toString</a> : sock_type -&gt; string

    val <a href="#val-sock.fromstring">fromString</a> : string -&gt; sock_type option
  end

  structure <a href="#str-ctl">Ctl</a> :
  sig
    val <a href="#val-ctl.getdebug">getDEBUG</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setdebug">setDEBUG</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getreuseaddr">getREUSEADDR</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setreuseaddr">setREUSEADDR</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getkeepalive">getKEEPALIVE</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setkeepalive">setKEEPALIVE</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getdontroute">getDONTROUTE</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setdontroute">setDONTROUTE</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getlinger">getLINGER</a> : ('af, 'sock_type) sock -&gt; Time.time option

    val <a href="#val-ctl.setlinger">setLINGER</a> : ('af, 'sock_type) sock * Time.time option -&gt; unit

    val <a href="#val-ctl.getbroadcast">getBROADCAST</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setbroadcast">setBROADCAST</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getoobinline">getOOBINLINE</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.setoobinline">setOOBINLINE</a> : ('af, 'sock_type) sock * bool -&gt; unit

    val <a href="#val-ctl.getsndbuf">getSNDBUF</a> : ('af, 'sock_type) sock -&gt; int

    val <a href="#val-ctl.setsndbuf">setSNDBUF</a> : ('af, 'sock_type) sock * int -&gt; unit

    val <a href="#val-ctl.getrcvbuf">getRCVBUF</a> : ('af, 'sock_type) sock -&gt; int

    val <a href="#val-ctl.setrcvbuf">setRCVBUF</a> : ('af, 'sock_type) sock * int -&gt; unit

    val <a href="#val-ctl.gettype">getTYPE</a> : ('af, 'sock_type) sock -&gt; SOCK.sock_type

    val <a href="#val-ctl.geterror">getERROR</a> : ('af, 'sock_type) sock -&gt; bool

    val <a href="#val-ctl.getpeername">getPeerName</a> : ('af, 'sock_type) sock -&gt; 'af sock_addr

    val <a href="#val-ctl.getsockname">getSockName</a> : ('af, 'sock_type) sock -&gt; 'af sock_addr

    val <a href="#val-ctl.getnread">getNREAD</a> : ('af, 'sock_type) sock -&gt; int

    val <a href="#val-ctl.getatmark">getATMARK</a> : ('af, active stream) sock -&gt; bool
  end

  val <a href="#val-sameaddr">sameAddr</a> : 'af sock_addr * 'af sock_addr -&gt; bool

  val <a href="#val-familyofaddr">familyOfAddr</a> : 'af sock_addr -&gt; AF.addr_family

  val <a href="#val-bind">bind</a> : ('af, 'sock_type) sock * 'af sock_addr -&gt; unit

  val <a href="#val-listen">listen</a> : ('af, passive stream) sock * int -&gt; unit

  val <a href="#val-accept">accept</a> : ('af, passive stream) sock -&gt; ('af, active stream) sock * 'af sock_addr

  val <a href="#val-acceptnb">acceptNB</a> : ('af, passive stream) sock -&gt; (('af, active stream) sock * 'af sock_addr) option

  val <a href="#val-connect">connect</a> : ('af, 'sock_type) sock * 'af sock_addr -&gt; unit

  val <a href="#val-connectnb">connectNB</a> : ('af, 'sock_type) sock * 'af sock_addr -&gt; bool

  val <a href="#val-close">close</a> : ('af, 'sock_type) sock -&gt; unit

  datatype <a href="#type-shutdown_mode">shutdown_mode</a>
    = <a href="#con-no_recvs">NO_RECVS</a>
    | <a href="#con-no_sends">NO_SENDS</a>
    | <a href="#con-no_recvs_or_sends">NO_RECVS_OR_SENDS</a>

  val <a href="#val-shutdown">shutdown</a> : ('af, 'mode stream) sock * shutdown_mode -&gt; unit

  type <a href="#type-sock_desc">sock_desc</a>

  val <a href="#val-sockdesc">sockDesc</a> : ('af, 'sock_type) sock -&gt; sock_desc

  val <a href="#val-samedesc">sameDesc</a> : sock_desc * sock_desc -&gt; bool

  val <a href="#val-select">select</a> : {<a href="#fld-select.rds">rds</a> : sock_desc list, <a href="#fld-select.wrs">wrs</a> : sock_desc list, <a href="#fld-select.exs">exs</a> : sock_desc list, <a href="#fld-select.timeout">timeout</a> : Time.time option}
               -&gt; {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list}

  val <a href="#val-iodesc">ioDesc</a> : ('af, 'sock_type) sock -&gt; OS.IO.iodesc

  type <a href="#type-out_flags">out_flags</a> = {<a href="#fld-out_flags.don-primet_route">don't_route</a> : bool, <a href="#fld-out_flags.oob">oob</a> : bool}

  type <a href="#type-in_flags">in_flags</a> = {<a href="#fld-in_flags.peek">peek</a> : bool, <a href="#fld-in_flags.oob">oob</a> : bool}

  val <a href="#val-sendvec">sendVec</a> : ('af, active stream) sock * Word8VectorSlice.slice -&gt; int

  val <a href="#val-sendarr">sendArr</a> : ('af, active stream) sock * Word8ArraySlice.slice -&gt; int

  val <a href="#val-sendvec-prime">sendVec'</a> : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -&gt; int

  val <a href="#val-sendarr-prime">sendArr'</a> : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -&gt; int

  val <a href="#val-sendvecnb">sendVecNB</a> : ('af, active stream) sock * Word8VectorSlice.slice -&gt; int option

  val <a href="#val-sendvecnb-prime">sendVecNB'</a> : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -&gt; int option

  val <a href="#val-sendarrnb">sendArrNB</a> : ('af, active stream) sock * Word8ArraySlice.slice -&gt; int option

  val <a href="#val-sendarrnb-prime">sendArrNB'</a> : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -&gt; int option

  val <a href="#val-recvvec">recvVec</a> : ('af, active stream) sock * int -&gt; Word8Vector.vector

  val <a href="#val-recvvec-prime">recvVec'</a> : ('af, active stream) sock * int * in_flags -&gt; Word8Vector.vector

  val <a href="#val-recvarr">recvArr</a> : ('af, active stream) sock * Word8ArraySlice.slice -&gt; int

  val <a href="#val-recvarr-prime">recvArr'</a> : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -&gt; int

  val <a href="#val-recvvecnb">recvVecNB</a> : ('af, active stream) sock * int -&gt; Word8Vector.vector option

  val <a href="#val-recvvecnb-prime">recvVecNB'</a> : ('af, active stream) sock * int * in_flags -&gt; Word8Vector.vector option

  val <a href="#val-recvarrnb">recvArrNB</a> : ('af, active stream) sock * Word8ArraySlice.slice -&gt; int option

  val <a href="#val-recvarrnb-prime">recvArrNB'</a> : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -&gt; int option

  val <a href="#val-sendvecto">sendVecTo</a> : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -&gt; unit

  val <a href="#val-sendarrto">sendArrTo</a> : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -&gt; unit

  val <a href="#val-sendvecto-prime">sendVecTo'</a> : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -&gt; unit

  val <a href="#val-sendarrto-prime">sendArrTo'</a> : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -&gt; unit

  val <a href="#val-sendvectonb">sendVecToNB</a> : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -&gt; bool

  val <a href="#val-sendvectonb-prime">sendVecToNB'</a> : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -&gt; bool

  val <a href="#val-sendarrtonb">sendArrToNB</a> : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -&gt; bool

  val <a href="#val-sendarrtonb-prime">sendArrToNB'</a> : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -&gt; bool

  val <a href="#val-recvvecfrom">recvVecFrom</a> : ('af, dgram) sock * int -&gt; Word8Vector.vector * 'af sock_addr

  val <a href="#val-recvvecfrom-prime">recvVecFrom'</a> : ('af, dgram) sock * int * in_flags -&gt; Word8Vector.vector * 'af sock_addr

  val <a href="#val-recvarrfrom">recvArrFrom</a> : ('af, dgram) sock * Word8ArraySlice.slice -&gt; int * 'af sock_addr

  val <a href="#val-recvarrfrom-prime">recvArrFrom'</a> : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -&gt; int * 'af sock_addr

  val <a href="#val-recvvecfromnb">recvVecFromNB</a> : ('af, dgram) sock * int -&gt; (Word8Vector.vector * 'af sock_addr) option

  val <a href="#val-recvvecfromnb-prime">recvVecFromNB'</a> : ('af, dgram) sock * int * in_flags -&gt; (Word8Vector.vector * 'af sock_addr) option

  val <a href="#val-recvarrfromnb">recvArrFromNB</a> : ('af, dgram) sock * Word8ArraySlice.slice -&gt; (int * 'af sock_addr) option

  val <a href="#val-recvarrfromnb-prime">recvArrFromNB'</a> : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -&gt; (int * 'af sock_addr) option
end
</pre>

### <a name="type-sock"></a>`sock`

```sml
type ('af, 'sock_type) sock
```

The type of a socket: its address family, then what kind of socket it is.

### <a name="type-sock_addr"></a>`sock_addr`

```sml
type 'af sock_addr
```

The type of an address in the family `'af`.

### <a name="type-dgram"></a>`dgram`

```sml
type dgram
```

The kind of a socket that sends messages, each to an address of its own.

### <a name="type-stream"></a>`stream`

```sml
type 'mode stream
```

The kind of a socket that carries a stream of bytes; `'mode` says whether it is listening or connected.

### <a name="type-passive"></a>`passive`

```sml
type passive
```

The mode of a stream socket that is waiting for connections.

### <a name="type-active"></a>`active`

```sml
type active
```

The mode of a stream socket that is connected.

### <a name="str-af"></a>`AF`

The address families the system knows.

#### <a name="type-af.addr_family"></a>`addr_family`

```sml
type addr_family = NetHostDB.addr_family
```

The type of an address family, the one of [`NetHostDB`](../sig/NET_HOST_DB.md).

#### <a name="val-af.list"></a>`list`

```sml
val list : unit -> (string * addr_family) list
```

`list ()` is the families this system has, each with its name.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; AF.list names AF\_UNIX's value also "LOCAL" (5.9.2: and "FILE"), which toString calls "UNIX"

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `has-INET` &middot; `has-UNIX` &middot; `names-are-toString` &middot; `inet-is-not-unix`

</details>

#### <a name="val-af.tostring"></a>`toString`

```sml
val toString : addr_family -> string
```

`toString af` is the name of `af`.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `inet` &middot; `unix`

</details>

#### <a name="val-af.fromstring"></a>`fromString`

```sml
val fromString : string -> addr_family option
```

`fromString s` is `SOME` of the family called `s`, or `NONE`.

> **Reading** `Socket.AF.fromString/without-the-prefix`. A name is the C
> constant without its leading `"AF_"`: `"INET"` and `"UNIX"`, so
> `"AF_INET"` gives `NONE`.

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `inverts-list` &middot; `INET` &middot; `UNIX` &middot; `unknown` &middot; `empty` &middot; `with-AF_-prefix`

</details>

### <a name="str-sock"></a>`SOCK`

The kinds of socket the system knows.

#### <a name="type-sock.sock_type"></a>`sock_type`

```sml
eqtype sock_type
```

The type of a kind of socket, as the system names it.

#### <a name="val-sock.stream"></a>`stream`

```sml
val stream : sock_type
```

A stream of bytes that arrives in order and whole.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `is-not-dgram` &middot; `type-of-a-TCP-socket`

</details>

#### <a name="val-sock.dgram"></a>`dgram`

```sml
val dgram : sock_type
```

Separate messages, which may be lost or arrive out of order.

<details><summary>Tests (1)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `type-of-a-UDP-socket`

</details>

#### <a name="val-sock.list"></a>`list`

```sml
val list : unit -> (string * sock_type) list
```

`list ()` is the kinds this system has, each with its name.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `has-STREAM` &middot; `has-DGRAM` &middot; `names-are-toString`

</details>

#### <a name="val-sock.tostring"></a>`toString`

```sml
val toString : sock_type -> string
```

`toString st` is the name of `st`.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `stream` &middot; `dgram`

</details>

#### <a name="val-sock.fromstring"></a>`fromString`

```sml
val fromString : string -> sock_type option
```

`fromString s` is `SOME` of the kind called `s`, or `NONE`.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `inverts-list` &middot; `STREAM` &middot; `DGRAM` &middot; `unknown` &middot; `with-SOCK_-prefix`

</details>

### <a name="str-ctl"></a>`Ctl`

The options of a socket, read and set.

> **Implementation** `Socket.Ctl/defaults-are-the-systems`. The values a new
> socket starts with are those of the C socket interface, which has every
> flag here off. The suite sets `DEBUG` to `false` only, since turning it
> on needs privileges.

#### <a name="val-ctl.getdebug"></a>`getDEBUG`

```sml
val getDEBUG : ('af, 'sock_type) sock -> bool
```

`getDEBUG sock` is `true` when the system is recording what the socket does.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setdebug"></a>`setDEBUG`

```sml
val setDEBUG : ('af, 'sock_type) sock * bool -> unit
```

`setDEBUG (sock, b)` asks the system to record what the socket does, or to stop.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `off` &middot; `closed`

</details>

#### <a name="val-ctl.getreuseaddr"></a>`getREUSEADDR`

```sml
val getREUSEADDR : ('af, 'sock_type) sock -> bool
```

`getREUSEADDR sock` is `true` when the socket may bind an address that was lately in use.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setreuseaddr"></a>`setREUSEADDR`

```sml
val setREUSEADDR : ('af, 'sock_type) sock * bool -> unit
```

`setREUSEADDR (sock, b)` allows or forbids binding an address that was lately in use.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `on` &middot; `off-again` &middot; `closed`

</details>

#### <a name="val-ctl.getkeepalive"></a>`getKEEPALIVE`

```sml
val getKEEPALIVE : ('af, 'sock_type) sock -> bool
```

`getKEEPALIVE sock` is `true` when the connection is checked while it is idle.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setkeepalive"></a>`setKEEPALIVE`

```sml
val setKEEPALIVE : ('af, 'sock_type) sock * bool -> unit
```

`setKEEPALIVE (sock, b)` asks for the connection to be checked while it is idle, or not.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `on` &middot; `off-again` &middot; `closed`

</details>

#### <a name="val-ctl.getdontroute"></a>`getDONTROUTE`

```sml
val getDONTROUTE : ('af, 'sock_type) sock -> bool
```

`getDONTROUTE sock` is `true` when messages go to the local network only.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setdontroute"></a>`setDONTROUTE`

```sml
val setDONTROUTE : ('af, 'sock_type) sock * bool -> unit
```

`setDONTROUTE (sock, b)` keeps messages on the local network, or lets them be routed.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `on` &middot; `off-again` &middot; `closed`

</details>

#### <a name="val-ctl.getlinger"></a>`getLINGER`

```sml
val getLINGER : ('af, 'sock_type) sock -> Time.time option
```

`getLINGER sock` is `SOME t` when closing waits up to `t` for what was sent, or `NONE` when it does not wait.

> **Implementation** `Socket.Ctl.getLINGER/whole-seconds`. The system keeps
> the time in a `struct linger`, in whole seconds.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setlinger"></a>`setLINGER`

```sml
val setLINGER : ('af, 'sock_type) sock * Time.time option -> unit
```

`setLINGER (sock, SOME t)` makes closing wait up to `t`; `NONE` makes it not wait.

**Raises** [`Time`](../sig/TIME.md) if `t` is negative or is 2^31 seconds or more, which
the system's `int` cannot hold.

<details><summary>Other implementations (4)</summary>

- **MLton, SML/NJ** &mdash; setLINGER takes a negative time without raising Time
- **MLton, SML/NJ (32-bit)** &mdash; setLINGER raises Overflow, not Time, for a time too large for the system
- **SML/NJ 110.99.9 (64-bit)** &mdash; setLINGER takes a time too large for the system without raising Time
- **Poly/ML** &mdash; setLINGER raises SysErr ("Invalid time"), not Time, for a negative time

</details>

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `some` &middot; `zero` &middot; `none-again` &middot; `negative` (raises) &middot; `too-large` (raises) &middot; `closed`

</details>

#### <a name="val-ctl.getbroadcast"></a>`getBROADCAST`

```sml
val getBROADCAST : ('af, 'sock_type) sock -> bool
```

`getBROADCAST sock` is `true` when the socket may send to a broadcast address.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setbroadcast"></a>`setBROADCAST`

```sml
val setBROADCAST : ('af, 'sock_type) sock * bool -> unit
```

`setBROADCAST (sock, b)` allows or forbids sending to a broadcast address.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `on` &middot; `off-again` &middot; `closed`

</details>

#### <a name="val-ctl.getoobinline"></a>`getOOBINLINE`

```sml
val getOOBINLINE : ('af, 'sock_type) sock -> bool
```

`getOOBINLINE sock` is `true` when urgent data arrive in the ordinary stream.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `default` &middot; `closed`

</details>

#### <a name="val-ctl.setoobinline"></a>`setOOBINLINE`

```sml
val setOOBINLINE : ('af, 'sock_type) sock * bool -> unit
```

`setOOBINLINE (sock, b)` puts urgent data into the ordinary stream, or keeps them apart.

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `on` &middot; `off-again` &middot; `urgent-byte-in-the-stream` &middot; `closed`

</details>

#### <a name="val-ctl.getsndbuf"></a>`getSNDBUF`

```sml
val getSNDBUF : ('af, 'sock_type) sock -> int
```

`getSNDBUF sock` is the size in bytes of the room the system keeps for what is sent.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `positive` &middot; `closed`

</details>

#### <a name="val-ctl.setsndbuf"></a>`setSNDBUF`

```sml
val setSNDBUF : ('af, 'sock_type) sock * int -> unit
```

`setSNDBUF (sock, n)` asks for `n` bytes of room for what is sent.

> **Implementation** `Socket.Ctl.setSNDBUF/at-least`. The system may give
> more room than was asked for -- Linux doubles it -- so the size read
> back is only bound to be at least `n`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `at-least-the-size` &middot; `larger` &middot; `closed`

</details>

#### <a name="val-ctl.getrcvbuf"></a>`getRCVBUF`

```sml
val getRCVBUF : ('af, 'sock_type) sock -> int
```

`getRCVBUF sock` is the size in bytes of the room the system keeps for what arrives.

<details><summary>Tests (2)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `positive` &middot; `closed`

</details>

#### <a name="val-ctl.setrcvbuf"></a>`setRCVBUF`

```sml
val setRCVBUF : ('af, 'sock_type) sock * int -> unit
```

`setRCVBUF (sock, n)` asks for `n` bytes of room for what arrives.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `at-least-the-size` &middot; `larger` &middot; `closed`

</details>

#### <a name="val-ctl.gettype"></a>`getTYPE`

```sml
val getTYPE : ('af, 'sock_type) sock -> SOCK.sock_type
```

`getTYPE sock` is the kind of socket that `sock` is.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `tcp` &middot; `udp` &middot; `unix-stream` &middot; `unix-dgram` &middot; `closed`

</details>

#### <a name="val-ctl.geterror"></a>`getERROR`

```sml
val getERROR : ('af, 'sock_type) sock -> bool
```

`getERROR sock` is `true` when the socket has an error waiting, which reading it clears.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; getERROR of a closed socket answers instead of raising SysErr

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `fresh` &middot; `port-unreachable` &middot; `closed`

</details>

#### <a name="val-ctl.getpeername"></a>`getPeerName`

```sml
val getPeerName : ('af, 'sock_type) sock -> 'af sock_addr
```

`getPeerName sock` is the address of the other end.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not connected.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `session-is-peer-of-client` &middot; `loopback` &middot; `dgram-connected` &middot; `unix-pair` &middot; `closed`

</details>

#### <a name="val-ctl.getsockname"></a>`getSockName`

```sml
val getSockName : ('af, 'sock_type) sock -> 'af sock_addr
```

`getSockName sock` is the address the socket is bound to.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it is not bound.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `bound` &middot; `client-is-peer-of-session` &middot; `closed`

</details>

#### <a name="val-ctl.getnread"></a>`getNREAD`

```sml
val getNREAD : ('af, 'sock_type) sock -> int
```

`getNREAD sock` is how many bytes can be read from the socket without waiting.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; getNREAD answers \~1 whatever there is to read

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `nothing` &middot; `five-bytes` &middot; `after-reading-two` &middot; `closed`

</details>

#### <a name="val-ctl.getatmark"></a>`getATMARK`

```sml
val getATMARK : ('af, active stream) sock -> bool
```

`getATMARK sock` is `true` when the next byte to be read is the urgent one.

> **Implementation** `Socket.Ctl.getATMARK/the-last-byte-is-urgent`. The
> mark falls where the host's TCP puts it: sending `"abc"` out of band
> puts it after `"ab"`, the last byte being the urgent one.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; getATMARK answers true whether or not the read pointer is at the out-of-band mark
- **SML/NJ** &mdash; sendVec' sends oob as don't\_route, so that there is no urgent byte and no mark

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_ctl.sml](../../../../tests/basis/socket_ctl.sml): `before-and-at-the-mark` &middot; `no-urgent-data` &middot; `closed`

</details>

### <a name="val-sameaddr"></a>`sameAddr`

```sml
val sameAddr : 'af sock_addr * 'af sock_addr -> bool
```

`sameAddr (a, b)` is `true` when the two addresses are the same one.

<details><summary>Tests (7)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `equal-addresses` &middot; `other-port` &middot; `other-host` &middot; `any-is-not-loopback` &middot; `sockname-and-its-parts` &middot; `unix-same-path` &middot; `unix-other-path`

</details>

### <a name="val-familyofaddr"></a>`familyOfAddr`

```sml
val familyOfAddr : 'af sock_addr -> AF.addr_family
```

`familyOfAddr a` is the address family that `a` belongs to.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; familyOfAddr gives a family that is neither INetSock.inetAF nor UnixSock.unixAF (AF.toString says "\<UNKNOWN\>")

</details>

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `inet-toAddr` &middot; `inet-any` &middot; `inet-sockname` &middot; `unix-toAddr` &middot; `unix-sockname`

</details>

### <a name="val-bind"></a>`bind`

```sml
val bind : ('af, 'sock_type) sock * 'af sock_addr -> unit
```

`bind (sock, a)` gives the socket the address `a`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the address is in use or may not be taken.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `port-0-picks-a-port` &middot; `bound-host` &middot; `address-in-use` (raises) &middot; `already-bound` (raises) &middot; `closed` (raises)

</details>

### <a name="val-listen"></a>`listen`

```sml
val listen : ('af, passive stream) sock * int -> unit
```

`listen (sock, n)` makes the socket wait for connections, keeping up to `n` of them unanswered.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not bound.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `backlog-above-the-limit` &middot; `then-connections-are-accepted` &middot; `closed` (raises)

</details>

### <a name="val-accept"></a>`accept`

```sml
val accept : ('af, passive stream) sock -> ('af, active stream) sock * 'af sock_addr
```

`accept sock` waits for a connection and is a socket on it and the address it came from.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not listening, or the wait
fails.

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `address-of-the-client` &middot; `new-socket-like-the-listener` &middot; `new-socket-is-connected` &middot; `first-in-the-queue` &middot; `not-listening` (raises) &middot; `closed` (raises)

</details>

### <a name="val-acceptnb"></a>`acceptNB`

```sml
val acceptNB : ('af, passive stream) sock -> (('af, active stream) sock * 'af sock_addr) option
```

`acceptNB sock` is [`accept`](#val-accept) that does not wait: `NONE` when no connection is there.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not listening.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `nothing-pending` &middot; `pending` &middot; `queue-emptied` &middot; `not-listening` (raises) &middot; `closed` (raises)

</details>

### <a name="val-connect"></a>`connect`

```sml
val connect : ('af, 'sock_type) sock * 'af sock_addr -> unit
```

`connect (sock, a)` connects the socket to the address `a`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the connection is refused or cannot be made.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; connect on a connected socket returns instead of raising SysErr

</details>

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `refused` (raises) &middot; `already-connected` (raises) &middot; `closed` (raises) &middot; `peer-is-the-listener` &middot; `dgram-peer` &middot; `dgram-receives-from-the-peer-only`

</details>

### <a name="val-connectnb"></a>`connectNB`

```sml
val connectNB : ('af, 'sock_type) sock * 'af sock_addr -> bool
```

`connectNB (sock, a)` is [`connect`](#val-connect) that does not wait, and is `true` when the connection is already made.

When it is `false` the connection is being made; [`select`](#val-select) says when it
is done.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the connection is refused.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `stream` &middot; `dgram` &middot; `closed` (raises)

</details>

### <a name="val-close"></a>`close`

```sml
val close : ('af, 'sock_type) sock -> unit
```

`close sock` closes the socket.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it was not open.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `twice` (raises) &middot; `twice-unix` (raises) &middot; `peer-sees-the-end` &middot; `peer-gets-the-data-then-the-end` &middot; `listener-stops-listening` (raises)

</details>

### <a name="type-shutdown_mode"></a>`shutdown_mode`

```sml
datatype shutdown_mode
  = NO_RECVS
  | NO_SENDS
  | NO_RECVS_OR_SENDS
```

Which half of a connection [`shutdown`](#val-shutdown) is to end.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-no_recvs"></a>`NO_RECVS` |  | nothing more may be received |
| <a name="con-no_sends"></a>`NO_SENDS` |  | nothing more may be sent |
| <a name="con-no_recvs_or_sends"></a>`NO_RECVS_OR_SENDS` |  | neither |

### <a name="val-shutdown"></a>`shutdown`

```sml
val shutdown : ('af, 'mode stream) sock * shutdown_mode -> unit
```

`shutdown (sock, mode)` ends the half of the connection that `mode` names, without closing the socket.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not connected.

> **Reading** `Socket.shutdown/peer-sees-the-end`. The page says only that
> "further sends will be disallowed"; the other end of a socket shut down
> for sending sees the end of its stream, after everything sent before it
> has arrived.

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `NO_SENDS-peer-sees-the-end` &middot; `unix-NO_SENDS` &middot; `not-connected` (raises) &middot; `closed` (raises)

</details>

### <a name="type-sock_desc"></a>`sock_desc`

```sml
type sock_desc
```

The type that names a socket to [`select`](#val-select), whatever its family and mode.

### <a name="val-sockdesc"></a>`sockDesc`

```sml
val sockDesc : ('af, 'sock_type) sock -> sock_desc
```

`sockDesc sock` is the descriptor of `sock`, for [`select`](#val-select).

<details><summary>Tests (1)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `sameDesc-of-itself`

</details>

### <a name="val-samedesc"></a>`sameDesc`

```sml
val sameDesc : sock_desc * sock_desc -> bool
```

`sameDesc (a, b)` is `true` when the two descriptors are of the same socket.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `same-socket` &middot; `different-sockets` &middot; `pair`

</details>

### <a name="val-select"></a>`select`

```sml
val select : {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list, timeout : Time.time option}
             -> {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list}
```

`select {rds, wrs, exs, timeout}` waits until one of the sockets is ready, and is those that are.

A `timeout` of `NONE` waits as long as it must.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if a descriptor is not one of an open socket, or
`timeout` is negative.

> **Implementation** `Socket.select/is-poll`. It is [`OS.IO.poll`](../sig/OS_IO.md#val-poll), so a
> negative timeout is refused rather than taken to mean "no timeout".

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-select.rds"></a>`rds` | `sock_desc list` |  |
| <a name="fld-select.wrs"></a>`wrs` | `sock_desc list` |  |
| <a name="fld-select.exs"></a>`exs` | `sock_desc list` |  |
| <a name="fld-select.timeout"></a>`timeout` | `Time.time option` |  |

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; sendVec' sends oob as don't\_route, so that there is no urgent byte to make an exceptional condition
- **Poly/ML** &mdash; select takes a negative timeout for zero instead of raising SysErr

</details>

<details><summary>Tests (14)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `timeout` &middot; `timeout-waits` &middot; `zero-timeout` &middot; `no-sockets` &middot; `readable` &middot; `no-timeout` &middot; `writable` &middot; `only-the-ready-ones` &middot; `in-two-lists` &middot; `order-preserved` &middot; `listener-readable-when-a-connection-is-pending` &middot; `closed` (raises) &middot; `negative-timeout` (raises)

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `exceptional-condition`

</details>

### <a name="val-iodesc"></a>`ioDesc`

```sml
val ioDesc : ('af, 'sock_type) sock -> OS.IO.iodesc
```

`ioDesc sock` is the socket as an [`OS.IO.iodesc`](../sig/OS_IO.md#type-iodesc), which [`OS.IO.poll`](../sig/OS_IO.md#val-poll) takes.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket.sml](../../../../tests/basis/socket.sml): `kind-is-socket` &middot; `kind-is-socket-unix` &middot; `same-socket` &middot; `different-sockets` &middot; `poll`

</details>

### <a name="type-out_flags"></a>`out_flags`

```sml
type out_flags = {don't_route : bool, oob : bool}
```

How something is to be sent: without routing, or as urgent data.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-out_flags.don-primet_route"></a>`don't_route` | `bool` |  |
| <a name="fld-out_flags.oob"></a>`oob` | `bool` |  |

### <a name="type-in_flags"></a>`in_flags`

```sml
type in_flags = {peek : bool, oob : bool}
```

How something is to be received: looking without taking, or taking urgent data.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-in_flags.peek"></a>`peek` | `bool` |  |
| <a name="fld-in_flags.oob"></a>`oob` | `bool` |  |

### <a name="val-sendvec"></a>`sendVec`

```sml
val sendVec : ('af, active stream) sock * Word8VectorSlice.slice -> int
```

`sendVec (sock, sl)` sends the bytes of `sl` and is the number it sent, which may be fewer.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not connected, or the other end has
gone.

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `count` &middot; `arrives` &middot; `slice` &middot; `empty-slice` &middot; `unix-pair-both-ways` &middot; `closed` (raises)

</details>

### <a name="val-sendarr"></a>`sendArr`

```sml
val sendArr : ('af, active stream) sock * Word8ArraySlice.slice -> int
```

`sendArr (sock, sl)` sends the bytes of the array stretch `sl` and is the number it sent.

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `count` &middot; `arrives` &middot; `slice` &middot; `empty-slice` &middot; `closed` (raises)

</details>

### <a name="val-sendvec-prime"></a>`sendVec'`

```sml
val sendVec' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int
```

`sendVec' (sock, sl, flags)` is [`sendVec`](#val-sendvec) with the flags `flags`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the flags of sendVec', sendArr', sendVecTo' and sendArrTo' are swapped: don't\_route sends out of band (the last byte of a stream goes out of band, a datagram is refused)
- **SML/NJ** &mdash; the flags are swapped: sendVec' and sendArr' send oob as don't\_route (no urgent byte), and recvVec' and recvArr' receive oob as peek

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `no-flags` &middot; `don't_route` &middot; `closed` (raises) &middot; `oob`

</details>

### <a name="val-sendarr-prime"></a>`sendArr'`

```sml
val sendArr' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int
```

`sendArr' (sock, sl, flags)` is [`sendArr`](#val-sendarr) with the flags `flags`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the flags of sendVec', sendArr', sendVecTo' and sendArrTo' are swapped: don't\_route sends out of band (the last byte of a stream goes out of band, a datagram is refused)
- **SML/NJ** &mdash; the flags are swapped: sendVec' and sendArr' send oob as don't\_route (no urgent byte), and recvVec' and recvArr' receive oob as peek

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `no-flags` &middot; `don't_route` &middot; `closed` (raises) &middot; `oob`

</details>

### <a name="val-sendvecnb"></a>`sendVecNB`

```sml
val sendVecNB : ('af, active stream) sock * Word8VectorSlice.slice -> int option
```

`sendVecNB (sock, sl)` is [`sendVec`](#val-sendvec) that does not wait: `NONE` when it would have to.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `room` &middot; `full` &middot; `closed` (raises)

</details>

### <a name="val-sendvecnb-prime"></a>`sendVecNB'`

```sml
val sendVecNB' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int option
```

`sendVecNB' (sock, sl, flags)` is [`sendVecNB`](#val-sendvecnb) with the flags `flags`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `room` &middot; `full` &middot; `closed` (raises)

</details>

### <a name="val-sendarrnb"></a>`sendArrNB`

```sml
val sendArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option
```

`sendArrNB (sock, sl)` is [`sendArr`](#val-sendarr) that does not wait.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `room` &middot; `full` &middot; `closed` (raises)

</details>

### <a name="val-sendarrnb-prime"></a>`sendArrNB'`

```sml
val sendArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int option
```

`sendArrNB' (sock, sl, flags)` is [`sendArrNB`](#val-sendarrnb) with the flags `flags`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `room` &middot; `full` &middot; `closed` (raises)

</details>

### <a name="val-recvvec"></a>`recvVec`

```sml
val recvVec : ('af, active stream) sock * int -> Word8Vector.vector
```

`recvVec (sock, n)` receives at most `n` bytes, waiting for at least one, and is what came.

The empty vector means that the other end has finished sending.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the socket is not connected.

> **Reading** `Socket.recvVec/zero-returns-at-once`. "If `n` is 0 the empty
> vector is returned": it is returned at once, without waiting for
> anything, where the system's own call would wait.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n` is negative or more than [`Word8Vector.maxLen`](../sig/MONO_VECTOR.md#val-maxlen).

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; recvVec and recvVecFrom do not raise Size when n \> Word8Vector.maxLen

</details>

<details><summary>Tests (8)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `at-most-n` &middot; `unix` &middot; `zero` &middot; `end-of-stream` &middot; `end-of-stream-again` &middot; `negative` (raises Size) &middot; `above-maxLen` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvvec-prime"></a>`recvVec'`

```sml
val recvVec' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector
```

`recvVec' (sock, n, flags)` is [`recvVec`](#val-recvvec) with the flags `flags`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec' and recvArr' receive oob as peek (the byte stays), and sendVec' sends oob as don't\_route (no urgent byte)
- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (6)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `oob` &middot; `peek` &middot; `no-flags` &middot; `end-of-stream` &middot; `negative` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvarr"></a>`recvArr`

```sml
val recvArr : ('af, active stream) sock * Word8ArraySlice.slice -> int
```

`recvArr (sock, sl)` receives into the stretch `sl` and is the number of bytes that came, 0 at the end.

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `count-and-place` &middot; `empty-slice` &middot; `end-of-stream` &middot; `closed` (raises)

</details>

### <a name="val-recvarr-prime"></a>`recvArr'`

```sml
val recvArr' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int
```

`recvArr' (sock, sl, flags)` is [`recvArr`](#val-recvarr) with the flags `flags`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec' and recvArr' receive oob as peek (the byte stays), and sendVec' sends oob as don't\_route (no urgent byte)
- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `oob` &middot; `peek` &middot; `end-of-stream` &middot; `closed` (raises)

</details>

### <a name="val-recvvecnb"></a>`recvVecNB`

```sml
val recvVecNB : ('af, active stream) sock * int -> Word8Vector.vector option
```

`recvVecNB (sock, n)` is [`recvVec`](#val-recvvec) that does not wait: `NONE` when nothing is there.

> **Reading** `Socket.recvVecNB/zero-is-SOME`. Since `recvVec (sock, 0)`
> gives the empty vector without waiting, `recvVecNB (sock, 0)` is `SOME`
> of the empty vector and not `NONE`, however little has arrived.

<details><summary>Other implementations (1)</summary>

- **MLton, Poly/ML** &mdash; recvVecNB (sock, 0) is NONE while nothing is there to read, instead of SOME of the empty vector (the system waits for a byte even when none is asked for)

</details>

<details><summary>Tests (7)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `nothing-there` &middot; `data` &middot; `end-of-stream` &middot; `zero` &middot; `negative` (raises Size) &middot; `closed` (raises) &middot; `then-blocking`

</details>

### <a name="val-recvvecnb-prime"></a>`recvVecNB'`

```sml
val recvVecNB' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector option
```

`recvVecNB' (sock, n, flags)` is [`recvVecNB`](#val-recvvecnb) with the flags `flags`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)
- **SML/NJ** &mdash; the flags are swapped: recvVecNB' takes peek for oob and raises SysErr (EINVAL) instead of giving NONE

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `nothing-there` &middot; `peek` &middot; `negative` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvarrnb"></a>`recvArrNB`

```sml
val recvArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option
```

`recvArrNB (sock, sl)` is [`recvArr`](#val-recvarr) that does not wait.

<details><summary>Other implementations (1)</summary>

- **MLton, Poly/ML** &mdash; recvArrNB with an empty slice is NONE while nothing is there to read, instead of SOME 0 (the system waits for a byte even when none is asked for)

</details>

<details><summary>Tests (5)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `nothing-there` &middot; `count-and-place` &middot; `end-of-stream` &middot; `empty-slice` &middot; `closed` (raises)

</details>

### <a name="val-recvarrnb-prime"></a>`recvArrNB'`

```sml
val recvArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int option
```

`recvArrNB' (sock, sl, flags)` is [`recvArrNB`](#val-recvarrnb) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_io.sml](../../../../tests/basis/socket_io.sml): `nothing-there` &middot; `peek` &middot; `closed` (raises)

</details>

### <a name="val-sendvecto"></a>`sendVecTo`

```sml
val sendVecTo : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> unit
```

`sendVecTo (sock, a, sl)` sends the bytes of `sl` as one message to the address `a`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the message cannot be sent.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; a datagram of no bytes never arrives

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `arrives` &middot; `slice` &middot; `empty-message` &middot; `closed` (raises)

</details>

### <a name="val-sendarrto"></a>`sendArrTo`

```sml
val sendArrTo : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> unit
```

`sendArrTo (sock, a, sl)` sends the bytes of the array stretch `sl` as one message to `a`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `arrives` &middot; `slice` &middot; `closed` (raises)

</details>

### <a name="val-sendvecto-prime"></a>`sendVecTo'`

```sml
val sendVecTo' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> unit
```

`sendVecTo' (sock, a, sl, flags)` is [`sendVecTo`](#val-sendvecto) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags of sendVec', sendArr', sendVecTo' and sendArrTo' are swapped: don't\_route sends out of band (the last byte of a stream goes out of band, a datagram is refused)

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `no-flags` &middot; `don't_route` &middot; `closed` (raises)

</details>

### <a name="val-sendarrto-prime"></a>`sendArrTo'`

```sml
val sendArrTo' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> unit
```

`sendArrTo' (sock, a, sl, flags)` is [`sendArrTo`](#val-sendarrto) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags of sendVec', sendArr', sendVecTo' and sendArrTo' are swapped: don't\_route sends out of band (the last byte of a stream goes out of band, a datagram is refused)

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `no-flags` &middot; `don't_route` &middot; `closed` (raises)

</details>

### <a name="val-sendvectonb"></a>`sendVecToNB`

```sml
val sendVecToNB : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> bool
```

`sendVecToNB (sock, a, sl)` is [`sendVecTo`](#val-sendvecto) that does not wait, and is `true` when it sent.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `room` &middot; `closed` (raises) &middot; `full`

</details>

### <a name="val-sendvectonb-prime"></a>`sendVecToNB'`

```sml
val sendVecToNB' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> bool
```

`sendVecToNB' (sock, a, sl, flags)` is [`sendVecToNB`](#val-sendvectonb) with the flags `flags`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `room` &middot; `closed` (raises) &middot; `full`

</details>

### <a name="val-sendarrtonb"></a>`sendArrToNB`

```sml
val sendArrToNB : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> bool
```

`sendArrToNB (sock, a, sl)` is [`sendArrTo`](#val-sendarrto) that does not wait, and is `true` when it sent.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `room` &middot; `closed` (raises) &middot; `full`

</details>

### <a name="val-sendarrtonb-prime"></a>`sendArrToNB'`

```sml
val sendArrToNB' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> bool
```

`sendArrToNB' (sock, a, sl, flags)` is [`sendArrToNB`](#val-sendarrtonb) with the flags `flags`.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `room` &middot; `closed` (raises) &middot; `full`

</details>

### <a name="val-recvvecfrom"></a>`recvVecFrom`

```sml
val recvVecFrom : ('af, dgram) sock * int -> Word8Vector.vector * 'af sock_addr
```

`recvVecFrom (sock, n)` receives one message of at most `n` bytes, and is it and where it came from.

<details><summary>Other implementations (3)</summary>

- **SML/NJ** &mdash; the address recvVecFrom gives is not sameAddr to the sender's (recvArrFrom's is)
- **SML/NJ** &mdash; the Unix-domain address recvVecFrom and recvVecFromNB give is garbled: UnixSock.fromAddr of it is not the sender's path
- **SML/NJ** &mdash; recvVec and recvVecFrom do not raise Size when n \> Word8Vector.maxLen

</details>

<details><summary>Tests (7)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `message-and-address` &middot; `one-message-at-a-time` &middot; `at-most-n` &middot; `unix` &middot; `negative` (raises Size) &middot; `above-maxLen` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvvecfrom-prime"></a>`recvVecFrom'`

```sml
val recvVecFrom' : ('af, dgram) sock * int * in_flags -> Word8Vector.vector * 'af sock_addr
```

`recvVecFrom' (sock, n, flags)` is [`recvVecFrom`](#val-recvvecfrom) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `peek` &middot; `no-flags` &middot; `negative` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvarrfrom"></a>`recvArrFrom`

```sml
val recvArrFrom : ('af, dgram) sock * Word8ArraySlice.slice -> int * 'af sock_addr
```

`recvArrFrom (sock, sl)` receives one message into the stretch `sl`, and is its length and where it came from.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; with an empty slice, the address recvArrFrom gives is not sameAddr to the sender's

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `count-place-and-address` &middot; `at-most-the-slice` &middot; `empty-slice` &middot; `closed` (raises)

</details>

### <a name="val-recvarrfrom-prime"></a>`recvArrFrom'`

```sml
val recvArrFrom' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> int * 'af sock_addr
```

`recvArrFrom' (sock, sl, flags)` is [`recvArrFrom`](#val-recvarrfrom) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `no-flags` &middot; `peek` &middot; `closed` (raises)

</details>

### <a name="val-recvvecfromnb"></a>`recvVecFromNB`

```sml
val recvVecFromNB : ('af, dgram) sock * int -> (Word8Vector.vector * 'af sock_addr) option
```

`recvVecFromNB (sock, n)` is [`recvVecFrom`](#val-recvvecfrom) that does not wait: `NONE` when no message is there.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the address recvVecFromNB gives is not sameAddr to the sender's (recvArrFromNB's is)

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `nothing-there` &middot; `message` &middot; `negative` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvvecfromnb-prime"></a>`recvVecFromNB'`

```sml
val recvVecFromNB' : ('af, dgram) sock * int * in_flags -> (Word8Vector.vector * 'af sock_addr) option
```

`recvVecFromNB' (sock, n, flags)` is [`recvVecFromNB`](#val-recvvecfromnb) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `nothing-there` &middot; `peek` &middot; `negative` (raises Size) &middot; `closed` (raises)

</details>

### <a name="val-recvarrfromnb"></a>`recvArrFromNB`

```sml
val recvArrFromNB : ('af, dgram) sock * Word8ArraySlice.slice -> (int * 'af sock_addr) option
```

`recvArrFromNB (sock, sl)` is [`recvArrFrom`](#val-recvarrfrom) that does not wait.

<details><summary>Tests (3)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `nothing-there` &middot; `message` &middot; `closed` (raises)

</details>

### <a name="val-recvarrfromnb-prime"></a>`recvArrFromNB'`

```sml
val recvArrFromNB' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> (int * 'af sock_addr) option
```

`recvArrFromNB' (sock, sl, flags)` is [`recvArrFromNB`](#val-recvarrfromnb) with the flags `flags`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)

</details>

<details><summary>Tests (4)</summary>

For `Socket`, in [tests/basis/socket\_dgram.sml](../../../../tests/basis/socket_dgram.sml): `nothing-there` &middot; `message` &middot; `peek` &middot; `closed` (raises)

</details>

## See also

[`INET_SOCK`](../sig/INET_SOCK.md), [`UNIX_SOCK`](../sig/UNIX_SOCK.md), [`GENERIC_SOCK`](../sig/GENERIC_SOCK.md), [`NET_HOST_DB`](../sig/NET_HOST_DB.md), [`OS_IO`](../sig/OS_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_socket.sml; do not edit.</sub>
