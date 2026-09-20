(* Sockets: connections between processes, on one machine or across a
   network.

   A socket carries two type variables that hold nothing but say what may be
   done with it. The first is its address family, so that an address of one
   family cannot be given to a socket of another; the second is what kind of
   socket it is -- `dgram` for one that sends messages, `passive stream` for
   one that is waiting for connections, `active stream` for one that is
   connected. `listen` needs a passive socket, `accept` turns one into an
   active one, and the send and receive functions need an active one. A
   program that gets the family or the mode wrong does not compile.

   `INET_SOCK` and `UNIX_SOCK` make the sockets of the two families;
   `GENERIC_SOCK` makes one of any family.

   The operations come in families of their own. `sendVec` and `sendArr`
   differ in where the bytes come from, the primed forms take flags, and the
   ones whose names end in `NB` never wait and answer `NONE` or `false`
   instead. `Ctl` reads and sets the options of a socket.

   Area: The operating system

   Status: optional

   See also: `INET_SOCK`, `UNIX_SOCK`, `GENERIC_SOCK`, `NET_HOST_DB`, `OS_IO`

   Erratum: `SOCKET/recvVecFrom-type-variable`. The page gives
   `recvVecFrom` and the three like it the result `Word8Vector.vector *
   'sock_type sock_addr`, a type variable that occurs nowhere else in the
   type. That is a slip for `'af`: the address a message came from is in the
   family of the socket, as it is for `recvArrFrom`, and as the description
   says. It is written `'af` here.

   Limitation: `SOCKET/no-ipv6`. There is no IPv6: `INetSock` is IPv4 only,
   and an `in_addr` is the dotted text of an IPv4 address.

   Implementation: `Socket.sock/is-a-descriptor`. A socket is the system's
   descriptor and a `sock_addr` the bytes of a `sockaddr`; the type variables
   are phantoms and hold nothing. The `NB` forms put the descriptor into
   non-blocking mode for the call and back afterwards. Sending to a peer that
   has gone fails with the condition `pipe` rather than raising the signal of
   that name. *)
signature SOCKET =
sig
  (* The type of a socket: its address family, then what kind of socket it is. *)
  type ('af, 'sock_type) sock

  (* The type of an address in the family `'af`. *)
  type 'af sock_addr

  (* The kind of a socket that sends messages, each to an address of its own. *)
  type dgram

  (* The kind of a socket that carries a stream of bytes; `'mode` says whether it is listening or connected. *)
  type 'mode stream

  (* The mode of a stream socket that is waiting for connections. *)
  type passive

  (* The mode of a stream socket that is connected. *)
  type active

  (* The address families the system knows. *)
  structure AF :
  sig
    (* The type of an address family, the one of `NetHostDB`. *)
    type addr_family = NetHostDB.addr_family

    (* `list ()` is the families this system has, each with its name. *)
    val list : unit -> (string * addr_family) list

    (* `toString af` is the name of `af`. *)
    val toString : addr_family -> string

    (* `fromString s` is `SOME` of the family called `s`, or `NONE`.

       Reading: `Socket.AF.fromString/without-the-prefix`. A name is the C
       constant without its leading `"AF_"`: `"INET"` and `"UNIX"`, so
       `"AF_INET"` gives `NONE`.

       Pinned by: `Socket.AF.fromString/*` *)
    val fromString : string -> addr_family option
  end

  (* The kinds of socket the system knows. *)
  structure SOCK :
  sig
    (* The type of a kind of socket, as the system names it. *)
    eqtype sock_type

    (* A stream of bytes that arrives in order and whole. *)
    val stream : sock_type

    (* Separate messages, which may be lost or arrive out of order. *)
    val dgram : sock_type

    (* `list ()` is the kinds this system has, each with its name. *)
    val list : unit -> (string * sock_type) list

    (* `toString st` is the name of `st`. *)
    val toString : sock_type -> string

    (* `fromString s` is `SOME` of the kind called `s`, or `NONE`. *)
    val fromString : string -> sock_type option
  end

  (* The options of a socket, read and set.

     Implementation: `Socket.Ctl/defaults-are-the-systems`. The values a new
     socket starts with are those of the C socket interface, which has every
     flag here off. The suite sets `DEBUG` to `false` only, since turning it
     on needs privileges.

     Pinned by: `Socket.Ctl.get*/default` *)
  structure Ctl :
  sig
    (* `getDEBUG sock` is `true` when the system is recording what the socket does. *)
    val getDEBUG : ('af, 'sock_type) sock -> bool

    (* `setDEBUG (sock, b)` asks the system to record what the socket does, or to stop. *)
    val setDEBUG : ('af, 'sock_type) sock * bool -> unit

    (* `getREUSEADDR sock` is `true` when the socket may bind an address that was lately in use. *)
    val getREUSEADDR : ('af, 'sock_type) sock -> bool

    (* `setREUSEADDR (sock, b)` allows or forbids binding an address that was lately in use. *)
    val setREUSEADDR : ('af, 'sock_type) sock * bool -> unit

    (* `getKEEPALIVE sock` is `true` when the connection is checked while it is idle. *)
    val getKEEPALIVE : ('af, 'sock_type) sock -> bool

    (* `setKEEPALIVE (sock, b)` asks for the connection to be checked while it is idle, or not. *)
    val setKEEPALIVE : ('af, 'sock_type) sock * bool -> unit

    (* `getDONTROUTE sock` is `true` when messages go to the local network only. *)
    val getDONTROUTE : ('af, 'sock_type) sock -> bool

    (* `setDONTROUTE (sock, b)` keeps messages on the local network, or lets them be routed. *)
    val setDONTROUTE : ('af, 'sock_type) sock * bool -> unit

    (* `getLINGER sock` is `SOME t` when closing waits up to `t` for what was sent, or `NONE` when it does not wait.

       Implementation: `Socket.Ctl.getLINGER/whole-seconds`. The system keeps
       the time in a `struct linger`, in whole seconds. *)
    val getLINGER : ('af, 'sock_type) sock -> Time.time option

    (* `setLINGER (sock, SOME t)` makes closing wait up to `t`; `NONE` makes it not wait.

       Raises: `Time` if `t` is negative or is 2^31 seconds or more, which
       the system's `int` cannot hold. *)
    val setLINGER : ('af, 'sock_type) sock * Time.time option -> unit

    (* `getBROADCAST sock` is `true` when the socket may send to a broadcast address. *)
    val getBROADCAST : ('af, 'sock_type) sock -> bool

    (* `setBROADCAST (sock, b)` allows or forbids sending to a broadcast address. *)
    val setBROADCAST : ('af, 'sock_type) sock * bool -> unit

    (* `getOOBINLINE sock` is `true` when urgent data arrive in the ordinary stream. *)
    val getOOBINLINE : ('af, 'sock_type) sock -> bool

    (* `setOOBINLINE (sock, b)` puts urgent data into the ordinary stream, or keeps them apart. *)
    val setOOBINLINE : ('af, 'sock_type) sock * bool -> unit

    (* `getSNDBUF sock` is the size in bytes of the room the system keeps for what is sent. *)
    val getSNDBUF : ('af, 'sock_type) sock -> int

    (* `setSNDBUF (sock, n)` asks for `n` bytes of room for what is sent.

       Implementation: `Socket.Ctl.setSNDBUF/at-least`. The system may give
       more room than was asked for -- Linux doubles it -- so the size read
       back is only bound to be at least `n`.

       Pinned by: `Socket.Ctl.setSNDBUF/*`, `Socket.Ctl.setRCVBUF/*` *)
    val setSNDBUF : ('af, 'sock_type) sock * int -> unit

    (* `getRCVBUF sock` is the size in bytes of the room the system keeps for what arrives. *)
    val getRCVBUF : ('af, 'sock_type) sock -> int

    (* `setRCVBUF (sock, n)` asks for `n` bytes of room for what arrives. *)
    val setRCVBUF : ('af, 'sock_type) sock * int -> unit

    (* `getTYPE sock` is the kind of socket that `sock` is. *)
    val getTYPE : ('af, 'sock_type) sock -> SOCK.sock_type

    (* `getERROR sock` is `true` when the socket has an error waiting, which reading it clears. *)
    val getERROR : ('af, 'sock_type) sock -> bool

    (* `getPeerName sock` is the address of the other end.

       Raises: `OS.SysErr` if the socket is not connected. *)
    val getPeerName : ('af, 'sock_type) sock -> 'af sock_addr

    (* `getSockName sock` is the address the socket is bound to.

       Raises: `OS.SysErr` if it is not bound. *)
    val getSockName : ('af, 'sock_type) sock -> 'af sock_addr

    (* `getNREAD sock` is how many bytes can be read from the socket without waiting. *)
    val getNREAD : ('af, 'sock_type) sock -> int

    (* `getATMARK sock` is `true` when the next byte to be read is the urgent one.

       Implementation: `Socket.Ctl.getATMARK/the-last-byte-is-urgent`. The
       mark falls where the host's TCP puts it: sending `"abc"` out of band
       puts it after `"ab"`, the last byte being the urgent one.

       Pinned by: `Socket.Ctl.getATMARK/before-and-at-the-mark` *)
    val getATMARK : ('af, active stream) sock -> bool
  end

  (* `sameAddr (a, b)` is `true` when the two addresses are the same one. *)
  val sameAddr : 'af sock_addr * 'af sock_addr -> bool

  (* `familyOfAddr a` is the address family that `a` belongs to. *)
  val familyOfAddr : 'af sock_addr -> AF.addr_family

  (* `bind (sock, a)` gives the socket the address `a`.

     Raises: `OS.SysErr` if the address is in use or may not be taken. *)
  val bind : ('af, 'sock_type) sock * 'af sock_addr -> unit

  (* `listen (sock, n)` makes the socket wait for connections, keeping up to `n` of them unanswered.

     Raises: `OS.SysErr` if the socket is not bound. *)
  val listen : ('af, passive stream) sock * int -> unit

  (* `accept sock` waits for a connection and is a socket on it and the address it came from.

     Raises: `OS.SysErr` if the socket is not listening, or the wait
     fails. *)
  val accept : ('af, passive stream) sock -> ('af, active stream) sock * 'af sock_addr

  (* `acceptNB sock` is `accept` that does not wait: `NONE` when no connection is there.

     Raises: `OS.SysErr` if the socket is not listening. *)
  val acceptNB : ('af, passive stream) sock -> (('af, active stream) sock * 'af sock_addr) option

  (* `connect (sock, a)` connects the socket to the address `a`.

     Raises: `OS.SysErr` if the connection is refused or cannot be made. *)
  val connect : ('af, 'sock_type) sock * 'af sock_addr -> unit

  (* `connectNB (sock, a)` is `connect` that does not wait, and is `true` when the connection is already made.

     When it is `false` the connection is being made; `select` says when it
     is done.

     Raises: `OS.SysErr` if the connection is refused. *)
  val connectNB : ('af, 'sock_type) sock * 'af sock_addr -> bool

  (* `close sock` closes the socket.

     Raises: `OS.SysErr` if it was not open. *)
  val close : ('af, 'sock_type) sock -> unit

  (* Which half of a connection `shutdown` is to end. *)
  datatype shutdown_mode
    = NO_RECVS            (* nothing more may be received *)
    | NO_SENDS            (* nothing more may be sent *)
    | NO_RECVS_OR_SENDS   (* neither *)

  (* `shutdown (sock, mode)` ends the half of the connection that `mode` names, without closing the socket.

     Raises: `OS.SysErr` if the socket is not connected.

     Reading: `Socket.shutdown/peer-sees-the-end`. The page says only that
     "further sends will be disallowed"; the other end of a socket shut down
     for sending sees the end of its stream, after everything sent before it
     has arrived.

     Pinned by: `Socket.shutdown/*`, `Socket.NO_SENDS/data-sent-before-arrives` *)
  val shutdown : ('af, 'mode stream) sock * shutdown_mode -> unit

  (* The type that names a socket to `select`, whatever its family and mode. *)
  type sock_desc

  (* `sockDesc sock` is the descriptor of `sock`, for `select`. *)
  val sockDesc : ('af, 'sock_type) sock -> sock_desc

  (* `sameDesc (a, b)` is `true` when the two descriptors are of the same socket. *)
  val sameDesc : sock_desc * sock_desc -> bool

  (* `select {rds, wrs, exs, timeout}` waits until one of the sockets is ready, and is those that are.

     A `timeout` of `NONE` waits as long as it must.

     Raises: `OS.SysErr` if a descriptor is not one of an open socket, or
     `timeout` is negative.

     Implementation: `Socket.select/is-poll`. It is `OS.IO.poll`, so a
     negative timeout is refused rather than taken to mean "no timeout". *)
  val select : {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list, timeout : Time.time option}
               -> {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list}

  (* `ioDesc sock` is the socket as an `OS.IO.iodesc`, which `OS.IO.poll` takes. *)
  val ioDesc : ('af, 'sock_type) sock -> OS.IO.iodesc

  (* How something is to be sent: without routing, or as urgent data. *)
  type out_flags = {don't_route : bool, oob : bool}

  (* How something is to be received: looking without taking, or taking urgent data. *)
  type in_flags = {peek : bool, oob : bool}

  (* `sendVec (sock, sl)` sends the bytes of `sl` and is the number it sent, which may be fewer.

     Raises: `OS.SysErr` if the socket is not connected, or the other end has
     gone. *)
  val sendVec : ('af, active stream) sock * Word8VectorSlice.slice -> int

  (* `sendArr (sock, sl)` sends the bytes of the array stretch `sl` and is the number it sent. *)
  val sendArr : ('af, active stream) sock * Word8ArraySlice.slice -> int

  (* `sendVec' (sock, sl, flags)` is `sendVec` with the flags `flags`. *)
  val sendVec' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int

  (* `sendArr' (sock, sl, flags)` is `sendArr` with the flags `flags`. *)
  val sendArr' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int

  (* `sendVecNB (sock, sl)` is `sendVec` that does not wait: `NONE` when it would have to. *)
  val sendVecNB : ('af, active stream) sock * Word8VectorSlice.slice -> int option

  (* `sendVecNB' (sock, sl, flags)` is `sendVecNB` with the flags `flags`. *)
  val sendVecNB' : ('af, active stream) sock * Word8VectorSlice.slice * out_flags -> int option

  (* `sendArrNB (sock, sl)` is `sendArr` that does not wait. *)
  val sendArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option

  (* `sendArrNB' (sock, sl, flags)` is `sendArrNB` with the flags `flags`. *)
  val sendArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * out_flags -> int option

  (* `recvVec (sock, n)` receives at most `n` bytes, waiting for at least one, and is what came.

     The empty vector means that the other end has finished sending.

     Raises: `OS.SysErr` if the socket is not connected.

     Reading: `Socket.recvVec/zero-returns-at-once`. "If `n` is 0 the empty
     vector is returned": it is returned at once, without waiting for
     anything, where the system's own call would wait.

     Pinned by: `Socket.recvVec/zero*`

     Raises: `Size` if `n` is negative or more than `Word8Vector.maxLen`. *)
  val recvVec : ('af, active stream) sock * int -> Word8Vector.vector

  (* `recvVec' (sock, n, flags)` is `recvVec` with the flags `flags`. *)
  val recvVec' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector

  (* `recvArr (sock, sl)` receives into the stretch `sl` and is the number of bytes that came, 0 at the end. *)
  val recvArr : ('af, active stream) sock * Word8ArraySlice.slice -> int

  (* `recvArr' (sock, sl, flags)` is `recvArr` with the flags `flags`. *)
  val recvArr' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int

  (* `recvVecNB (sock, n)` is `recvVec` that does not wait: `NONE` when nothing is there.

     Reading: `Socket.recvVecNB/zero-is-SOME`. Since `recvVec (sock, 0)`
     gives the empty vector without waiting, `recvVecNB (sock, 0)` is `SOME`
     of the empty vector and not `NONE`, however little has arrived.

     Pinned by: `Socket.recvVecNB/zero` *)
  val recvVecNB : ('af, active stream) sock * int -> Word8Vector.vector option

  (* `recvVecNB' (sock, n, flags)` is `recvVecNB` with the flags `flags`. *)
  val recvVecNB' : ('af, active stream) sock * int * in_flags -> Word8Vector.vector option

  (* `recvArrNB (sock, sl)` is `recvArr` that does not wait. *)
  val recvArrNB : ('af, active stream) sock * Word8ArraySlice.slice -> int option

  (* `recvArrNB' (sock, sl, flags)` is `recvArrNB` with the flags `flags`. *)
  val recvArrNB' : ('af, active stream) sock * Word8ArraySlice.slice * in_flags -> int option

  (* `sendVecTo (sock, a, sl)` sends the bytes of `sl` as one message to the address `a`.

     Raises: `OS.SysErr` if the message cannot be sent. *)
  val sendVecTo : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> unit

  (* `sendArrTo (sock, a, sl)` sends the bytes of the array stretch `sl` as one message to `a`. *)
  val sendArrTo : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> unit

  (* `sendVecTo' (sock, a, sl, flags)` is `sendVecTo` with the flags `flags`. *)
  val sendVecTo' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> unit

  (* `sendArrTo' (sock, a, sl, flags)` is `sendArrTo` with the flags `flags`. *)
  val sendArrTo' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> unit

  (* `sendVecToNB (sock, a, sl)` is `sendVecTo` that does not wait, and is `true` when it sent. *)
  val sendVecToNB : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice -> bool

  (* `sendVecToNB' (sock, a, sl, flags)` is `sendVecToNB` with the flags `flags`. *)
  val sendVecToNB' : ('af, dgram) sock * 'af sock_addr * Word8VectorSlice.slice * out_flags -> bool

  (* `sendArrToNB (sock, a, sl)` is `sendArrTo` that does not wait, and is `true` when it sent. *)
  val sendArrToNB : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice -> bool

  (* `sendArrToNB' (sock, a, sl, flags)` is `sendArrToNB` with the flags `flags`. *)
  val sendArrToNB' : ('af, dgram) sock * 'af sock_addr * Word8ArraySlice.slice * out_flags -> bool

  (* `recvVecFrom (sock, n)` receives one message of at most `n` bytes, and is it and where it came from. *)
  val recvVecFrom : ('af, dgram) sock * int -> Word8Vector.vector * 'af sock_addr

  (* `recvVecFrom' (sock, n, flags)` is `recvVecFrom` with the flags `flags`. *)
  val recvVecFrom' : ('af, dgram) sock * int * in_flags -> Word8Vector.vector * 'af sock_addr

  (* `recvArrFrom (sock, sl)` receives one message into the stretch `sl`, and is its length and where it came from. *)
  val recvArrFrom : ('af, dgram) sock * Word8ArraySlice.slice -> int * 'af sock_addr

  (* `recvArrFrom' (sock, sl, flags)` is `recvArrFrom` with the flags `flags`. *)
  val recvArrFrom' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> int * 'af sock_addr

  (* `recvVecFromNB (sock, n)` is `recvVecFrom` that does not wait: `NONE` when no message is there. *)
  val recvVecFromNB : ('af, dgram) sock * int -> (Word8Vector.vector * 'af sock_addr) option

  (* `recvVecFromNB' (sock, n, flags)` is `recvVecFromNB` with the flags `flags`. *)
  val recvVecFromNB' : ('af, dgram) sock * int * in_flags -> (Word8Vector.vector * 'af sock_addr) option

  (* `recvArrFromNB (sock, sl)` is `recvArrFrom` that does not wait. *)
  val recvArrFromNB : ('af, dgram) sock * Word8ArraySlice.slice -> (int * 'af sock_addr) option

  (* `recvArrFromNB' (sock, sl, flags)` is `recvArrFromNB` with the flags `flags`. *)
  val recvArrFromNB' : ('af, dgram) sock * Word8ArraySlice.slice * in_flags -> (int * 'af sock_addr) option
end
