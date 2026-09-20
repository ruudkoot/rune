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
    datatype inet' = InetFamily
  in
    type inet = inet'
    type 'sock_type sock = (inet, 'sock_type) RuneSocket.sock
    type 'mode stream_sock = 'mode RuneSocket.stream sock
    type dgram_sock = RuneSocket.dgram sock
    type sock_addr = inet RuneSocket.sock_addr

    val inetAF = named "AF_INET"

    fun toAddr (host : RuneNetHostDB.in_addr, port) : sock_addr =
      case inetAddr (host, port) of
        "" => raise RuneError.lastError ()
      | a => RuneSocket.ADDR a

    fun any port : sock_addr = case inetAddr ("", port) of "" => raise RuneError.lastError () | a => RuneSocket.ADDR a

    fun fromAddr (RuneSocket.ADDR a : sock_addr) =
      case inetParts a of
        [host, port] => (host, number port)
      | _ => raise RuneError.lastError ()

    structure UDP =
    struct
      fun socket () : dgram_sock = RuneSocket.socket (inetAF, RuneSocket.SOCK.dgram)
      fun socket' protocol : dgram_sock = RuneSocket.socket' (inetAF, RuneSocket.SOCK.dgram, protocol)
    end

    structure TCP =
    struct
      fun 'mode socket () : 'mode stream_sock = RuneSocket.socket (inetAF, RuneSocket.SOCK.stream)
      fun 'mode socket' protocol : 'mode stream_sock = RuneSocket.socket' (inetAF, RuneSocket.SOCK.stream, protocol)
      fun 'mode getNODELAY (RuneSocket.SOCK fd : 'mode stream_sock) =
        getopt' (fd, named "IPPROTO_TCP", named "TCP_NODELAY") <> 0
      fun 'mode setNODELAY (RuneSocket.SOCK fd : 'mode stream_sock, v) =
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
    datatype unix' = UnixFamily
  in
    type unix = unix'
    type 'sock_type sock = (unix, 'sock_type) RuneSocket.sock
    type 'mode stream_sock = 'mode RuneSocket.stream sock
    type dgram_sock = RuneSocket.dgram sock
    type sock_addr = unix RuneSocket.sock_addr

    val unixAF = named "AF_UNIX"

    fun toAddr path : sock_addr =
      case unixAddr path of
        "" => raise RuneError.lastError ()
      | a => RuneSocket.ADDR a
    fun fromAddr (RuneSocket.ADDR a : sock_addr) = unixPath a

    structure Strm =
    struct
      fun 'mode socket () : 'mode stream_sock = RuneSocket.socket (unixAF, RuneSocket.SOCK.stream)
      fun 'mode socketPair () : 'mode stream_sock * 'mode stream_sock =
        RuneSocket.socketPair (unixAF, RuneSocket.SOCK.stream)
    end

    structure DGrm =
    struct
      fun socket () : dgram_sock = RuneSocket.socket (unixAF, RuneSocket.SOCK.dgram)
      fun socketPair () : dgram_sock * dgram_sock = RuneSocket.socketPair (unixAF, RuneSocket.SOCK.dgram)
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
