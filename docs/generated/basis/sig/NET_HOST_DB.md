# signature NET_HOST_DB

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **NET_HOST_DB**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | 30 checks of 11 entries |
| Source | [lib/basis/sig\_net\_host\_db.sml](../../../../lib/basis/sig_net_host_db.sml) |

## Synopsis

```sml
signature NET_HOST_DB
structure NetHostDB : NET_HOST_DB  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `NetHostDB` |  | [lib/basis/netdb.sml](../../../../lib/basis/netdb.sml) |

The host database: turning a host name into an address, and back.

[`getByName`](#val-getbyname) and [`getByAddr`](#val-getbyaddr) ask the system what it knows about a host --
from `/etc/hosts`, from the domain name service, from whatever the machine
is set up to use. What comes back is an [`entry`](#type-entry), which the functions above
it take apart: a host may have several names and several addresses.

[`fromString`](#val-fromstring) and [`toString`](#val-tostring) do no lookup at all; they read and write the
dotted form of an address.

> **Implementation** `NetHostDB.in_addr/is-dotted-text`. An address is the
> canonical dotted text of an IPv4 address, so `=` compares addresses and
> not the text they were written as; there is no IPv6 here.

> **Deviation** `NetHostDB.in_addr/not-abstract`. The specification leaves
> [`in_addr`](#type-in_addr) and [`addr_family`](#type-addr_family) abstract; in Rune they are `string` and `int`,
> and the structure is not sealed.

## Interface

<pre>
signature NET_HOST_DB =
sig
  eqtype <a href="#type-in_addr">in_addr</a>

  eqtype <a href="#type-addr_family">addr_family</a>

  type <a href="#type-entry">entry</a>

  val <a href="#val-name">name</a> : entry -&gt; string

  val <a href="#val-aliases">aliases</a> : entry -&gt; string list

  val <a href="#val-addrtype">addrType</a> : entry -&gt; addr_family

  val <a href="#val-addr">addr</a> : entry -&gt; in_addr

  val <a href="#val-addrs">addrs</a> : entry -&gt; in_addr list

  val <a href="#val-getbyname">getByName</a> : string -&gt; entry option

  val <a href="#val-getbyaddr">getByAddr</a> : in_addr -&gt; entry option

  val <a href="#val-gethostname">getHostName</a> : unit -&gt; string

  val <a href="#val-tostring">toString</a> : in_addr -&gt; string

  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (in_addr, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; in_addr option
end
</pre>

### <a name="type-in_addr"></a>`in_addr`

```sml
eqtype in_addr
```

The type of the address of a host.

Two are equal when they are the same address.

### <a name="type-addr_family"></a>`addr_family`

```sml
eqtype addr_family
```

The type of an address family, the one of [`Socket.AF`](../sig/SOCKET.md#str-af).

### <a name="type-entry"></a>`entry`

```sml
type entry
```

The type of what the database records about one host.

### <a name="val-name"></a>`name`

```sml
val name : entry -> string
```

`name e` is the official name of the host.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-aliases"></a>`aliases`

```sml
val aliases : entry -> string list
```

`aliases e` is the other names the host answers to.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-addrtype"></a>`addrType`

```sml
val addrType : entry -> addr_family
```

`addrType e` is the address family of the host's addresses.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-addr"></a>`addr`

```sml
val addr : entry -> in_addr
```

`addr e` is the first of the host's addresses.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-addrs"></a>`addrs`

```sml
val addrs : entry -> in_addr list
```

`addrs e` is every address the host has.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-getbyname"></a>`getByName`

```sml
val getByName : string -> entry option
```

`getByName name` is `SOME` of what the database records about the host `name`, or `NONE`.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `localhost`

</details>

### <a name="val-getbyaddr"></a>`getByAddr`

```sml
val getByAddr : in_addr -> entry option
```

`getByAddr a` is `SOME` of what the database records about the host at `a`, or `NONE`.

<details><summary>Tests (1)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `loopback`

</details>

### <a name="val-gethostname"></a>`getHostName`

```sml
val getHostName : unit -> string
```

`getHostName ()` is the name of this machine.

> **Implementation** `NetHostDB.getHostName/is-the-nodename`. The "standard
> hostname" is the `nodename` that [`Posix.ProcEnv.uname`](../sig/POSIX_PROC_ENV.md#val-uname) reports.

<details><summary>Tests (3)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `not-empty` &middot; `stable` &middot; `uname`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : in_addr -> string
```

`toString a` is `a` in the dotted form, four decimal numbers separated by points.

<details><summary>Tests (2)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `dotted` &middot; `round-trip`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (in_addr, 'a) StringCvt.reader
```

`scan getc src` reads an address and is it and what is left.

> **Reading** `NetHostDB.scan/inet_aton-forms`. One number, two, three or
> four may be written, as the C library's `inet_aton` allows: a single
> part fills all 32 bits, the last of two parts the low 24, the last of
> three the low 16. "As specified in the C language" fixes how each part
> is written: `0x` or `0X` begins a hexadecimal number and a leading `0`
> an octal one.

<details><summary>Other implementations (1)</summary>

- **MLton, Poly/ML** &mdash; fromString and scan do not skip initial whitespace

</details>

<details><summary>Tests (7)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `rest` &middot; `whitespace-then-rest` &middot; `one-part-rest` &middot; `nothing-left` &middot; `char-list` &middot; `not-an-address` &middot; `empty`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> in_addr option
```

`fromString s` is `SOME` of the address that `s` begins with, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

<details><summary>Other implementations (4)</summary>

- **MLton, Poly/ML** &mdash; fromString and scan do not skip initial whitespace
- **Poly/ML** &mdash; the last number of "a.b" is taken for the last byte, not the last 24 bits ("127.1" is 0.0.127.1)
- **Poly/ML** &mdash; the last number of "a.b.c" is taken for the last byte, not the last 16 bits ("127.0.1" is 0.127.0.1)
- **Poly/ML** &mdash; "127.1" is read as 0.0.127.1, not 127.0.0.1

</details>

<details><summary>Tests (11)</summary>

For `NetHostDB`, in [tests/basis/netdb.sml](../../../../tests/basis/netdb.sml): `one-part` &middot; `two-parts` &middot; `three-parts` &middot; `hexadecimal` &middot; `octal` &middot; `zeros` &middot; `initial-whitespace` &middot; `prefix` &middot; `not-an-address` &middot; `same-address` &middot; `other-address`

</details>

## See also

[`SOCKET`](../sig/SOCKET.md), [`INET_SOCK`](../sig/INET_SOCK.md), [`NET_SERV_DB`](../sig/NET_SERV_DB.md), [`NET_PROT_DB`](../sig/NET_PROT_DB.md)

---

<sub>Generated by runedoc from lib/basis/sig\_net\_host\_db.sml; do not edit.</sub>
