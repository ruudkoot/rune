# signature SOCKET

[The Standard ML Basis Library](../README.md) &rsaquo; **SOCKET**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 93 entries documented |
| Source | [lib/basis/sig\_socket.sml](../../../../lib/basis/sig_socket.sml) |

## Synopsis

```sml
signature SOCKET
structure Socket : SOCKET  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Socket` |  | [lib/basis/socket.sml](../../../../lib/basis/socket.sml) |

signature SOCKET, transcribed from
<https://smlfamily.github.io/Basis/socket.html>

The substructures AF, SOCK and Ctl are specified in place, as the page
has them. NetHostDB.addr\_family, Time.time, OS.IO.iodesc and the slice
and vector types are those of the top-level structures.

The page gives recvVecFrom, recvVecFrom', recvVecFromNB and
recvVecFromNB' the result `Word8Vector.vector * 'sock_type sock_addr`, a
type variable that occurs nowhere else in the type. That is a slip for
'af: the address a message came from is in the family of the socket, as
for recvArrFrom and the rest, and as the description has it ("sa is the
socket address from the which the data originated"); no implementation
could give an address of every family. It is written 'af here.

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
  datatype <a href="#type-shutdown_mode">shutdown_mode</a> = <a href="#con-no_recvs">NO_RECVS</a> | <a href="#con-no_sends">NO_SENDS</a> | <a href="#con-no_recvs_or_sends">NO_RECVS_OR_SENDS</a>
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

### <a name="type-sock_addr"></a>`sock_addr`

```sml
type 'af sock_addr
```

### <a name="type-dgram"></a>`dgram`

```sml
type dgram
```

### <a name="type-stream"></a>`stream`

```sml
type 'mode stream
```

### <a name="type-passive"></a>`passive`

```sml
type passive
```

### <a name="type-active"></a>`active`

```sml
type active
```

### <a name="str-af"></a>`AF`

#### <a name="type-af.addr_family"></a>`addr_family`

```sml
type addr_family = NetHostDB.addr_family
```

#### <a name="val-af.list"></a>`list`

```sml
val list : unit -> (string * addr_family) list
```

#### <a name="val-af.tostring"></a>`toString`

```sml
val toString : addr_family -> string
```

#### <a name="val-af.fromstring"></a>`fromString`

```sml
val fromString : string -> addr_family option
```

### <a name="str-sock"></a>`SOCK`

#### <a name="type-sock.sock_type"></a>`sock_type`

```sml
eqtype sock_type
```

#### <a name="val-sock.stream"></a>`stream`

```sml
val stream : sock_type
```

#### <a name="val-sock.dgram"></a>`dgram`

```sml
val dgram : sock_type
```

#### <a name="val-sock.list"></a>`list`

```sml
val list : unit -> (string * sock_type) list
```

#### <a name="val-sock.tostring"></a>`toString`

```sml
val toString : sock_type -> string
```

#### <a name="val-sock.fromstring"></a>`fromString`

```sml
val fromString : string -> sock_type option
```

### <a name="str-ctl"></a>`Ctl`

#### <a name="val-ctl.getdebug"></a>`getDEBUG`

```sml
val getDEBUG : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setdebug"></a>`setDEBUG`

```sml
val setDEBUG : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getreuseaddr"></a>`getREUSEADDR`

```sml
val getREUSEADDR : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setreuseaddr"></a>`setREUSEADDR`

```sml
val setREUSEADDR : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getkeepalive"></a>`getKEEPALIVE`

```sml
val getKEEPALIVE : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setkeepalive"></a>`setKEEPALIVE`

```sml
val setKEEPALIVE : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getdontroute"></a>`getDONTROUTE`

```sml
val getDONTROUTE : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setdontroute"></a>`setDONTROUTE`

```sml
val setDONTROUTE : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getlinger"></a>`getLINGER`

```sml
val getLINGER : ('af, 'sock_type) sock -> Time.time option
```

#### <a name="val-ctl.setlinger"></a>`setLINGER`

```sml
val setLINGER : ('af, 'sock_type) sock * Time.time option -> unit
```

#### <a name="val-ctl.getbroadcast"></a>`getBROADCAST`

```sml
val getBROADCAST : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setbroadcast"></a>`setBROADCAST`

```sml
val setBROADCAST : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getoobinline"></a>`getOOBINLINE`

```sml
val getOOBINLINE : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.setoobinline"></a>`setOOBINLINE`

```sml
val setOOBINLINE : ('af, 'sock_type) sock * bool -> unit
```

#### <a name="val-ctl.getsndbuf"></a>`getSNDBUF`

```sml
val getSNDBUF : ('af, 'sock_type) sock -> int
```

#### <a name="val-ctl.setsndbuf"></a>`setSNDBUF`

```sml
val setSNDBUF : ('af, 'sock_type) sock * int -> unit
```

#### <a name="val-ctl.getrcvbuf"></a>`getRCVBUF`

```sml
val getRCVBUF : ('af, 'sock_type) sock -> int
```

#### <a name="val-ctl.setrcvbuf"></a>`setRCVBUF`

```sml
val setRCVBUF : ('af, 'sock_type) sock * int -> unit
```

#### <a name="val-ctl.gettype"></a>`getTYPE`

```sml
val getTYPE : ('af, 'sock_type) sock -> SOCK.sock_type
```

#### <a name="val-ctl.geterror"></a>`getERROR`

```sml
val getERROR : ('af, 'sock_type) sock -> bool
```

#### <a name="val-ctl.getpeername"></a>`getPeerName`

```sml
val getPeerName : ('af, 'sock_type) sock -> 'af sock_addr
```

#### <a name="val-ctl.getsockname"></a>`getSockName`

```sml
val getSockName : ('af, 'sock_type) sock -> 'af sock_addr
```

#### <a name="val-ctl.getnread"></a>`getNREAD`

```sml
val getNREAD : ('af, 'sock_type) sock -> int
```

#### <a name="val-ctl.getatmark"></a>`getATMARK`

```sml
val getATMARK : ('af, active stream) sock -> bool
```

### <a name="val-sameaddr"></a>`sameAddr`

```sml
val sameAddr : 'af sock_addr * 'af sock_addr -> bool
```

### <a name="val-familyofaddr"></a>`familyOfAddr`

```sml
val familyOfAddr : 'af sock_addr -> AF.addr_family
```

### <a name="val-bind"></a>`bind`

```sml
val bind : ('af, 'sock_type) sock * 'af sock_addr -> unit
```

### <a name="val-listen"></a>`listen`

```sml
val listen : ('af, passive stream) sock * int -> unit
```

### <a name="val-accept"></a>`accept`

```sml
val accept : ('af, passive stream) sock -> ('af, active stream) sock * 'af sock_addr
```

### <a name="val-acceptnb"></a>`acceptNB`

```sml
val acceptNB : ('af, passive stream) sock -> (('af, active stream) sock * 'af sock_addr) option
```

### <a name="val-connect"></a>`connect`

```sml
val connect : ('af, 'sock_type) sock * 'af sock_addr -> unit
```

### <a name="val-connectnb"></a>`connectNB`

```sml
val connectNB : ('af, 'sock_type) sock * 'af sock_addr -> bool
```

### <a name="val-close"></a>`close`

```sml
val close : ('af, 'sock_type) sock -> unit
```

### <a name="type-shutdown_mode"></a>`shutdown_mode`

```sml
datatype shutdown_mode = NO_RECVS | NO_SENDS | NO_RECVS_OR_SENDS
```

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-no_recvs"></a>`NO_RECVS` |  |  |
| <a name="con-no_sends"></a>`NO_SENDS` |  |  |
| <a name="con-no_recvs_or_sends"></a>`NO_RECVS_OR_SENDS` |  |  |

### <a name="val-shutdown"></a>`shutdown`

```sml
val shutdown : ('af, 'mode stream) sock * shutdown_mode -> unit
```

### <a name="type-sock_desc"></a>`sock_desc`

```sml
type sock_desc
```

### <a name="val-sockdesc"></a>`sockDesc`

```sml
val sockDesc : ('af, 'sock_type) sock -> sock_desc
```

### <a name="val-samedesc"></a>`sameDesc`

```sml
val sameDesc : sock_desc * sock_desc -> bool
```

### <a name="val-select"></a>`select`

```sml
val select : {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list, timeout : Time.time option}
             -> {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-select.rds"></a>`rds` | `sock_desc list` |  |
| <a name="fld-select.wrs"></a>`wrs` | `sock_desc list` |  |
| <a name="fld-select.exs"></a>`exs` | `sock_desc list` |  |
| <a name="fld-select.timeout"></a>`timeout` | `Time.time option` |  |

### <a name="val-iodesc"></a>`ioDesc`

```sml
val ioDesc : ('af, 'sock_type) sock -> OS.IO.iodesc
```

### <a name="type-out_flags"></a>`out_flags`

```sml
type out_flags = {don't_route : bool, oob : bool}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-out_flags.don-primet_route"></a>`don't_route` | `bool` |  |
| <a name="fld-out_flags.oob"></a>`oob` | `bool` |  |

### <a name="type-in_flags"></a>`in_flags`

```sml
type in_flags = {peek : bool, oob : bool}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-in_flags.peek"></a>`peek` | `bool` |  |
| <a name="fld-in_flags.oob"></a>`oob` | `bool` |  |

### <a name="val-sendvec"></a>`sendVec`

```sml
val sendVec : ('af, active stream) sock * Word8VectorSlice.slice -> int
```

### <a name="val-sendarr"></a>`sendArr`

```sml
val sendArr : ('af, active stream) sock * Word8ArraySlice.slice -> int
```

### <a name="val-sendvec-prime"></a>`sendVec'`

```sml
val sendVec' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int
```

### <a name="val-sendarr-prime"></a>`sendArr'`

```sml
val sendArr' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int
```

### <a name="val-sendvecnb"></a>`sendVecNB`

```sml
val sendVecNB : ('af, active stream) sock * Word8VectorSlice.slice -> int option
```

### <a name="val-sendvecnb-prime"></a>`sendVecNB'`

```sml
val sendVecNB' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int option
```

### <a name="val-sendarrnb"></a>`sendArrNB`

```sml
val sendArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option
```

### <a name="val-sendarrnb-prime"></a>`sendArrNB'`

```sml
val sendArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int option
```

### <a name="val-recvvec"></a>`recvVec`

```sml
val recvVec : ('af, active stream) sock * int -> Word8Vector.vector
```

### <a name="val-recvvec-prime"></a>`recvVec'`

```sml
val recvVec' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector
```

### <a name="val-recvarr"></a>`recvArr`

```sml
val recvArr : ('af, active stream) sock * Word8ArraySlice.slice -> int
```

### <a name="val-recvarr-prime"></a>`recvArr'`

```sml
val recvArr' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int
```

### <a name="val-recvvecnb"></a>`recvVecNB`

```sml
val recvVecNB : ('af, active stream) sock * int -> Word8Vector.vector option
```

### <a name="val-recvvecnb-prime"></a>`recvVecNB'`

```sml
val recvVecNB' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector option
```

### <a name="val-recvarrnb"></a>`recvArrNB`

```sml
val recvArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option
```

### <a name="val-recvarrnb-prime"></a>`recvArrNB'`

```sml
val recvArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int option
```

### <a name="val-sendvecto"></a>`sendVecTo`

```sml
val sendVecTo : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> unit
```

### <a name="val-sendarrto"></a>`sendArrTo`

```sml
val sendArrTo : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> unit
```

### <a name="val-sendvecto-prime"></a>`sendVecTo'`

```sml
val sendVecTo' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> unit
```

### <a name="val-sendarrto-prime"></a>`sendArrTo'`

```sml
val sendArrTo' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> unit
```

### <a name="val-sendvectonb"></a>`sendVecToNB`

```sml
val sendVecToNB : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> bool
```

### <a name="val-sendvectonb-prime"></a>`sendVecToNB'`

```sml
val sendVecToNB' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> bool
```

### <a name="val-sendarrtonb"></a>`sendArrToNB`

```sml
val sendArrToNB : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> bool
```

### <a name="val-sendarrtonb-prime"></a>`sendArrToNB'`

```sml
val sendArrToNB' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> bool
```

### <a name="val-recvvecfrom"></a>`recvVecFrom`

```sml
val recvVecFrom : ('af, dgram) sock * int -> Word8Vector.vector * 'af sock_addr
```

### <a name="val-recvvecfrom-prime"></a>`recvVecFrom'`

```sml
val recvVecFrom' : ('af, dgram) sock * int * in_flags -> Word8Vector.vector * 'af sock_addr
```

### <a name="val-recvarrfrom"></a>`recvArrFrom`

```sml
val recvArrFrom : ('af, dgram) sock * Word8ArraySlice.slice -> int * 'af sock_addr
```

### <a name="val-recvarrfrom-prime"></a>`recvArrFrom'`

```sml
val recvArrFrom' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> int * 'af sock_addr
```

### <a name="val-recvvecfromnb"></a>`recvVecFromNB`

```sml
val recvVecFromNB : ('af, dgram) sock * int -> (Word8Vector.vector * 'af sock_addr) option
```

### <a name="val-recvvecfromnb-prime"></a>`recvVecFromNB'`

```sml
val recvVecFromNB' : ('af, dgram) sock * int * in_flags -> (Word8Vector.vector * 'af sock_addr) option
```

### <a name="val-recvarrfromnb"></a>`recvArrFromNB`

```sml
val recvArrFromNB : ('af, dgram) sock * Word8ArraySlice.slice -> (int * 'af sock_addr) option
```

### <a name="val-recvarrfromnb-prime"></a>`recvArrFromNB'`

```sml
val recvArrFromNB' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> (int * 'af sock_addr) option
```

---

<sub>Generated by runedoc from lib/basis/sig\_socket.sml; do not edit.</sub>
