# signature INET_SOCK

[The Standard ML Basis Library](../README.md) &rsaquo; **INET_SOCK**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 17 entries documented |
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

signature INET\_SOCK, transcribed from
<https://smlfamily.github.io/Basis/inet-sock.html>

The substructures UDP and TCP are specified in place, as the page has
them. Socket and NetHostDB are the top-level structures.

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

### <a name="type-sock"></a>`sock`

```sml
type 'sock_type sock = (inet, 'sock_type) Socket.sock
```

### <a name="type-stream_sock"></a>`stream_sock`

```sml
type 'mode stream_sock = 'mode Socket.stream sock
```

### <a name="type-dgram_sock"></a>`dgram_sock`

```sml
type dgram_sock = Socket.dgram sock
```

### <a name="type-sock_addr"></a>`sock_addr`

```sml
type sock_addr = inet Socket.sock_addr
```

### <a name="val-inetaf"></a>`inetAF`

```sml
val inetAF : Socket.AF.addr_family
```

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `named-INET` &middot; `fromString-INET`

</details>

### <a name="val-toaddr"></a>`toAddr`

```sml
val toAddr : NetHostDB.in_addr * int -> sock_addr
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `fromAddr` &middot; `round-trip` &middot; `connect-to-it`

</details>

### <a name="val-fromaddr"></a>`fromAddr`

```sml
val fromAddr : sock_addr -> NetHostDB.in_addr * int
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `ports` &middot; `hosts` &middot; `bound-socket`

</details>

### <a name="val-any"></a>`any`

```sml
val any : int -> sock_addr
```

<details><summary>Tests (5)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `fromAddr` &middot; `port-0` &middot; `is-0.0.0.0` &middot; `bind` &middot; `reached-through-loopback`

</details>

### <a name="str-udp"></a>`UDP`

#### <a name="val-udp.socket"></a>`socket`

```sml
val socket : unit -> dgram_sock
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `dgram` &middot; `works` &middot; `new-each-time`

</details>

#### <a name="val-udp.socket-prime"></a>`socket'`

```sml
val socket' : int -> dgram_sock
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `zero-dgram` &middot; `zero-works` &middot; `udp-protocol`

</details>

### <a name="str-tcp"></a>`TCP`

#### <a name="val-tcp.socket"></a>`socket`

```sml
val socket : unit -> 'mode stream_sock
```

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `stream` &middot; `works`

</details>

#### <a name="val-tcp.socket-prime"></a>`socket'`

```sml
val socket' : int -> 'mode stream_sock
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `zero-stream` &middot; `zero-works` &middot; `tcp-protocol`

</details>

#### <a name="val-tcp.getnodelay"></a>`getNODELAY`

```sml
val getNODELAY : 'mode stream_sock -> bool
```

<details><summary>Tests (2)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `default` &middot; `listener-default`

</details>

#### <a name="val-tcp.setnodelay"></a>`setNODELAY`

```sml
val setNODELAY : 'mode stream_sock * bool -> unit
```

<details><summary>Tests (3)</summary>

For `INetSock`, in [tests/basis/inetsock.sml](../../../../tests/basis/inetsock.sml): `on` &middot; `off-again` &middot; `connected`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_inet\_sock.sml; do not edit.</sub>
