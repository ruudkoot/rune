(* Socket: the sockets themselves. A socket is a handle of the system; an
   address is the bytes the system keeps it in, which only the structure of
   its family takes apart. *)
structure RuneSocket =
struct
  local
    val const = _prim "posix_const" : string -> int
    val create' = _prim "socket_create" : int * int * int -> int
    val pair' = _prim "socket_pair" : int * int * int -> int list
    val bind' = _prim "socket_bind" : int * string -> int
    val connect' = _prim "socket_connect" : int * string -> int
    val listen' = _prim "socket_listen" : int * int -> int
    val accept' = _prim "socket_accept" : int -> int
    val send' = _prim "socket_send" : int * string * int -> int
    val sendto' = _prim "socket_sendto" : int * string * int * string -> int
    val recv' = _prim "socket_recv" : int * int * int -> string
    val recvfrom' = _prim "socket_recvfrom" : int * int * int -> string list
    val shutdown' = _prim "socket_shutdown" : int * int -> int
    val name' = _prim "socket_name" : int -> string
    val peer' = _prim "socket_peer" : int -> string
    val getopt' = _prim "socket_getopt" : int * int * int -> int
    val setopt' = _prim "socket_setopt" : int * int * int * int -> int
    val family' = _prim "socket_addr_family" : string -> int
    val close' = _prim "posix_close" : int -> int
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun checkString s = if s = "" then raise RuneError.lastError () else s
    fun named name = case const name of ~1 => 0 | v => v
  in
    (* The type variables of the specification say what the socket carries;
       the value is the handle either way. *)
    datatype ('af, 'sock) sock = SOCK of int
    datatype 'af sock_addr = ADDR of string
    type dgram = unit
    type 'mode stream = unit
    type passive = unit
    type active = unit

    structure AF =
    struct
      type addr_family = int
      val inet = named "AF_INET"
      val unix = named "AF_UNIX"
      fun list () = [("INET", inet), ("UNIX", unix)]
      fun toString af = if af = inet then "INET" else if af = unix then "UNIX" else "?"
      fun fromString "INET" = SOME inet
        | fromString "UNIX" = SOME unix
        | fromString _ = NONE
    end

    structure SOCK =
    struct
      type sock_type = int
      val stream = named "SOCK_STREAM"
      val dgram = named "SOCK_DGRAM"
      fun list () = [("STREAM", stream), ("DGRAM", dgram)]
      fun toString t = if t = stream then "STREAM" else if t = dgram then "DGRAM" else "?"
      fun fromString "STREAM" = SOME stream
        | fromString "DGRAM" = SOME dgram
        | fromString _ = NONE
    end

    fun sockToWord (SOCK fd) = Word.fromInt fd
    fun wordToSock w = SOCK (Word.toInt w)
    fun sockDesc (SOCK fd) = RuneIODesc.FD fd
    fun sameDesc (a, b) = RuneIODesc.compare (a, b) = EQUAL
    fun ioDesc (SOCK fd) = RuneIODesc.FD fd
    fun familyOfAddr (ADDR a) = family' a

    fun socket' (af, ty, protocol) = SOCK (check (create' (af, ty, protocol)))
    fun socket (af, ty) = socket' (af, ty, 0)
    fun socketPair' (af, ty, protocol) =
      case pair' (af, ty, protocol) of
        [a, b] => (SOCK a, SOCK b)
      | _ => raise RuneError.lastError ()
    fun socketPair (af, ty) = socketPair' (af, ty, 0)

    (* The family of a socket and of an address are the same variable, which
       is why these say so with an explicit one. *)
    fun 'af bind (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr) = ignore (check (bind' (fd, a)))
    fun 'af connect (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr) = ignore (check (connect' (fd, a)))
    fun listen (SOCK fd, backlog) = ignore (check (listen' (fd, backlog)))
    fun 'af accept (SOCK fd : ('af, passive stream) sock) : ('af, active stream) sock * 'af sock_addr =
      let val got = check (accept' fd)
      in (SOCK got, ADDR (checkString (peer' got))) end
    fun close (SOCK fd) = ignore (check (close' fd))

    datatype shutdown_mode = NO_RECVS | NO_SENDS | NO_RECVS_OR_SENDS
    fun shutdown (SOCK fd, mode) =
      ignore (check (shutdown' (fd, case mode of
                                      NO_RECVS => named "SHUT_RD"
                                    | NO_SENDS => named "SHUT_WR"
                                    | NO_RECVS_OR_SENDS => named "SHUT_RDWR")))

    fun 'af getSockName (SOCK fd : ('af, 'sock) sock) : 'af sock_addr = ADDR (checkString (name' fd))
    fun 'af getPeerName (SOCK fd : ('af, 'sock) sock) : 'af sock_addr = ADDR (checkString (peer' fd))

    (* Sending and receiving, on slices of bytes. *)
    val oob = named "MSG_OOB"
    val peek = named "MSG_PEEK"
    val dontRoute = named "MSG_DONTROUTE"
    fun flagsOf {don't_route, oob = wantOob} =
      Word.toInt (Word.orb (if don't_route then Word.fromInt dontRoute else 0w0,
                            if wantOob then Word.fromInt oob else 0w0))
    fun peekFlags {peek = wantPeek, oob = wantOob} =
      Word.toInt (Word.orb (if wantPeek then Word.fromInt peek else 0w0,
                            if wantOob then Word.fromInt oob else 0w0))

    fun sendVec (SOCK fd, slice) = check (send' (fd, Word8VectorSlice.vector slice, 0))
    fun sendArr (SOCK fd, slice) = check (send' (fd, Word8ArraySlice.vector slice, 0))
    fun sendVec' (SOCK fd, slice, flags) = check (send' (fd, Word8VectorSlice.vector slice, flagsOf flags))
    fun sendArr' (SOCK fd, slice, flags) = check (send' (fd, Word8ArraySlice.vector slice, flagsOf flags))
    fun 'af sendVecTo (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr, slice) =
      check (sendto' (fd, Word8VectorSlice.vector slice, 0, a))
    fun 'af sendArrTo (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr, slice) =
      check (sendto' (fd, Word8ArraySlice.vector slice, 0, a))
    fun 'af sendVecTo' (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr, slice, flags) =
      check (sendto' (fd, Word8VectorSlice.vector slice, flagsOf flags, a))
    fun 'af sendArrTo' (SOCK fd : ('af, 'sock) sock, ADDR a : 'af sock_addr, slice, flags) =
      check (sendto' (fd, Word8ArraySlice.vector slice, flagsOf flags, a))

    fun recvVec (SOCK fd, n) = if n < 0 then raise Size else recv' (fd, n, 0)
    fun recvVec' (SOCK fd, n, flags) = if n < 0 then raise Size else recv' (fd, n, peekFlags flags)
    fun intoArray (slice, got) =
      let val (a, i, _) = Word8ArraySlice.base slice
      in Word8Array.copyVec {src = got, dst = a, di = i}; Word8Vector.length got end
    fun recvArr (sock, slice) = intoArray (slice, recvVec (sock, Word8ArraySlice.length slice))
    fun recvArr' (sock, slice, flags) = intoArray (slice, recvVec' (sock, Word8ArraySlice.length slice, flags))

    fun 'af recvVecFrom (SOCK fd : ('af, 'sock) sock, n) : Word8Vector.vector * 'af sock_addr =
      if n < 0 then raise Size
      else
        (case recvfrom' (fd, n, 0) of
           [bytes, addr] => (bytes, ADDR addr)
         | _ => raise RuneError.lastError ())
    fun 'af recvVecFrom' (SOCK fd : ('af, 'sock) sock, n, flags) : Word8Vector.vector * 'af sock_addr =
      if n < 0 then raise Size
      else
        (case recvfrom' (fd, n, peekFlags flags) of
           [bytes, addr] => (bytes, ADDR addr)
         | _ => raise RuneError.lastError ())
    fun recvArrFrom (sock, slice) =
      let val (bytes, addr) = recvVecFrom (sock, Word8ArraySlice.length slice)
      in (intoArray (slice, bytes), addr) end
    fun recvArrFrom' (sock, slice, flags) =
      let val (bytes, addr) = recvVecFrom' (sock, Word8ArraySlice.length slice, flags)
      in (intoArray (slice, bytes), addr) end

    (* The options of a socket. *)
    local
      val solSocket = named "SOL_SOCKET"
      fun getBool (SOCK fd, name) = check (getopt' (fd, solSocket, named name)) <> 0
      fun setBool (SOCK fd, name, v) = ignore (check (setopt' (fd, solSocket, named name, if v then 1 else 0)))
      fun getInt (SOCK fd, name) = check (getopt' (fd, solSocket, named name))
      fun setInt (SOCK fd, name, v) = ignore (check (setopt' (fd, solSocket, named name, v)))
    in
      fun getDEBUG s = getBool (s, "SO_DEBUG")
      fun setDEBUG (s, v) = setBool (s, "SO_DEBUG", v)
      fun getREUSEADDR s = getBool (s, "SO_REUSEADDR")
      fun setREUSEADDR (s, v) = setBool (s, "SO_REUSEADDR", v)
      fun getKEEPALIVE s = getBool (s, "SO_KEEPALIVE")
      fun setKEEPALIVE (s, v) = setBool (s, "SO_KEEPALIVE", v)
      fun getDONTROUTE s = getBool (s, "SO_DONTROUTE")
      fun setDONTROUTE (s, v) = setBool (s, "SO_DONTROUTE", v)
      fun getBROADCAST s = getBool (s, "SO_BROADCAST")
      fun setBROADCAST (s, v) = setBool (s, "SO_BROADCAST", v)
      fun getOOBINLINE s = getBool (s, "SO_OOBINLINE")
      fun setOOBINLINE (s, v) = setBool (s, "SO_OOBINLINE", v)
      fun getSNDBUF s = getInt (s, "SO_SNDBUF")
      fun setSNDBUF (s, v) = setInt (s, "SO_SNDBUF", v)
      fun getRCVBUF s = getInt (s, "SO_RCVBUF")
      fun setRCVBUF (s, v) = setInt (s, "SO_RCVBUF", v)
      fun getTYPE s = getInt (s, "SO_TYPE")
      fun getERROR s = getInt (s, "SO_ERROR") <> 0
      (* "the time a socket lingers"; NONE when it does not *)
      fun getLINGER s = if getInt (s, "SO_LINGER") = 0 then NONE else SOME Time.zeroTime
      fun setLINGER (s, NONE) = setInt (s, "SO_LINGER", 0)
        | setLINGER (s, SOME t) = setInt (s, "SO_LINGER", IntInf.toInt (Time.toSeconds t))
      fun getNREAD s = 0
      fun getATMARK s = false
    end

    (* Waiting for sockets, on the poll of OS.IO. *)
    fun select {rds, wrs, exs, timeout} =
      let
        fun descs (l, f) = List.map (fn d => f (valOf (RuneIODesc.pollDesc d))) l
        val all = descs (rds, RuneIODesc.pollIn) @ descs (wrs, RuneIODesc.pollOut)
                  @ descs (exs, RuneIODesc.pollPri)
        val ready = RuneIODesc.poll (all, timeout)
        fun pick test =
          List.map (fn info => RuneIODesc.pollToIODesc (RuneIODesc.infoToPollDesc info))
                   (List.filter test ready)
      in {rds = pick RuneIODesc.isIn, wrs = pick RuneIODesc.isOut, exs = pick RuneIODesc.isPri} end
  end
end

structure Socket = RuneSocket
