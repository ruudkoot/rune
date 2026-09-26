# structure Socket

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Socket**

|  |  |
| --- | --- |
| Signature | [`SOCKET`](../sig/SOCKET.md) |
| Status | optional |
| Members | 59 |
| Tests | 109 checks |
| Source | [lib/basis/socket.sml](../../../../lib/basis/socket.sml) |

## Synopsis

```sml
structure Socket : SOCKET
```

Socket: the sockets themselves. A socket is a handle of the system; an
address is the bytes the system keeps it in, which only the structure of
its family takes apart.

## Members

What each means is on [`SOCKET`](../sig/SOCKET.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`active`](../sig/SOCKET.md#type-active) | `active'` |
| type | [`dgram`](../sig/SOCKET.md#type-dgram) | `dgram'` |
| type | [`in_flags`](../sig/SOCKET.md#type-in_flags) | `{oob : bool, peek : bool}` |
| type | [`out_flags`](../sig/SOCKET.md#type-out_flags) | `{don't_route : bool, oob : bool}` |
| type | [`passive`](../sig/SOCKET.md#type-passive) | `passive'` |
| datatype | [`shutdown_mode`](../sig/SOCKET.md#type-shutdown_mode) | `NO_RECVS` &#124; `NO_SENDS` &#124; `NO_RECVS_OR_SENDS` |
| type | [`sock`](../sig/SOCKET.md#type-sock) | *a type of its own* |
| type | [`sock_addr`](../sig/SOCKET.md#type-sock_addr) | *a type of its own* |
| type | [`sock_desc`](../sig/SOCKET.md#type-sock_desc) | *a type of its own* |
| type | [`stream`](../sig/SOCKET.md#type-stream) | `'a stream'` |
| val | [`accept`](../sig/SOCKET.md#val-accept) | `('a, passive' stream') sock -> ('a, active' stream') sock * 'a sock_addr` |
| val | [`acceptNB`](../sig/SOCKET.md#val-acceptnb) | `('b, passive' stream') sock -> (('b, active' stream') sock * 'b sock_addr) option` |
| val | [`bind`](../sig/SOCKET.md#val-bind) | `('c, 'd) sock * 'c sock_addr -> unit` |
| val | [`close`](../sig/SOCKET.md#val-close) | `('e, 'f) sock -> unit` |
| val | [`connect`](../sig/SOCKET.md#val-connect) | `('g, 'h) sock * 'g sock_addr -> unit` |
| val | [`connectNB`](../sig/SOCKET.md#val-connectnb) | `('i, 'j) sock * 'i sock_addr -> bool` |
| val | [`familyOfAddr`](../sig/SOCKET.md#val-familyofaddr) | `'k sock_addr -> AF.addr_family` |
| val | [`ioDesc`](../sig/SOCKET.md#val-iodesc) | `('l, 'm) sock -> OS.IO.iodesc` |
| val | [`listen`](../sig/SOCKET.md#val-listen) | `('n, passive' stream') sock * int -> unit` |
| val | [`recvArr`](../sig/SOCKET.md#val-recvarr) | `('o, active' stream') sock * Word8ArraySlice.slice -> int` |
| val | [`recvArr'`](../sig/SOCKET.md#val-recvarr-prime) | `('p, active' stream') sock * Word8ArraySlice.slice * {oob : bool, peek : bool} -> int` |
| val | [`recvArrFrom`](../sig/SOCKET.md#val-recvarrfrom) | `('q, dgram') sock * Word8ArraySlice.slice -> int * 'q sock_addr` |
| val | [`recvArrFrom'`](../sig/SOCKET.md#val-recvarrfrom-prime) | `('r, dgram') sock * Word8ArraySlice.slice * {oob : bool, peek : bool} -> int * 'r sock_addr` |
| val | [`recvArrFromNB`](../sig/SOCKET.md#val-recvarrfromnb) | `('s, dgram') sock * Word8ArraySlice.slice -> (int * 's sock_addr) option` |
| val | [`recvArrFromNB'`](../sig/SOCKET.md#val-recvarrfromnb-prime) | `('t, dgram') sock * Word8ArraySlice.slice * {oob : bool, peek : bool} -> (int * 't sock_addr) option` |
| val | [`recvArrNB`](../sig/SOCKET.md#val-recvarrnb) | `('u, active' stream') sock * Word8ArraySlice.slice -> int option` |
| val | [`recvArrNB'`](../sig/SOCKET.md#val-recvarrnb-prime) | `('v, active' stream') sock * Word8ArraySlice.slice * {oob : bool, peek : bool} -> int option` |
| val | [`recvVec`](../sig/SOCKET.md#val-recvvec) | `('w, active' stream') sock * int -> BinIO.vector` |
| val | [`recvVec'`](../sig/SOCKET.md#val-recvvec-prime) | `('x, active' stream') sock * int * {oob : bool, peek : bool} -> BinIO.vector` |
| val | [`recvVecFrom`](../sig/SOCKET.md#val-recvvecfrom) | `('y, dgram') sock * int -> BinIO.vector * 'y sock_addr` |
| val | [`recvVecFrom'`](../sig/SOCKET.md#val-recvvecfrom-prime) | `('z, dgram') sock * int * {oob : bool, peek : bool} -> BinIO.vector * 'z sock_addr` |
| val | [`recvVecFromNB`](../sig/SOCKET.md#val-recvvecfromnb) | `('t26, dgram') sock * int -> (BinIO.vector * 't26 sock_addr) option` |
| val | [`recvVecFromNB'`](../sig/SOCKET.md#val-recvvecfromnb-prime) | `('t27, dgram') sock * int * {oob : bool, peek : bool} -> (BinIO.vector * 't27 sock_addr) option` |
| val | [`recvVecNB`](../sig/SOCKET.md#val-recvvecnb) | `('t28, active' stream') sock * int -> BinIO.vector option` |
| val | [`recvVecNB'`](../sig/SOCKET.md#val-recvvecnb-prime) | `('t29, active' stream') sock * int * {oob : bool, peek : bool} -> BinIO.vector option` |
| val | [`sameAddr`](../sig/SOCKET.md#val-sameaddr) | `'t30 sock_addr * 't30 sock_addr -> bool` |
| val | [`sameDesc`](../sig/SOCKET.md#val-samedesc) | `sock_desc * sock_desc -> bool` |
| val | [`select`](../sig/SOCKET.md#val-select) | `{exs : sock_desc list, rds : sock_desc list, timeout : Time.time option, wrs : sock_desc list} -> {exs : sock_desc list, rds : sock_desc list, wrs : sock_desc list}` |
| val | [`sendArr`](../sig/SOCKET.md#val-sendarr) | `('t31, active' stream') sock * Word8ArraySlice.slice -> int` |
| val | [`sendArr'`](../sig/SOCKET.md#val-sendarr-prime) | `('t32, active' stream') sock * Word8ArraySlice.slice * {don't_route : bool, oob : bool} -> int` |
| val | [`sendArrNB`](../sig/SOCKET.md#val-sendarrnb) | `('t33, active' stream') sock * Word8ArraySlice.slice -> int option` |
| val | [`sendArrNB'`](../sig/SOCKET.md#val-sendarrnb-prime) | `('t34, active' stream') sock * Word8ArraySlice.slice * {don't_route : bool, oob : bool} -> int option` |
| val | [`sendArrTo`](../sig/SOCKET.md#val-sendarrto) | `('t35, dgram') sock * 't35 sock_addr * Word8ArraySlice.slice -> unit` |
| val | [`sendArrTo'`](../sig/SOCKET.md#val-sendarrto-prime) | `('t36, dgram') sock * 't36 sock_addr * Word8ArraySlice.slice * {don't_route : bool, oob : bool} -> unit` |
| val | [`sendArrToNB`](../sig/SOCKET.md#val-sendarrtonb) | `('t37, dgram') sock * 't37 sock_addr * Word8ArraySlice.slice -> bool` |
| val | [`sendArrToNB'`](../sig/SOCKET.md#val-sendarrtonb-prime) | `('t38, dgram') sock * 't38 sock_addr * Word8ArraySlice.slice * {don't_route : bool, oob : bool} -> bool` |
| val | [`sendVec`](../sig/SOCKET.md#val-sendvec) | `('t39, active' stream') sock * Word8VectorSlice.slice -> int` |
| val | [`sendVec'`](../sig/SOCKET.md#val-sendvec-prime) | `('t40, active' stream') sock * Word8VectorSlice.slice * {don't_route : bool, oob : bool} -> int` |
| val | [`sendVecNB`](../sig/SOCKET.md#val-sendvecnb) | `('t41, active' stream') sock * Word8VectorSlice.slice -> int option` |
| val | [`sendVecNB'`](../sig/SOCKET.md#val-sendvecnb-prime) | `('t42, active' stream') sock * Word8VectorSlice.slice * {don't_route : bool, oob : bool} -> int option` |
| val | [`sendVecTo`](../sig/SOCKET.md#val-sendvecto) | `('t43, dgram') sock * 't43 sock_addr * Word8VectorSlice.slice -> unit` |
| val | [`sendVecTo'`](../sig/SOCKET.md#val-sendvecto-prime) | `('t44, dgram') sock * 't44 sock_addr * Word8VectorSlice.slice * {don't_route : bool, oob : bool} -> unit` |
| val | [`sendVecToNB`](../sig/SOCKET.md#val-sendvectonb) | `('t45, dgram') sock * 't45 sock_addr * Word8VectorSlice.slice -> bool` |
| val | [`sendVecToNB'`](../sig/SOCKET.md#val-sendvectonb-prime) | `('t46, dgram') sock * 't46 sock_addr * Word8VectorSlice.slice * {don't_route : bool, oob : bool} -> bool` |
| val | [`shutdown`](../sig/SOCKET.md#val-shutdown) | `('t47, 't48 stream') sock * shutdown_mode -> unit` |
| val | [`sockDesc`](../sig/SOCKET.md#val-sockdesc) | `('t49, 't50) sock -> sock_desc` |
| structure | [`AF`](../str/Socket.AF.md) |  |
| structure | [`Ctl`](../str/Socket.Ctl.md) |  |
| structure | [`SOCK`](../str/Socket.SOCK.md) |  |

## Notes

### 

> **Implementation** `Socket.sock/is-a-descriptor`. A socket is the system's
> descriptor and a [`sock_addr`](../sig/SOCKET.md#type-sock_addr) the bytes of a `sockaddr`; the type variables
> are phantoms and hold nothing. The `NB` forms put the descriptor into
> non-blocking mode for the call and back afterwards. Sending to a peer that
> has gone fails with the condition `pipe` rather than raising the signal of
> that name.

### recvVec

> **Reading** `Socket.recvVec/zero-returns-at-once`. "If `n` is 0 the empty
> vector is returned": it is returned at once, without waiting for
> anything, where the system's own call would wait.

### recvVecNB

> **Reading** `Socket.recvVecNB/zero-is-SOME`. Since `recvVec (sock, 0)`
> gives the empty vector without waiting, `recvVecNB (sock, 0)` is `SOME`
> of the empty vector and not `NONE`, however little has arrived.

### select

> **Implementation** `Socket.select/is-poll`. It is [`OS.IO.poll`](../sig/OS_IO.md#val-poll), so a
> negative timeout is refused rather than taken to mean "no timeout".

### shutdown

> **Reading** `Socket.shutdown/peer-sees-the-end`. The page says only that
> "further sends will be disallowed"; the other end of a socket shut down
> for sending sees the end of its stream, after everything sent before it
> has arrived.

<details><summary>Other implementations (17)</summary>

- **Poly/ML** &mdash; connect on a connected socket returns instead of raising SysErr
- **SML/NJ** &mdash; familyOfAddr gives a family that is neither INetSock.inetAF nor UnixSock.unixAF (AF.toString says "\<UNKNOWN\>")
- **SML/NJ** &mdash; the flags are swapped: recvVec' and recvArr' receive oob as peek (the byte stays), and sendVec' sends oob as don't\_route (no urgent byte)
- **SML/NJ** &mdash; the flags are swapped: recvVec', recvArr', recvVecFrom', recvArrFrom' and their NB forms receive peek as oob (SysErr EINVAL on a stream without urgent data; a datagram is taken off the queue)
- **SML/NJ** &mdash; with an empty slice, the address recvArrFrom gives is not sameAddr to the sender's
- **MLton, Poly/ML** &mdash; recvArrNB with an empty slice is NONE while nothing is there to read, instead of SOME 0 (the system waits for a byte even when none is asked for)
- **SML/NJ** &mdash; recvVec and recvVecFrom do not raise Size when n \> Word8Vector.maxLen
- **SML/NJ** &mdash; the address recvVecFrom gives is not sameAddr to the sender's (recvArrFrom's is)
- **SML/NJ** &mdash; the Unix-domain address recvVecFrom and recvVecFromNB give is garbled: UnixSock.fromAddr of it is not the sender's path
- **SML/NJ** &mdash; the address recvVecFromNB gives is not sameAddr to the sender's (recvArrFromNB's is)
- **MLton, Poly/ML** &mdash; recvVecNB (sock, 0) is NONE while nothing is there to read, instead of SOME of the empty vector (the system waits for a byte even when none is asked for)
- **SML/NJ** &mdash; the flags are swapped: recvVecNB' takes peek for oob and raises SysErr (EINVAL) instead of giving NONE
- **SML/NJ** &mdash; sendVec' sends oob as don't\_route, so that there is no urgent byte to make an exceptional condition
- **Poly/ML** &mdash; select takes a negative timeout for zero instead of raising SysErr
- **SML/NJ** &mdash; the flags of sendVec', sendArr', sendVecTo' and sendArrTo' are swapped: don't\_route sends out of band (the last byte of a stream goes out of band, a datagram is refused)
- **SML/NJ** &mdash; the flags are swapped: sendVec' and sendArr' send oob as don't\_route (no urgent byte), and recvVec' and recvArr' receive oob as peek
- **SML/NJ** &mdash; a datagram of no bytes never arrives

</details>

---

<sub>Generated by runedoc from lib/basis/socket.sml; do not edit.</sub>
