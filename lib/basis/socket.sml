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
    val fcntl' = _prim "posix_fcntl" : int * int * int -> int
    val errno' = _prim "sys_errno" : unit -> int
    val linger' = _prim "socket_linger" : int * int * int -> int list
    val query' = _prim "socket_query" : int * int -> int
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun checkString s = if s = "" then raise RuneError.lastError () else s
    fun named name = case const name of ~1 => 0 | v => v
    fun invalid () = let val e = RuneError.fromInt (named "EINVAL") in RuneError.SysErr (RuneError.errorMsg e, SOME e) end
    (* distinct types without values, so that the checker keeps them apart *)
    datatype dgram' = DGRAM
    datatype 'mode stream' = STREAM
    datatype passive' = PASSIVE
    datatype active' = ACTIVE
  in
    (* The type variables of the specification say what the socket carries;
       the value is the handle either way. *)
    datatype ('af, 'sock) sock = SOCK of int
    datatype 'af sock_addr = ADDR of string
    type dgram = dgram'
    type 'mode stream = 'mode stream'
    type passive = passive'
    type active = active'

    structure AF =
    struct
      type addr_family = RuneNet.addr_family
      val inet = RuneNet.familyFromInt (named "AF_INET")
      val unix = RuneNet.familyFromInt (named "AF_UNIX")
      fun list () = [("INET", inet), ("UNIX", unix)]
      fun toString af = if af = inet then "INET" else if af = unix then "UNIX" else "?"
      fun fromString "INET" = SOME inet
        | fromString "UNIX" = SOME unix
        | fromString _ = NONE
    end

    structure SOCK =
    struct
      type sock_type = RuneNet.sock_type
      val stream = RuneNet.typeFromInt (named "SOCK_STREAM")
      val dgram = RuneNet.typeFromInt (named "SOCK_DGRAM")
      fun list () = [("STREAM", stream), ("DGRAM", dgram)]
      fun toString t = if t = stream then "STREAM" else if t = dgram then "DGRAM" else "?"
      fun fromString "STREAM" = SOME stream
        | fromString "DGRAM" = SOME dgram
        | fromString _ = NONE
    end

    fun sockToWord (SOCK fd) = Word.fromInt fd
    fun wordToSock w = SOCK (Word.toInt w)

    type sock_desc = RuneIODesc.iodesc
    fun sockDesc (SOCK fd) = RuneIODesc.FD fd
    fun sameDesc (a, b) = RuneIODesc.compare (a, b) = EQUAL
    fun ioDesc (SOCK fd) = RuneIODesc.FD fd
    fun 'af sameAddr (ADDR a : 'af sock_addr, ADDR b : 'af sock_addr) = a = b
    fun familyOfAddr (ADDR a) = RuneNet.familyFromInt (family' a)

    fun socket' (af, ty, protocol) =
      SOCK (check (create' (RuneNet.familyToInt af, RuneNet.typeToInt ty, protocol)))
    fun socket (af, ty) = socket' (af, ty, 0)
    fun socketPair' (af, ty, protocol) =
      case pair' (RuneNet.familyToInt af, RuneNet.typeToInt ty, protocol) of
        [a, b] => (SOCK a, SOCK b)
      | _ => raise RuneError.lastError ()
    fun socketPair (af, ty) = socketPair' (af, ty, 0)

    (* The ...NB functions: the call with the handle in non-blocking mode, and
       NONE where it would have to wait. f reads errno before the mode is put
       back. *)
    fun nonBlocking (fd, f : unit -> 'a) : 'a =
      let
        val old = check (fcntl' (fd, named "F_GETFL", 0))
        val nb = Word.toInt (Word.orb (Word.fromInt old, Word.fromInt (named "O_NONBLOCK")))
        val _ = check (fcntl' (fd, named "F_SETFL", nb))
        val r = f () handle e => (ignore (fcntl' (fd, named "F_SETFL", old)); raise e)
      in ignore (fcntl' (fd, named "F_SETFL", old)); r end
    fun wouldBlock () =
      let val e = errno' ()
      in e = named "EAGAIN" orelse e = named "EWOULDBLOCK" orelse e = named "EINPROGRESS" end
    fun maybe (r, ok) = if r >= 0 then SOME (ok r) else if wouldBlock () then NONE else raise RuneError.lastError ()
    (* "" from a receive is the end of the stream only if errno is 0 *)
    fun received s = if s = "" andalso errno' () <> 0 then raise RuneError.lastError () else s
    fun receivedNB s =
      if s <> "" orelse errno' () = 0 then SOME s
      else if wouldBlock () then NONE
      else raise RuneError.lastError ()

    (* The family of a socket and of an address are the same variable, which
       is why these say so with an explicit one. *)
    fun 'af bind (SOCK fd : ('af, 'sock_type) sock, ADDR a : 'af sock_addr) = ignore (check (bind' (fd, a)))
    fun 'af connect (SOCK fd : ('af, 'sock_type) sock, ADDR a : 'af sock_addr) = ignore (check (connect' (fd, a)))
    fun 'af connectNB (SOCK fd : ('af, 'sock_type) sock, ADDR a : 'af sock_addr) =
      nonBlocking (fd, fn () => case maybe (connect' (fd, a), fn _ => ()) of SOME () => true | NONE => false)
    fun 'af listen (SOCK fd : ('af, passive stream) sock, backlog) = ignore (check (listen' (fd, backlog)))
    fun 'af accept (SOCK fd : ('af, passive stream) sock) : ('af, active stream) sock * 'af sock_addr =
      let val got = check (accept' fd)
      in (SOCK got, ADDR (checkString (peer' got))) end
    fun 'af acceptNB (SOCK fd : ('af, passive stream) sock) : (('af, active stream) sock * 'af sock_addr) option =
      nonBlocking (fd, fn () => maybe (accept' fd, fn got => (SOCK got, ADDR (checkString (peer' got)))))
    fun close (SOCK fd) = ignore (check (close' fd))

    datatype shutdown_mode = NO_RECVS | NO_SENDS | NO_RECVS_OR_SENDS
    fun 'mode shutdown (SOCK fd : ('af, 'mode stream) sock, mode) =
      ignore (check (shutdown' (fd, case mode of
                                      NO_RECVS => named "SHUT_RD"
                                    | NO_SENDS => named "SHUT_WR"
                                    | NO_RECVS_OR_SENDS => named "SHUT_RDWR")))

    (* Sending and receiving, on slices of bytes. *)
    type out_flags = {don't_route : bool, oob : bool}
    type in_flags = {peek : bool, oob : bool}
    fun outFlags ({don't_route, oob} : out_flags) =
      Word.toInt (Word.orb (if don't_route then Word.fromInt (named "MSG_DONTROUTE") else 0w0,
                            if oob then Word.fromInt (named "MSG_OOB") else 0w0))
    fun inFlags ({peek, oob} : in_flags) =
      Word.toInt (Word.orb (if peek then Word.fromInt (named "MSG_PEEK") else 0w0,
                            if oob then Word.fromInt (named "MSG_OOB") else 0w0))
    val noOut = {don't_route = false, oob = false}
    val noIn = {peek = false, oob = false}
    fun arrBytes sl = Word8ArraySlice.vector sl
    fun vecBytes sl = Word8VectorSlice.vector sl

    fun 'af sendVec' (SOCK fd : ('af, active stream) sock, sl, flags) = check (send' (fd, vecBytes sl, outFlags flags))
    fun 'af sendArr' (SOCK fd : ('af, active stream) sock, sl, flags) = check (send' (fd, arrBytes sl, outFlags flags))
    fun sendVec (s, sl) = sendVec' (s, sl, noOut)
    fun sendArr (s, sl) = sendArr' (s, sl, noOut)
    fun 'af sendVecNB' (SOCK fd : ('af, active stream) sock, sl, flags) =
      nonBlocking (fd, fn () => maybe (send' (fd, vecBytes sl, outFlags flags), fn n => n))
    fun 'af sendArrNB' (SOCK fd : ('af, active stream) sock, sl, flags) =
      nonBlocking (fd, fn () => maybe (send' (fd, arrBytes sl, outFlags flags), fn n => n))
    fun sendVecNB (s, sl) = sendVecNB' (s, sl, noOut)
    fun sendArrNB (s, sl) = sendArrNB' (s, sl, noOut)

    fun 'af sendVecTo' (SOCK fd : ('af, dgram) sock, ADDR a : 'af sock_addr, sl, flags) =
      ignore (check (sendto' (fd, vecBytes sl, outFlags flags, a)))
    fun 'af sendArrTo' (SOCK fd : ('af, dgram) sock, ADDR a : 'af sock_addr, sl, flags) =
      ignore (check (sendto' (fd, arrBytes sl, outFlags flags, a)))
    fun sendVecTo (s, a, sl) = sendVecTo' (s, a, sl, noOut)
    fun sendArrTo (s, a, sl) = sendArrTo' (s, a, sl, noOut)
    fun 'af sendVecToNB' (SOCK fd : ('af, dgram) sock, ADDR a : 'af sock_addr, sl, flags) =
      nonBlocking (fd, fn () => isSome (maybe (sendto' (fd, vecBytes sl, outFlags flags, a), fn _ => ())))
    fun 'af sendArrToNB' (SOCK fd : ('af, dgram) sock, ADDR a : 'af sock_addr, sl, flags) =
      nonBlocking (fd, fn () => isSome (maybe (sendto' (fd, arrBytes sl, outFlags flags, a), fn _ => ())))
    fun sendVecToNB (s, a, sl) = sendVecToNB' (s, a, sl, noOut)
    fun sendArrToNB (s, a, sl) = sendArrToNB' (s, a, sl, noOut)

    fun intoArray (sl, got) =
      let val (a, i, _) = Word8ArraySlice.base sl
      in Word8Array.copyVec {src = got, dst = a, di = i}; Word8Vector.length got end

    (* "Size if n < 0 or n > Word8Vector.maxLen". The system would wait for a
       byte to arrive even when none is asked for, but "if n is 0, then the
       empty vector will be returned": only whether the socket is open is
       looked at then. *)
    fun wanted (fd, n) =
      if n < 0 orelse n > Word8Vector.maxLen then raise Size
      else if n = 0 then (ignore (check (getopt' (fd, named "SOL_SOCKET", named "SO_TYPE"))); false)
      else true
    val none = Word8Vector.fromList []
    fun 'af recvVec' (SOCK fd : ('af, active stream) sock, n, flags) =
      if wanted (fd, n) then received (recv' (fd, n, inFlags flags)) else none
    fun recvVec (s, n) = recvVec' (s, n, noIn)
    fun recvArr' (s, sl, flags) = intoArray (sl, recvVec' (s, Word8ArraySlice.length sl, flags))
    fun recvArr (s, sl) = recvArr' (s, sl, noIn)
    fun 'af recvVecNB' (SOCK fd : ('af, active stream) sock, n, flags) =
      if wanted (fd, n) then nonBlocking (fd, fn () => receivedNB (recv' (fd, n, inFlags flags))) else SOME none
    fun recvVecNB (s, n) = recvVecNB' (s, n, noIn)
    fun recvArrNB' (s, sl, flags) =
      Option.map (fn v => intoArray (sl, v)) (recvVecNB' (s, Word8ArraySlice.length sl, flags))
    fun recvArrNB (s, sl) = recvArrNB' (s, sl, noIn)

    fun 'af recvVecFrom' (SOCK fd : ('af, dgram) sock, n, flags) : Word8Vector.vector * 'af sock_addr =
      if n < 0 orelse n > Word8Vector.maxLen then raise Size
      else
        (case recvfrom' (fd, n, inFlags flags) of
           [bytes, addr] => (bytes, ADDR addr)
         | _ => raise RuneError.lastError ())
    fun recvVecFrom (s, n) = recvVecFrom' (s, n, noIn)
    fun recvArrFrom' (s, sl, flags) =
      let val (bytes, addr) = recvVecFrom' (s, Word8ArraySlice.length sl, flags)
      in (intoArray (sl, bytes), addr) end
    fun recvArrFrom (s, sl) = recvArrFrom' (s, sl, noIn)
    fun 'af recvVecFromNB' (SOCK fd : ('af, dgram) sock, n, flags) : (Word8Vector.vector * 'af sock_addr) option =
      if n < 0 orelse n > Word8Vector.maxLen then raise Size
      else
        nonBlocking (fd, fn () =>
          case recvfrom' (fd, n, inFlags flags) of
            [bytes, addr] => SOME (bytes, ADDR addr)
          | _ => if wouldBlock () then NONE else raise RuneError.lastError ())
    fun recvVecFromNB (s, n) = recvVecFromNB' (s, n, noIn)
    fun recvArrFromNB' (s, sl, flags) =
      Option.map (fn (bytes, addr) => (intoArray (sl, bytes), addr))
                 (recvVecFromNB' (s, Word8ArraySlice.length sl, flags))
    fun recvArrFromNB (s, sl) = recvArrFromNB' (s, sl, noIn)

    (* The options of a socket, and its addresses. *)
    structure Ctl =
    struct
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
        fun getTYPE s : SOCK.sock_type = RuneNet.typeFromInt (getInt (s, "SO_TYPE"))
        fun getERROR s = getInt (s, "SO_ERROR") <> 0
        (* SO_LINGER is a struct linger: whether the socket lingers, and for
           how many seconds *)
        fun linger (SOCK fd, set, seconds) =
          case linger' (fd, set, seconds) of
            [s] => if s < 0 then NONE else SOME (Time.fromSeconds (IntInf.fromInt s))
          | _ => raise RuneError.lastError ()
        fun getLINGER s = linger (s, 0, 0)
        (* "If t is negative or too large, then the Time is raised": the
           system keeps the seconds in a C int *)
        fun setLINGER (s, NONE) = ignore (linger (s, 1, ~1))
          | setLINGER (s, SOME t) =
              let val secs = Time.toSeconds t
              in
                if Time.< (t, Time.zeroTime) orelse IntInf.>= (secs, IntInf.pow (IntInf.fromInt 2, 31))
                then raise Time.Time
                else ignore (linger (s, 1, IntInf.toInt secs))
              end
        fun 'af getSockName (SOCK fd : ('af, 'sock_type) sock) : 'af sock_addr = ADDR (checkString (name' fd))
        fun 'af getPeerName (SOCK fd : ('af, 'sock_type) sock) : 'af sock_addr = ADDR (checkString (peer' fd))
        (* the bytes that can be read at once (FIONREAD), and whether the
           next byte is the out-of-band mark (sockatmark) *)
        fun getNREAD (SOCK fd : ('af, 'sock_type) sock) = check (query' (fd, 0))
        fun getATMARK (SOCK fd : ('af, active stream) sock) = check (query' (fd, 1)) <> 0
      end
    end

    (* Waiting for sockets, on the poll of OS.IO, which would take a negative
       timeout for none: "This function raises SysErr ... if the timeout
       value is negative." *)
    fun select {rds : sock_desc list, wrs : sock_desc list, exs : sock_desc list, timeout} =
      let
        val () =
          case timeout of
            SOME t => if Time.< (t, Time.zeroTime) then raise invalid () else ()
          | NONE => ()
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

(* Implements: SOCKET

   Status: optional *)
structure Socket = RuneSocket
