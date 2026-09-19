(* INetSock, UnixSock and GenericSock: the families of sockets. *)
structure RuneINetSock =
struct
  local
    val inetAddr = _prim "socket_inet_addr" : string * int -> string
    val inetParts = _prim "socket_inet_parts" : string -> string list
    val const = _prim "posix_const" : string -> int
    val getopt' = _prim "socket_getopt" : int * int * int -> int
    val setopt' = _prim "socket_setopt" : int * int * int * int -> int
    fun named name = case const name of ~1 => 0 | v => v
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
  in
    type inet = unit
    type 'sock_type sock = (inet, 'sock_type) RuneSocket.sock
    type 'mode stream_sock = 'mode RuneSocket.stream sock
    type dgram_sock = RuneSocket.dgram sock
    type sock_addr = inet RuneSocket.sock_addr

    val inetAF = named "AF_INET"

    fun toAddr (host : RuneNetHostDB.in_addr, port) =
      case inetAddr (host, port) of
        "" => raise RuneError.lastError ()
      | a => RuneSocket.ADDR a

    fun any port = case inetAddr ("", port) of "" => raise RuneError.lastError () | a => RuneSocket.ADDR a

    fun fromAddr (RuneSocket.ADDR a) =
      case inetParts a of
        [host, port] => (host, number port)
      | _ => raise RuneError.lastError ()

    structure UDP =
    struct
      fun socket () = RuneSocket.socket (inetAF, RuneSocket.SOCK.dgram)
      fun socket' protocol = RuneSocket.socket' (inetAF, RuneSocket.SOCK.dgram, protocol)
    end

    structure TCP =
    struct
      fun socket () = RuneSocket.socket (inetAF, RuneSocket.SOCK.stream)
      fun socket' protocol = RuneSocket.socket' (inetAF, RuneSocket.SOCK.stream, protocol)
      fun getNODELAY (RuneSocket.SOCK fd) =
        getopt' (fd, named "IPPROTO_TCP", named "TCP_NODELAY") <> 0
      fun setNODELAY (RuneSocket.SOCK fd, v) =
        ignore (setopt' (fd, named "IPPROTO_TCP", named "TCP_NODELAY", if v then 1 else 0))
    end
  end
end

structure RuneUnixSock =
struct
  local
    val unixAddr = _prim "socket_unix_addr" : string -> string
    val unixPath = _prim "socket_unix_path" : string -> string
    val const = _prim "posix_const" : string -> int
    fun named name = case const name of ~1 => 0 | v => v
  in
    type unix = unit
    type 'sock_type sock = (unix, 'sock_type) RuneSocket.sock
    type 'mode stream_sock = 'mode RuneSocket.stream sock
    type dgram_sock = RuneSocket.dgram sock
    type sock_addr = unix RuneSocket.sock_addr

    val unixAF = named "AF_UNIX"

    fun toAddr path =
      case unixAddr path of
        "" => raise RuneError.lastError ()
      | a => RuneSocket.ADDR a
    fun fromAddr (RuneSocket.ADDR a) = unixPath a

    structure Strm =
    struct
      fun socket () = RuneSocket.socket (unixAF, RuneSocket.SOCK.stream)
      fun socketPair () = RuneSocket.socketPair (unixAF, RuneSocket.SOCK.stream)
    end

    structure DGrm =
    struct
      fun socket () = RuneSocket.socket (unixAF, RuneSocket.SOCK.dgram)
      fun socketPair () = RuneSocket.socketPair (unixAF, RuneSocket.SOCK.dgram)
    end
  end
end

structure RuneGenericSock =
struct
  fun socket (af, ty) = RuneSocket.socket (af, ty)
  fun socket' (af, ty, protocol) = RuneSocket.socket' (af, ty, protocol)
  fun socketPair (af, ty) = RuneSocket.socketPair (af, ty)
  fun socketPair' (af, ty, protocol) = RuneSocket.socketPair' (af, ty, protocol)
end

structure INetSock = RuneINetSock
structure UnixSock = RuneUnixSock
structure GenericSock = RuneGenericSock
