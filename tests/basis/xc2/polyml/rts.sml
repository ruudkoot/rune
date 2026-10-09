(* The functions of Poly/ML's runtime (libpolyml), which the library calls
   with RunCall.rtsCallFullN "NAME" and rewrite.awk names XC2PR.NAME, made
   of the primitives of Rune's machine; the calls of the dispatchers
   PolyBasicIOGeneral and PolyOSSpecificGeneral with a constant code are
   NAME_CODE. They are typed where the library binds them: an int is Rune's
   int (Poly/ML's FixedInt.int), a LargeInt.int IntInf.int, a
   LargeWord.word and a SysWord.word Rune's Word64.word. A call that fails raises
   RunCall.SysErr with C's errno, as the runtime's raise_syscall does; one
   the shim does not make raises XC2.Unimplemented (the generated
   stubs.sml). *)
structure XC2PRImpl =
struct
  structure R = XC2PolyBuiltin.RunCall
  val c = XC2Sys.posixConst
  (* raise_syscall and raise_fail *)
  fun syserr () = let val e = XC2Sys.sysErrno () in raise R.SysErr (XC2Sys.errorMsg e, SOME (Word64.fromInt e)) end
  fun failWith e = raise R.SysErr (XC2Sys.errorMsg e, SOME (Word64.fromInt e))
  fun check (r : int) = if r = ~1 then syserr () else r
  fun unit (r : int) = ignore (check r)

  (* ---- machine.cpp, and the limits of Rune's machine *)
  fun PolyIsBigEndian () = XC2P.bigEndian
  fun PolyGetMaxAllocationSize () = Word.fromInt Array.maxLen
  fun PolyGetMaxStringSize () = Word.fromInt String.maxSize
  (* 0 for Unix *)
  fun PolyGetOSType () = 0

  (* ---- basicio.cpp: PolyBasicIOGeneral, a descriptor XC2P.iodesc *)
  fun fd (d : XC2P.iodesc) = case XC2P.fdOf d of ~1 => failWith (c "EBADF") | f => f
  (* open_file: the flags, with FD_CLOEXEC unless for Posix *)
  fun openFile (name : string, flags : int, mode : int, posix : bool) =
    case XC2Sys.openf (name, flags, mode) of
      ~1 => syserr ()
    | f => (if posix then () else ignore (XC2Sys.fcntl (f, c "F_SETFD", 1)); XC2P.wrapFd f)
  val rdonly = c "O_RDONLY"
  val wrtrunc = c "O_WRONLY" + c "O_CREAT" + c "O_TRUNC"
  val wrappend = c "O_WRONLY" + c "O_CREAT" + c "O_APPEND"
  fun PolyBasicIOGeneral_0 (_ : int, _ : int) = XC2P.wrapFd 0
  fun PolyBasicIOGeneral_1 (_ : int, _ : int) = XC2P.wrapFd 1
  fun PolyBasicIOGeneral_2 (_ : int, _ : int) = XC2P.wrapFd 2
  fun PolyBasicIOGeneral_3 (_ : int, name : string) = openFile (name, rdonly, 438, false)
  val PolyBasicIOGeneral_4 = PolyBasicIOGeneral_3
  fun PolyBasicIOGeneral_5 (_ : int, name : string) = openFile (name, wrtrunc, 438, false)
  val PolyBasicIOGeneral_6 = PolyBasicIOGeneral_5
  fun PolyBasicIOGeneral_13 (_ : int, name : string) = openFile (name, wrappend, 438, false)
  val PolyBasicIOGeneral_14 = PolyBasicIOGeneral_13
  (* close_file: never the standard descriptors *)
  fun PolyBasicIOGeneral_7 (d : XC2P.iodesc, _ : int) : unit =
    let val f = XC2P.fdOf d in if f > 2 then (ignore (XC2Sys.close f); XC2P.markClosed d) else () end
  (* select for input or output, the time 0, or for ever (~1) *)
  fun ready (f, ev, us) =
    case XC2Sys.osPoll ([f], [ev], us) of
      [r] => Int.rem (r div ev, 2) = 1
    | _ => false
  fun waitIn f = ignore (ready (f, 1, ~1))
  (* readArray, readString: wait for input, then read *)
  fun readn (f : int, n : int) : string =
    (waitIn f;
     if n = 0 then ""
     else case XC2Sys.read (f, n) of "" => (if XC2Sys.sysErrno () <> 0 then syserr () else "") | s => s)
  fun readArray (d : XC2P.iodesc, (a : XC2P.address, off : word, n : word)) : int =
    let val s = readn (fd d, Word.toInt n)
    in CharVector.appi (fn (i, ch) => XC2P.storeByte (a, off + Word.fromInt i, ch)) s; size s end
  val PolyBasicIOGeneral_8 = readArray
  val PolyBasicIOGeneral_9 = readArray
  fun PolyBasicIOGeneral_10 (d : XC2P.iodesc, n : int) : string = readn (fd d, Int.min (n, 102400))
  val PolyBasicIOGeneral_26 = PolyBasicIOGeneral_10
  (* writeArray: the bytes of the address from the offset *)
  fun writeArray (d : XC2P.iodesc, (a : XC2P.address, off : word, n : word)) : int =
    let
      val f = fd d
      val s = CharVector.tabulate (Word.toInt n, fn i => XC2P.loadByte (a, off + Word.fromInt i))
    in check (XC2Sys.write (f, s)) end
  val PolyBasicIOGeneral_11 = writeArray
  val PolyBasicIOGeneral_12 = writeArray
  fun PolyBasicIOGeneral_15 (_ : XC2P.iodesc, _ : int) : int = 4096
  fun PolyBasicIOGeneral_16 (d : XC2P.iodesc, _ : int) : int = if ready (fd d, 1, 0) then 1 else 0
  fun seek (f, pos, whence) = case XC2Sys.lseek (f, pos, whence) of ~1 => syserr () | p => p
  fun PolyBasicIOGeneral_17 (d : XC2P.iodesc, _ : int) : int =
    let
      val f = fd d
      val here = seek (f, 0, c "SEEK_CUR")
      val theEnd = seek (f, 0, c "SEEK_END")
    in if seek (f, here, c "SEEK_SET") <> here then syserr () else theEnd - here end
  fun PolyBasicIOGeneral_18 (d : XC2P.iodesc, _ : int) : IntInf.int = IntInf.fromInt (seek (fd d, 0, c "SEEK_CUR"))
  fun PolyBasicIOGeneral_19 (d : XC2P.iodesc, p : IntInf.int) : IntInf.int =
    (ignore (seek (fd d, IntInf.toInt p, c "SEEK_SET")); 0)
  fun PolyBasicIOGeneral_20 (d : XC2P.iodesc, _ : int) : IntInf.int =
    let
      val f = fd d
      val here = seek (f, 0, c "SEEK_CUR")
      val theEnd = seek (f, 0, c "SEEK_END")
    in if seek (f, here, c "SEEK_SET") <> here then syserr () else IntInf.fromInt theEnd end
  (* fileKind: 0 file, 1 directory, 2 link, 3 terminal, 4 pipe, 5 socket, 6
     device; a character or block device that is a terminal is one *)
  fun PolyBasicIOGeneral_21 (d : XC2P.iodesc, _ : int) : int =
    let val f = fd d
    in
      case XC2Sys.stat ("", 0, f) of
        [] => syserr ()
      | k :: _ =>
          (case k of
             0 => 0 | 1 => 1 | 2 => 2 | 4 => 4 | 5 => 5
           | 6 => if XC2Sys.isatty f = 1 then 3 else 6
           | 7 => if XC2Sys.isatty f = 1 then 3 else 6
           | _ => ~1)
    end
  fun PolyBasicIOGeneral_22 (_ : XC2P.iodesc, _ : int) : word = 0w7
  fun PolyBasicIOGeneral_27 (d : XC2P.iodesc, _ : int) : unit = waitIn (fd d)
  fun PolyBasicIOGeneral_28 (d : XC2P.iodesc, _ : int) : int = if ready (fd d, 2, 0) then 1 else 0
  fun PolyBasicIOGeneral_29 (d : XC2P.iodesc, _ : int) : unit = ignore (ready (fd d, 2, ~1))
  fun PolyBasicIOGeneral_30 (d : XC2P.iodesc, () : unit) : int = fd d
  fun PolyBasicIOGeneral_69 (d : XC2P.iodesc, () : unit) : int = fd d
  (* directories: the machine's directory handle. The runtime clears the
     handle a stream holds when it closes it, and then raises for it
     ("Stream is closed", EBADF); here the closed handles are kept, until
     the machine gives the number again *)
  val closedDirs : int list ref = ref []
  fun closedDir h = List.exists (fn k => k = h) (!closedDirs)
  fun PolyBasicIOGeneral_50 ((), name : string) : int =
    case XC2Sys.osOpenDir name of
      ~1 => syserr ()
    | h => (closedDirs := List.filter (fn k => k <> h) (!closedDirs); h)
  fun PolyBasicIOGeneral_51 (h : int, ()) : string =
    if closedDir h then failWith (c "EBADF")
    else case XC2Sys.osReadDir h of
           NONE => ""
         | SOME "." => PolyBasicIOGeneral_51 (h, ())
         | SOME ".." => PolyBasicIOGeneral_51 (h, ())
         | SOME n => n
  fun PolyBasicIOGeneral_52 (h : int, ()) : unit =
    if closedDir h then () else (ignore (XC2Sys.osCloseDir h); closedDirs := h :: !closedDirs)
  fun PolyBasicIOGeneral_53 (h : int, _ : string) : unit =
    if closedDir h then failWith (c "EBADF") else ignore (check (XC2Sys.osRewindDir h))
  fun PolyBasicIOGeneral_54 ((), ()) : string = case XC2Sys.osGetcwd () of "" => syserr () | d => d
  fun PolyBasicIOGeneral_55 ((), d : string) : unit = unit (XC2Sys.osMkdir d)
  fun PolyBasicIOGeneral_56 ((), d : string) : unit = unit (XC2Sys.osRmdir d)
  fun stat (p, follow) = case XC2Sys.stat (p, if follow then 0 else 1, ~1) of [] => syserr () | l => l
  fun PolyBasicIOGeneral_57 ((), p : string) : bool = hd (stat (p, true)) = 1
  fun PolyBasicIOGeneral_58 ((), p : string) : bool = hd (stat (p, false)) = 2
  fun PolyBasicIOGeneral_59 ((), p : string) : string =
    case XC2Sys.osReadLink p of "" => syserr () | l => l
  (* realpath, of "." for ""; the result is stat'ed *)
  fun PolyBasicIOGeneral_60 ((), p : string) : string =
    case (_prim "os_real_path" : string -> string) (if p = "" then "." else p) of
      "" => syserr ()
    | r => (ignore (stat (r, true)); r)
  (* the modification time in microseconds; the machine gives the seconds *)
  fun PolyBasicIOGeneral_61 ((), p : string) : IntInf.int = IntInf.* (IntInf.fromInt (List.nth (stat (p, true), 9)), 1000000)
  fun PolyBasicIOGeneral_62 ((), p : string) : IntInf.int = IntInf.fromInt (List.nth (stat (p, true), 7))
  fun PolyBasicIOGeneral_63 (p : string, t : IntInf.int) : unit =
    let val s = IntInf.toInt (IntInf.div (t, 1000000)) in unit (XC2Sys.utime (p, s, s)) end
  fun PolyBasicIOGeneral_64 ((), p : string) : unit = unit (XC2Sys.osRemove p)
  fun PolyBasicIOGeneral_65 (old : string, new : string) : unit = unit (XC2Sys.osRename (old, new))
  (* access: 1 read, 2 write, 4 execute, which are the machine's bits *)
  fun PolyBasicIOGeneral_66 (p : string, m : word) : bool = XC2Sys.osAccess (p, Word.toInt m, 0) = 1
  (* mkstemp of /tmp/MLTEMPXXXXXX, the file closed *)
  fun PolyBasicIOGeneral_67 ((), ()) : string =
    let
      val letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
      fun name k = "/tmp/MLTEMP" ^ CharVector.tabulate (6, fn i => String.sub (letters, (k div (i + 1) + 7 * i) mod 62))
      fun try k =
        let val p = name (XC2Sys.timeNow () + k * 7919)
        in case XC2Sys.openf (p, c "O_RDWR" + c "O_CREAT" + c "O_EXCL", 384) of
             ~1 => if k < 100 then try (k + 1) else syserr ()
           | f => (ignore (XC2Sys.close f); p)
        end
    in try 0 end
  fun PolyBasicIOGeneral_68 ((), p : string) : IntInf.int = IntInf.fromInt (List.nth (stat (p, true), 2))
  fun PolyBasicIOGeneral_70 (_ : int, (name : string, flags : int, _ : int)) = openFile (name, flags, 438, true)
  fun PolyBasicIOGeneral_71 (_ : int, (name : string, flags : int, mode : int)) =
    openFile (name, flags + (if Word.andb (Word.fromInt flags, Word.fromInt (c "O_CREAT")) = 0w0 then c "O_CREAT" else 0), mode, true)

  fun PolyChDir (d : string) : unit = unit (XC2Sys.osChdir d)

  (* ---- process_env.cpp *)
  fun PolyProcessEnvSuccessValue () : int = 0
  fun PolyProcessEnvFailureValue () : int = 1
  (* system: the status of waitpid, which the machine's primitive decodes
     (the code, or 256 and the signal) *)
  fun PolyProcessEnvSystem (cmd : string) : int =
    case XC2Sys.system cmd of ~1 => syserr () | r => if r < 256 then r * 256 else r - 256
  fun PolyFinish (n : int) : unit = (_prim "exit" : int -> unit) n
  fun PolyTerminate (n : int) : unit = XC2Sys.exit n
  fun PolyGetEnv (n : string) : string =
    case XC2Sys.getenv n of SOME v => v | NONE => raise R.SysErr ("Not Found", SOME 0w0)
  fun PolyGetEnvironment () : string list = XC2Sys.environ ()
  fun PolyGetProcessName () : string = (_prim "command_name" : unit -> string) ()
  fun PolyGetCommandlineArguments () : string list = (_prim "command_args" : unit -> string list) ()
  (* errors.cpp: the names of the error codes, the first of a code its name *)
  val errorTable =
    List.filter (fn (v, _) => v <> ~1) (List.map (fn n => (c n, n)) ["EPERM", "ENOENT", "ESRCH", "EINTR", "EIO", "ENXIO", "E2BIG", "ENOEXEC", "EBADF", "ECHILD", "EAGAIN", "EDEADLK", "ENOMEM", "EACCES", "EFAULT", "ENOTBLK", "EBUSY", "EEXIST", "EXDEV", "ENODEV", "ENOTDIR", "EISDIR", "EINVAL", "ENFILE", "EMFILE", "ENOTTY", "ETXTBSY", "EFBIG", "ENOSPC", "ESPIPE", "EROFS", "EMLINK", "EPIPE", "EDOM", "ERANGE", "ENOMSG", "EUCLEAN", "EWOULDBLOCK", "EIDRM", "EINPROGRESS", "ECHRNG", "EALREADY", "EL2NSYNC", "ENAMETOOLONG", "ENOTSOCK", "EL3HLT", "ENOLCK", "EDESTADDRREQ", "EL3RST", "ENOSYS", "EMSGSIZE", "ELNRNG", "ENOTEMPTY", "EPROTOTYPE", "EUNATCH", "EILSEQ", "ENOPROTOOPT", "ENOCSI", "EPROTONOSUPPORT", "EL2HLT", "ESOCKTNOSUPPORT", "EOPNOTSUPP", "ENOTREADY", "EPFNOSUPPORT", "EWRPROTECT", "EAFNOSUPPORT", "EFORMAT", "EADDRINUSE", "EADDRNOTAVAIL", "ENOCONNECT", "ENETDOWN", "ESTALE", "ENETUNREACH", "EDIST", "ENETRESET", "ECONNABORTED", "ECONNRESET", "ENOBUFS", "EISCONN", "ENOTCONN", "ESHUTDOWN", "ETOOMANYREFS", "ETIMEDOUT", "ECONNREFUSED", "ELOOP", "EHOSTDOWN", "EHOSTUNREACH", "EPROCLIM", "EUSERS", "EDQUOT", "EREMOTE", "ENOSTR", "EBADRPC", "ETIME", "ERPCMISMATCH", "ENOSR", "EPROGUNAVAIL", "EPROGMISMATCH", "EBADMSG", "EPROCUNAVAIL", "EFTYPE", "ENONET", "EAUTH", "ERESTART", "ERREMOTE", "ENEEDAUTH", "ENOLINK", "EADV", "ESRMNT", "ECOMM", "EPROTO", "EMULTIHOP", "EDOTDOT", "EREMCHG", "EMEDIA", "ESOFT", "ENOATTR", "ESAD", "ENOTRUST", "ECANCELED", "ENODATA", "EBADE", "EBADR", "EXFULL", "ENOANO", "EBADRQC", "EBADSLT", "EDEADLOCK", "EBFONT", "EBFONT", "ENOPKG", "ELBIN", "ENOTUNIQ", "EBADFD", "ELIBACC", "ELIBBAD", "ELIBSCN", "ELIBMAX", "ESTRPIPE", "ELIBEXEC", "ENMFILE", "ENOTNAM", "ENAVAIL", "EISNAM", "EREMOTEIO", "ENOMEDIUM", "EMEDIUMTYPE", "ENOKEY", "EKEYEXPIRED", "EKEYREVOKED", "EKEYREJECTED", "EOWNERDEAD", "ENOTRECOVERABLE", "ENOTSUP", "ENOMEDIUM", "ENOSHARE", "ECASECLASH", "EOVERFLOW"])
  fun PolyProcessEnvErrorName (e : Word64.word) : string =
    let val e = Word64.toIntX e
    in case List.find (fn (v, _) => v = e) errorTable of SOME (_, n) => n | NONE => "ERROR" ^ Int.toString e end
  fun PolyProcessEnvErrorMessage (e : Word64.word) : string = XC2Sys.errorMsg (Word64.toIntX e)
  fun PolyProcessEnvErrorFromString (s : string) : Word64.word =
    case List.find (fn (_, n) => n = s) errorTable of
      SOME (v, _) => Word64.fromInt v
    | NONE => if String.isPrefix "ERROR" s then Word64.fromInt (getOpt (Int.fromString (String.extract (s, 5, NONE)), 0)) else 0w0

  (* ---- network.cpp: a socket is a descriptor, non-blocking as the runtime
     makes it (not one accept gives), an address the bytes of C's sockaddr *)
  structure Sock =
  struct
    val create = _prim "socket_create" : int * int * int -> int
    val pair = _prim "socket_pair" : int * int * int -> int list
    val bind = _prim "socket_bind" : int * string -> int
    val connect = _prim "socket_connect" : int * string -> int
    val listen = _prim "socket_listen" : int * int -> int
    val accept = _prim "socket_accept" : int -> int
    val send = _prim "socket_send" : int * string * int -> int
    val sendto = _prim "socket_sendto" : int * string * int * string -> int
    val recv = _prim "socket_recv" : int * int * int -> string
    val recvfrom = _prim "socket_recvfrom" : int * int * int -> string list
    val shutdown = _prim "socket_shutdown" : int * int -> int
    val name = _prim "socket_name" : int -> string
    val peer = _prim "socket_peer" : int -> string
    val getopt = _prim "socket_getopt" : int * int * int -> int
    val setopt = _prim "socket_setopt" : int * int * int * int -> int
    val linger = _prim "socket_linger" : int * int * int -> int list
    val query = _prim "socket_query" : int * int -> int
    val inetAddr = _prim "socket_inet_addr" : string * int -> string
    val inet6Addr = _prim "socket_inet6_addr" : string * int -> string
    val inet6Parts = _prim "socket_inet6_parts" : string -> string list
    val unixAddr = _prim "socket_unix_addr" : string -> string
    val family = _prim "socket_addr_family" : string -> int
    val hostByName = _prim "netdb_host_byname" : string -> string list
    val hostByAddr = _prim "netdb_host_byaddr" : string -> string list
    val hostname = _prim "netdb_hostname" : unit -> string
    val protoByName = _prim "netdb_proto_byname" : string -> string list
    val protoByNumber = _prim "netdb_proto_bynumber" : int -> string list
    val servByName = _prim "netdb_serv_byname" : string * string -> string list
    val servByPort = _prim "netdb_serv_byport" : int * string -> string list
  end
  fun nonblocking f =
    let val fl = check (XC2Sys.fcntl (f, c "F_GETFL", 0))
    in unit (XC2Sys.fcntl (f, c "F_SETFL", Word.toInt (Word.orb (Word.fromInt fl, Word.fromInt (c "O_NONBLOCK"))))) end
  (* the families and the kinds of socket of the tables that the machine's
     constants have (AF_LOCAL and AF_FILE are AF_UNIX's other names) *)
  fun known l = List.filter (fn (_, v) => v <> ~1) l
  fun PolyNetworkGetAddrList () : (string * int) list =
    known [("UNIX", c "AF_UNIX"), ("LOCAL", c "AF_UNIX"), ("INET", c "AF_INET"), ("INET6", c "AF_INET6"), ("FILE", c "AF_UNIX")]
  fun PolyNetworkGetSockTypeList () : (string * int) list =
    known [("STREAM", c "SOCK_STREAM"), ("DGRAM", c "SOCK_DGRAM")]
  fun PolyNetworkCreateSocket (af : int, XC2P.SOCKTYPE st, p : int) : XC2P.iodesc =
    let val f = check (Sock.create (af, st, p)) in nonblocking f; XC2P.wrapFd f end
  fun PolyNetworkCreateSocketPair (af : int, XC2P.SOCKTYPE st, p : int) : XC2P.iodesc * XC2P.iodesc =
    case Sock.pair (af, st, p) of
      [a, b] => (nonblocking a; nonblocking b; (XC2P.wrapFd a, XC2P.wrapFd b))
    | _ => syserr ()
  (* the options by the codes of Socket.Ctl *)
  fun opt code =
    case code of
      15 => ("IPPROTO_TCP", "TCP_NODELAY") | 16 => ("IPPROTO_TCP", "TCP_NODELAY")
    | 17 => ("SOL_SOCKET", "SO_DEBUG") | 18 => ("SOL_SOCKET", "SO_DEBUG")
    | 19 => ("SOL_SOCKET", "SO_REUSEADDR") | 20 => ("SOL_SOCKET", "SO_REUSEADDR")
    | 21 => ("SOL_SOCKET", "SO_KEEPALIVE") | 22 => ("SOL_SOCKET", "SO_KEEPALIVE")
    | 23 => ("SOL_SOCKET", "SO_DONTROUTE") | 24 => ("SOL_SOCKET", "SO_DONTROUTE")
    | 25 => ("SOL_SOCKET", "SO_BROADCAST") | 26 => ("SOL_SOCKET", "SO_BROADCAST")
    | 27 => ("SOL_SOCKET", "SO_OOBINLINE") | 28 => ("SOL_SOCKET", "SO_OOBINLINE")
    | 29 => ("SOL_SOCKET", "SO_SNDBUF") | 30 => ("SOL_SOCKET", "SO_SNDBUF")
    | 31 => ("SOL_SOCKET", "SO_RCVBUF") | 32 => ("SOL_SOCKET", "SO_RCVBUF")
    | _ => ("SOL_SOCKET", "SO_TYPE")
  fun PolyNetworkSetOption (code : int, d : XC2P.iodesc, v : int) : unit =
    if code < 15 orelse code > 31 orelse code mod 2 = 0 then ()
    else let val (l, n) = opt code in unit (Sock.setopt (fd d, c l, c n, v)) end
  fun PolyNetworkGetOption (code : int, d : XC2P.iodesc) : int =
    let val (l, n) = opt code in check (Sock.getopt (fd d, c l, c n)) end
  (* a negative time turns it off; ~1 when it is off *)
  fun PolyNetworkSetLinger (d : XC2P.iodesc, t : IntInf.int) : unit =
    case Sock.linger (fd d, 1, if IntInf.< (t, 0) then ~1 else IntInf.toInt t) of [_] => () | _ => syserr ()
  fun PolyNetworkGetLinger (d : XC2P.iodesc) : IntInf.int =
    case Sock.linger (fd d, 0, 0) of [t] => IntInf.fromInt (if t < 0 then ~1 else t) | _ => syserr ()
  fun PolyNetworkGetPeerName (d : XC2P.iodesc) : string = case Sock.peer (fd d) of "" => syserr () | a => a
  fun PolyNetworkGetSockName (d : XC2P.iodesc) : string = case Sock.name (fd d) of "" => syserr () | a => a
  fun PolyNetworkBytesAvailable (d : XC2P.iodesc) : int = check (Sock.query (fd d, 0))
  fun PolyNetworkGetAtMark (d : XC2P.iodesc) : bool = check (Sock.query (fd d, 1)) <> 0
  fun PolyNetworkBind (d : XC2P.iodesc, a : string) : unit = unit (Sock.bind (fd d, a))
  fun PolyNetworkListen (d : XC2P.iodesc, n : int) : unit = unit (Sock.listen (fd d, n))
  fun PolyNetworkShutdown (d : XC2P.iodesc, m : int) : unit =
    unit (Sock.shutdown (fd d, case m of 1 => c "SHUT_RD" | 2 => c "SHUT_WR" | 3 => c "SHUT_RDWR" | _ => 0))
  fun PolyNetworkConnect (d : XC2P.iodesc, a : string) : unit = unit (Sock.connect (fd d, a))
  fun PolyNetworkAccept (d : XC2P.iodesc) : XC2P.iodesc * string =
    case Sock.accept (fd d) of ~1 => syserr () | s => (XC2P.wrapFd s, Sock.peer s)
  (* PolyNetworkCloseSocket raises EBADF for a socket already closed *)
  fun PolyNetworkCloseSocket (d : XC2P.iodesc) : unit =
    case XC2P.fdOf d of ~1 => failWith (c "EBADF") | f => (unit (XC2Sys.close f); XC2P.markClosed d)
  fun PolyNetworkGetSocketError (d : XC2P.iodesc) : Word64.word = Word64.fromInt (check (Sock.getopt (fd d, c "SOL_SOCKET", c "SO_ERROR")))
  fun bytes (a : XC2P.address, off : int, n : int) = CharVector.tabulate (n, fn i => XC2P.loadByte (a, Word.fromInt (off + i)))
  fun sendFlags (dr, oob) = (if dr then c "MSG_DONTROUTE" else 0) + (if oob then c "MSG_OOB" else 0)
  fun recvFlags (peek, oob) = (if peek then c "MSG_PEEK" else 0) + (if oob then c "MSG_OOB" else 0)
  fun PolyNetworkSend (d : XC2P.iodesc, a : XC2P.address, off : int, n : int, dr : bool, oob : bool) : int =
    check (Sock.send (fd d, bytes (a, off, n), sendFlags (dr, oob)))
  fun PolyNetworkSendTo (d : XC2P.iodesc, to : string, a : XC2P.address, off : int, n : int, dr : bool, oob : bool) : int =
    check (Sock.sendto (fd d, bytes (a, off, n), sendFlags (dr, oob), to))
  fun store (a, off, s) = CharVector.appi (fn (i, ch) => XC2P.storeByte (a, Word.fromInt (off + i), ch)) s
  fun PolyNetworkReceive (d : XC2P.iodesc, a : XC2P.address, off : int, n : int, peek : bool, oob : bool) : int =
    let val r = Sock.recv (fd d, n, recvFlags (peek, oob))
    in if r = "" andalso XC2Sys.sysErrno () <> 0 then syserr () else (store (a, off, r); size r) end
  fun PolyNetworkReceiveFrom (d : XC2P.iodesc, a : XC2P.address, off : int, n : int, peek : bool, oob : bool) : int * string =
    case Sock.recvfrom (fd d, n, recvFlags (peek, oob)) of
      [r, from] => (store (a, off, r); (size r, from))
    | _ => syserr ()
  (* select of the three vectors of sockets, for up to the milliseconds;
     the ones that are ready *)
  fun PolyNetworkSelect ((rv : XC2P.iodesc vector, wv : XC2P.iodesc vector, ev : XC2P.iodesc vector), ms : int) =
    let
      val sets = [(rv, 1), (wv, 2), (ev, 4)]
      val asked = List.concat (List.map (fn (v, b) => Vector.foldr (fn (d, l) => (d, fd d, b) :: l) [] v) sets)
      val got =
        if null asked then (ignore (XC2Sys.osPoll ([], [], ms * 1000)); [])
        else case XC2Sys.osPoll (List.map #2 asked, List.map #3 asked, ms * 1000) of
               [] => syserr ()
             | l => l
      val ready = ListPair.zip (asked, if null asked then [] else got)
      fun pick b = Vector.fromList (List.mapPartial (fn ((d, _, b'), r) => if b' = b andalso Int.rem (r div b, 2) = 1 then SOME d else NONE) ready)
    in (pick 1, pick 2, pick 4) end
  fun PolyNetworkGetFamilyFromAddress (a : string) : int = Sock.family a
  (* INET: the address as a number, and the port, in the network's order *)
  fun byte (s, i) = Char.ord (String.sub (s, i))
  fun PolyNetworkGetAddressAndPortFromIP4 (a : string) : IntInf.int * int =
    (IntInf.fromInt (((byte (a, 4) * 256 + byte (a, 5)) * 256 + byte (a, 6)) * 256 + byte (a, 7)),
     byte (a, 2) * 256 + byte (a, 3))
  fun dottedOf (n : IntInf.int) =
    let val n = IntInf.toInt n
    in String.concatWith "." (List.map (fn k => Int.toString (n div k mod 256)) [16777216, 65536, 256, 1]) end
  fun PolyNetworkCreateIP4Address (n : IntInf.int, port : int) : string =
    case Sock.inetAddr (dottedOf n, port mod 65536) of "" => syserr () | s => s
  fun PolyNetworkReturnIP4AddressAny () : IntInf.int = 0
  (* INET6: sockaddr_in6 is the family, the port, the flow, the 16 bytes of
     the address and the scope *)
  fun PolyNetworkGetAddressAndPortFromIP6 (a : string) : string * int =
    if size a <> 28 then raise R.Fail "Invalid length"
    else (String.substring (a, 8, 16), byte (a, 2) * 256 + byte (a, 3))
  fun PolyNetworkReturnIP6AddressAny () : string = CharVector.tabulate (16, fn _ => #"\000")
  fun PolyNetworkStringToIP6Address (s : string) : string =
    case Sock.inet6Addr (s, 0) of "" => raise R.Fail "Invalid IPv6 address" | a => String.substring (a, 8, 16)
  fun PolyNetworkCreateIP6Address (addr : string, port : int) : string =
    if size addr <> 16 then raise R.Fail "Invalid address length"
    else
      let val any = Sock.inet6Addr ("::", port mod 65536)
      in String.substring (any, 0, 8) ^ addr ^ String.extract (any, 24, NONE) end
  fun PolyNetworkIP6AddressToString (addr : string) : string =
    if size addr <> 16 then raise R.Fail "Invalid address length"
    else case Sock.inet6Parts (PolyNetworkCreateIP6Address (addr, 0)) of h :: _ => h | [] => syserr ()
  (* UNIX: the whole sockaddr_un *)
  val sunPathMax = 108
  fun PolyNetworkUnixPathToSockAddr (p : string) : string =
    if size p > sunPathMax then failWith (c "ENAMETOOLONG")
    else case Sock.unixAddr "" of
           "" => (case Sock.unixAddr "x" of
                    "" => syserr ()
                  | a => String.substring (a, 0, 2) ^ CharVector.tabulate (sunPathMax, fn i => if i < size p then String.sub (p, i) else #"\000"))
         | a => String.substring (a, 0, 2) ^ CharVector.tabulate (sunPathMax, fn i => if i < size p then String.sub (p, i) else #"\000")
  fun PolyNetworkUnixSockAddrToPath (a : string) : string =
    let val p = if size a > 2 then String.extract (a, 2, NONE) else ""
    in Substring.string (#1 (Substring.splitl (fn ch => ch <> #"\000") (Substring.full p))) end
  (* the databases *)
  fun num s = getOpt (Int.fromString s, 0)
  fun servent l = case l of name :: port :: proto :: aliases => SOME (name, aliases, num port, proto) | _ => NONE
  fun PolyNetworkGetServByName (n : string) = servent (Sock.servByName (n, ""))
  fun PolyNetworkGetServByNameAndProtocol (n : string, p : string) = servent (Sock.servByName (n, p))
  fun PolyNetworkGetServByPort (port : int) = servent (Sock.servByPort (port mod 65536, ""))
  fun PolyNetworkGetServByPortAndProtocol (port : int, p : string) = servent (Sock.servByPort (port mod 65536, p))
  fun protoent l = case l of name :: p :: aliases => SOME (name, aliases, num p) | _ => NONE
  fun PolyNetworkGetProtByName (n : string) = protoent (Sock.protoByName n)
  fun PolyNetworkGetProtByNo (n : int) = protoent (Sock.protoByNumber n)
  fun PolyNetworkGetHostName () : string = case Sock.hostname () of "" => syserr () | h => h
  (* getnameinfo: the name of the host, or its number when it has none *)
  fun PolyNetworkGetNameInfo (a : string) : string =
    if Sock.family a = c "AF_INET" then
      let val dotted = String.concatWith "." (List.map (fn i => Int.toString (byte (a, i))) [4, 5, 6, 7])
      in case Sock.hostByAddr dotted of name :: _ => name | [] => dotted end
    else case Sock.inet6Parts a of h :: _ => h | [] => failWith (c "EINVAL")
  (* getaddrinfo with AI_CANONNAME and no kind of socket: each address three
     times, for STREAM, DGRAM and RAW, the canonical name on the first *)
  fun PolyNetworkGetAddrInfo (host : string, af : int) =
    case Sock.hostByName host of
      [] => raise R.SysErr ("Name or service not known", SOME 0w0)
    | l =>
        let
          val (canon, addrs) = case l of [n] => (n, []) | n :: a :: _ => (n, String.tokens (fn ch => ch = #" ") a) | [] => ("", [])
          fun entries (i, a) =
            let val sa = Sock.inetAddr (a, 0)
            in [(2, c "AF_INET", c "SOCK_STREAM", 6, sa, if i = 0 then canon else ""),
                (2, c "AF_INET", c "SOCK_DGRAM", 17, sa, ""), (2, c "AF_INET", 3, 0, sa, "")]
            end
        in
          if af <> c "AF_INET" andalso af <> 0 then []
          else List.concat (List.tabulate (length addrs, fn i => entries (i, List.nth (addrs, i))))
        end

  (* ---- unix_specific.cpp: PolyOSSpecificGeneral *)
  (* 4: unixConstVec, the constants by their index; the modes of access, which
     are not among the machine's constants, are 4, 2, 1 and 0 wherever there
     is POSIX, and O_ACCMODE is 3 *)
  val unixConsts = Vector.fromList ["E2BIG", "EACCES", "EAGAIN", "EBADF", "EBADMSG", "EBUSY", "ECANCELED", "ECHILD", "EDEADLK", "EDOM", "EEXIST", "EFAULT", "EFBIG", "EINPROGRESS", "EINTR", "EINVAL", "EIO", "EISDIR", "ELOOP", "EMFILE", "EMLINK", "EMSGSIZE", "ENAMETOOLONG", "ENFILE", "ENODEV", "ENOENT", "ENOEXEC", "ENOLCK", "ENOMEM", "ENOSPC", "ENOSYS", "ENOTDIR", "ENOTEMPTY", "ENOTSUP", "ENOTTY", "ENXIO", "EPERM", "EPIPE", "ERANGE", "EROFS", "ESPIPE", "ESRCH", "EXDEV", "SIGABRT", "SIGALRM", "SIGBUS", "SIGFPE", "SIGHUP", "SIGILL", "SIGINT", "SIGKILL", "SIGPIPE", "SIGQUIT", "SIGSEGV", "SIGTERM", "SIGUSR1", "SIGUSR2", "SIGCHLD", "SIGCONT", "SIGSTOP", "SIGTSTP", "SIGTTIN", "SIGTTOU", "O_RDONLY", "O_WRONLY", "O_RDWR", "O_APPEND", "O_EXCL", "O_NOCTTY", "O_NONBLOCK", "O_SYNC", "O_TRUNC", "VEOF", "VEOL", "VERASE", "VINTR", "VKILL", "VMIN", "VQUIT", "VSUSP", "VTIME", "VSTART", "VSTOP", "NCCS", "BRKINT", "ICRNL", "IGNBRK", "IGNCR", "IGNPAR", "INLCR", "INPCK", "ISTRIP", "IXOFF", "IXON", "PARMRK", "OPOST", "CLOCAL", "CREAD", "CS5", "CS6", "CS7", "CS8", "CSIZE", "CSTOPB", "HUPCL", "PARENB", "PARODD", "ECHO", "ECHOE", "ECHOK", "ECHONL", "ICANON", "IEXTEN", "ISIG", "NOFLSH", "TOSTOP", "B0", "B50", "B75", "B110", "B134", "B150", "B200", "B300", "B600", "B1200", "B1800", "B2400", "B4800", "B9600", "B19200", "B38400", "FD_CLOEXEC", "WUNTRACED", "WNOHANG", "TCSANOW", "TCSADRAIN", "TCSAFLUSH", "TCOOFF", "TCOON", "TCIOFF", "TCION", "TCIFLUSH", "TCOFLUSH", "TCIOFLUSH", "S_IRUSR", "S_IWUSR", "S_IXUSR", "S_IRGRP", "S_IWGRP", "S_IXGRP", "S_IROTH", "S_IWOTH", "S_IXOTH", "S_ISUID", "S_ISGID", "R_OK", "W_OK", "X_OK", "F_OK", "SEEK_SET", "SEEK_CUR", "SEEK_END", "F_RDLCK", "F_WRLCK", "F_UNLCK", "O_ACCMODE"]
  fun constant n =
    case n of "R_OK" => 4 | "W_OK" => 2 | "X_OK" => 1 | "F_OK" => 0 | "O_ACCMODE" => 3
            | n => (case c n of ~1 => 0 | v => v)
  fun PolyOSSpecificGeneral_4 (i : int) : Word64.word =
    if i < 0 orelse i >= Vector.length unixConsts then raise R.SysErr ("Invalid index", SOME 0w0)
    else Word64.fromInt (constant (Vector.sub (unixConsts, i)))
  fun PolyOSSpecificGeneral_5 () : int = check (XC2Sys.fork ())
  fun PolyOSSpecificGeneral_6 (pid : int, sg : int) : unit = unit (XC2Sys.kill (pid, sg))
  fun PolyOSSpecificGeneral_7 () : int = XC2Sys.getpid ()
  fun PolyOSSpecificGeneral_8 () : int = XC2Sys.getppid ()
  fun PolyOSSpecificGeneral_9 () : int = XC2Sys.getuid ()
  fun PolyOSSpecificGeneral_10 () : int = XC2Sys.geteuid ()
  fun PolyOSSpecificGeneral_11 () : int = XC2Sys.getgid ()
  fun PolyOSSpecificGeneral_12 () : int = XC2Sys.getegid ()
  fun PolyOSSpecificGeneral_13 () : int = check (XC2Sys.getpgrp ())
  (* the status of waitpid, which the machine's primitive decodes *)
  fun encode (how, v) = case how of 0 => v * 256 | 1 => v | _ => v * 256 + 127
  (* 14: wait for any child (0), one (1), any of the group (2) or of a group
     (3); (0, 0) when WNOHANG finds none *)
  fun PolyOSSpecificGeneral_14 (kind : int, pid : int, flags : int) : int * int =
    let val p = case kind of 0 => ~1 | 1 => pid | 2 => 0 | _ => ~pid
    in case XC2Sys.waitpid (p, flags) of
         [0, _, _] => (0, 0)
       | [got, how, v] => (got, encode (how, v))
       | _ => syserr ()
    end
  (* 15 and 16: a status as (1 exited | 2 signalled | 3 stopped, value) *)
  fun PolyOSSpecificGeneral_15 (st : int) : int * int =
    if st mod 256 = 0 then (1, st div 256 mod 256)
    else if st mod 256 = 127 then (3, st div 256 mod 256)
    else (2, st mod 128)
  fun PolyOSSpecificGeneral_16 (k : int, v : int) : int =
    case k of 1 => v * 256 | 2 => v | 3 => v * 256 + 127 | _ => 0
  fun PolyOSSpecificGeneral_17 (p : string, args : string list) = (ignore (XC2Sys.exec (p, args, 0)); syserr ())
  fun PolyOSSpecificGeneral_18 (p : string, args : string list, env : string list) = (ignore (XC2Sys.exece (p, args, env)); syserr ())
  fun PolyOSSpecificGeneral_19 (p : string, args : string list) = (ignore (XC2Sys.exec (p, args, 1)); syserr ())
  (* 20: the timer in microseconds; the machine's alarm counts seconds *)
  fun PolyOSSpecificGeneral_20 (t : IntInf.int) : IntInf.int =
    let val secs = IntInf.toInt (IntInf.div (IntInf.+ (t, 999999), 1000000))
    in IntInf.* (IntInf.fromInt (XC2Sys.alarm secs), 1000000) end
  fun PolyOSSpecificGeneral_23 (u : int) : unit = unit (XC2Sys.setuid u)
  fun PolyOSSpecificGeneral_24 (g : int) : unit = unit (XC2Sys.setgid g)
  fun PolyOSSpecificGeneral_25 () : int list = XC2Sys.getgroups ()
  fun PolyOSSpecificGeneral_26 () : string = case XC2Sys.getlogin () of "" => syserr () | l => l
  fun PolyOSSpecificGeneral_27 () : int = check (XC2Sys.setsid ())
  fun PolyOSSpecificGeneral_28 (pid : int, pgid : int) : unit = unit (XC2Sys.setpgid (pid, pgid))
  fun PolyOSSpecificGeneral_29 () : (string * string) list =
    case XC2Sys.uname () of
      [sys, node, rel, ver, mach] =>
        [("machine", mach), ("version", ver), ("release", rel), ("nodename", node), ("sysname", sys)]
    | _ => syserr ()
  fun PolyOSSpecificGeneral_30 () : string = XC2Sys.ctermid ()
  fun PolyOSSpecificGeneral_31 (d : XC2P.iodesc) : string = case XC2Sys.ttyname (fd d) of "" => syserr () | t => t
  fun PolyOSSpecificGeneral_32 (d : XC2P.iodesc) : bool = let val f = XC2P.fdOf d in f <> ~1 andalso XC2Sys.isatty f = 1 end
  (* 33: sysconf of a name, with or without _SC_ *)
  fun PolyOSSpecificGeneral_33 (n : string) : int =
    let val n = if String.isPrefix "_SC_" n then String.extract (n, 4, NONE) else n
    in case XC2Sys.sysconf n of ~1 => raise R.SysErr ("sysconf argument not found", SOME (Word64.fromInt (c "EINVAL"))) | v => v end
  fun PolyOSSpecificGeneral_50 (m : int) : int = XC2Sys.umask m
  fun PolyOSSpecificGeneral_51 (old : string, new : string) : unit = unit (XC2Sys.link (old, new))
  (* 52: mkdir with a mode, which the machine's primitive does not take: the
     directory is made, then given the mode less the mask *)
  fun PolyOSSpecificGeneral_52 (p : string, mode : int) : unit =
    let
      val mask = XC2Sys.umask 0
      val _ = XC2Sys.umask mask
    in
      unit (XC2Sys.osMkdir p);
      unit (XC2Sys.chmod (p, ~1, Word.toInt (Word.andb (Word.fromInt mode, Word.notb (Word.fromInt mask)))))
    end
  fun PolyOSSpecificGeneral_53 (p : string, mode : int) : unit = unit (XC2Sys.mkfifo (p, mode))
  fun PolyOSSpecificGeneral_54 (old : string, new : string) : unit = unit (XC2Sys.symlink (old, new))
  (* 55-57: stat as getStatInfo makes it: the mode, the kind (0 regular, 1
     directory, 2 character, 3 block, 4 FIFO, 5 link, 6 socket), and the
     times in microseconds, of which the machine gives the seconds *)
  fun statInfo l =
    case l of
      [k, mode, ino, dev, nlink, uid, gid, size, at, mt, ct] =>
        let
          val kind = case k of 1 => 1 | 6 => 2 | 7 => 3 | 4 => 4 | 2 => 5 | 5 => 6 | _ => 0
          fun us s = IntInf.* (IntInf.fromInt s, 1000000)
        in
          (mode, kind, IntInf.fromInt ino, IntInf.fromInt dev, nlink, uid, gid, IntInf.fromInt size, us at, us mt, us ct)
        end
    | _ => syserr ()
  fun PolyOSSpecificGeneral_55 (p : string) = statInfo (XC2Sys.stat (p, 0, ~1))
  fun PolyOSSpecificGeneral_56 (p : string) = statInfo (XC2Sys.stat (p, 1, ~1))
  fun PolyOSSpecificGeneral_57 (d : XC2P.iodesc) = statInfo (XC2Sys.stat ("", 0, fd d))
  (* 58: access with the machine's bits; the shim's primitive takes 1 read, 2
     write, 4 execute *)
  fun PolyOSSpecificGeneral_58 (p : string, m : int) : bool =
    XC2Sys.osAccess (p, (if Int.rem (m div 4, 2) = 1 then 1 else 0) + (if Int.rem (m div 2, 2) = 1 then 2 else 0)
                        + (if Int.rem (m, 2) = 1 then 4 else 0), 0) = 1
  fun PolyOSSpecificGeneral_59 (p : string, mode : int) : unit = unit (XC2Sys.chmod (p, ~1, mode))
  fun PolyOSSpecificGeneral_60 (d : XC2P.iodesc, mode : int) : unit = unit (XC2Sys.chmod ("", fd d, mode))
  fun PolyOSSpecificGeneral_61 (p : string, u : int, g : int) : unit = unit (XC2Sys.chown (p, ~1, u, g))
  fun PolyOSSpecificGeneral_62 (d : XC2P.iodesc, u : int, g : int) : unit = unit (XC2Sys.chown ("", fd d, u, g))
  (* 63 and 64: utimes, to the second here *)
  fun PolyOSSpecificGeneral_63 (p : string, a : IntInf.int, m : IntInf.int) : unit =
    unit (XC2Sys.utime (p, IntInf.toInt (IntInf.div (a, 1000000)), IntInf.toInt (IntInf.div (m, 1000000))))
  fun PolyOSSpecificGeneral_64 (p : string) : unit =
    let val t = XC2Sys.timeNow () div 1000000 in unit (XC2Sys.utime (p, t, t)) end
  fun PolyOSSpecificGeneral_65 (d : XC2P.iodesc, n : IntInf.int) : unit = unit (XC2Sys.ftruncate (fd d, IntInf.toInt n))
  (* 66 and 67: pathconf of a name, with or without _PC_; ~1 for no limit *)
  fun pathconf (p, f, n) =
    let val n = if String.isPrefix "_PC_" n then String.extract (n, 4, NONE) else n
    in case XC2Sys.pathconf (p, f, n) of [v] => v | _ => syserr () end
  fun PolyOSSpecificGeneral_66 (p : string, n : string) : int = pathconf (p, ~1, n)
  fun PolyOSSpecificGeneral_67 (d : XC2P.iodesc, n : string) : int = pathconf ("", fd d, n)
  (* 100-103: the entries, ENOENT when there is none *)
  fun num s = getOpt (Int.fromString s, 0)
  fun pw l = case l of [n, dir, sh, u, g] => (n, num u, num g, dir, sh) | _ => failWith (c "ENOENT")
  fun gr l = case l of n :: g :: m => (n, num g, m) | _ => failWith (c "ENOENT")
  fun PolyOSSpecificGeneral_100 (n : string) = pw (if n = "" then [] else XC2Sys.getpw (n, 0))
  fun PolyOSSpecificGeneral_101 (u : int) = pw (XC2Sys.getpw ("", u))
  fun PolyOSSpecificGeneral_102 (n : string) = gr (if n = "" then [] else XC2Sys.getgr (n, 0))
  fun PolyOSSpecificGeneral_103 (g : int) = gr (XC2Sys.getgr ("", g))
  fun PolyOSSpecificGeneral_110 () : XC2P.iodesc * XC2P.iodesc =
    case XC2Sys.pipe () of [r, w] => (XC2P.wrapFd r, XC2P.wrapFd w) | _ => syserr ()
  fun PolyOSSpecificGeneral_111 (d : XC2P.iodesc) : XC2P.iodesc = XC2P.wrapFd (check (XC2Sys.dup (fd d)))
  fun PolyOSSpecificGeneral_112 (d : XC2P.iodesc, e : XC2P.iodesc) : unit = unit (XC2Sys.dup2 (fd d, fd e))
  (* 113: F_DUPFD, whose failure the runtime does not look at *)
  fun PolyOSSpecificGeneral_113 (d : XC2P.iodesc, e : XC2P.iodesc) : XC2P.iodesc =
    XC2P.wrapFd (XC2Sys.fcntl (fd d, c "F_DUPFD", fd e))
  fun PolyOSSpecificGeneral_114 (d : XC2P.iodesc) : int = check (XC2Sys.fcntl (fd d, c "F_GETFD", 0))
  fun PolyOSSpecificGeneral_115 (d : XC2P.iodesc, f : int) : unit = unit (XC2Sys.fcntl (fd d, c "F_SETFD", f))
  fun PolyOSSpecificGeneral_116 (d : XC2P.iodesc) : int = check (XC2Sys.fcntl (fd d, c "F_GETFL", 0))
  fun PolyOSSpecificGeneral_117 (d : XC2P.iodesc, f : int) : unit = unit (XC2Sys.fcntl (fd d, c "F_SETFL", f))
  fun PolyOSSpecificGeneral_118 (d : XC2P.iodesc, pos : IntInf.int, whence : int) : IntInf.int =
    case XC2Sys.lseek (fd d, IntInf.toInt pos, whence) of ~1 => syserr () | p => IntInf.fromInt p
  fun PolyOSSpecificGeneral_119 (d : XC2P.iodesc) : unit = unit (XC2Sys.fsync (fd d))
  fun lock cmd (d : XC2P.iodesc, t : int, w : int, s : IntInf.int, l : IntInf.int, _ : int) =
    case XC2Sys.lock (fd d, c cmd, t, w, IntInf.toInt s, IntInf.toInt l) of
      [t, w, st, ln, pid] => (t, w, IntInf.fromInt st, IntInf.fromInt ln, pid)
    | _ => syserr ()
  val PolyOSSpecificGeneral_120 = lock "F_GETLK"
  val PolyOSSpecificGeneral_121 = lock "F_SETLK"
  val PolyOSSpecificGeneral_122 = lock "F_SETLKW"
  (* 150 and 151: the terminal's attributes, the control characters a string *)
  fun PolyOSSpecificGeneral_150 (d : XC2P.iodesc) =
    case XC2Sys.tcgetattr (fd d) of
      i :: oflag :: cflag :: l :: is :: os :: cc => (i, oflag, cflag, l, CharVector.fromList (List.map Char.chr cc), is, os)
    | _ => syserr ()
  fun PolyOSSpecificGeneral_151 (d : XC2P.iodesc, sa : int, i : int, oflag : int, cflag : int, l : int, cc : string, is : int, os : int) : unit =
    if size cc <> c "NCCS" then failWith (c "EINVAL")
    else unit (XC2Sys.tcsetattr (fd d, sa, [i, oflag, cflag, l, is, os] @ List.map Char.ord (String.explode cc)))
  val tcop = _prim "posix_tcop" : int * int * int -> int
  fun PolyOSSpecificGeneral_152 (d : XC2P.iodesc, dur : int) : unit = unit (tcop (3, fd d, dur))
  fun PolyOSSpecificGeneral_153 (d : XC2P.iodesc) : unit = unit (tcop (0, fd d, 0))
  fun PolyOSSpecificGeneral_154 (d : XC2P.iodesc, q : int) : unit = unit (tcop (1, fd d, q))
  fun PolyOSSpecificGeneral_155 (d : XC2P.iodesc, a : int) : unit = unit (tcop (2, fd d, a))
  fun PolyOSSpecificGeneral_156 (d : XC2P.iodesc) : int = check (tcop (4, fd d, 0))
  fun PolyOSSpecificGeneral_157 (d : XC2P.iodesc, p : int) : unit = unit (tcop (5, fd d, p))

  fun PolyPosixCreatePersistentFD (f : int) : XC2P.iodesc = XC2P.wrapFd f
  (* PolyPosixSleep: wait up to the milliseconds for a signal, and give the
     count of those received; there are none here *)
  fun PolyPosixSleep (ms : int, count : int) : int =
    ((_prim "time_sleep" : int -> unit) (ms * 1000); count)
  (* PolyPollIODescriptors: poll, for up to the milliseconds; the result of
     a descriptor is one bit, the last of in, out and pri that is set *)
  fun PolyPollIODescriptors (dv : XC2P.iodesc vector, bv : word vector, ms : int) : word vector =
    let
      val fds = Vector.foldr (fn (d, l) => fd d :: l) [] dv
      val evs = Vector.foldr (fn (b, l) => Word.toInt (Word.andb (b, 0w7)) :: l) [] bv
      val got =
        if null fds then (ignore (XC2Sys.osPoll ([], [], ms * 1000)); [])
        else case XC2Sys.osPoll (fds, evs, ms * 1000) of [] => syserr () | l => l
    in
      Vector.fromList (List.map (fn r => if Int.rem (r div 4, 2) = 1 then 0w4 else if Int.rem (r div 2, 2) = 1 then 0w2
                                         else if Int.rem (r, 2) = 1 then 0w1 else 0w0) got)
    end
  (* PolyUnixExecute: the child's pid, and the pipes to its input and from
     its output; a child whose exec fails ends with 126 *)
  fun PolyUnixExecute (cmd : string, args : string list, env : string list) : int * XC2P.iodesc * XC2P.iodesc =
    let
      val (toR, toW) = case XC2Sys.pipe () of [r, w] => (r, w) | _ => syserr ()
      val (fromR, fromW) = case XC2Sys.pipe () of [r, w] => (r, w) | _ => (ignore (XC2Sys.close toR); ignore (XC2Sys.close toW); syserr ())
    in
      case XC2Sys.fork () of
        ~1 => syserr ()
      | 0 =>
          (ignore (XC2Sys.close toW); ignore (XC2Sys.close fromR);
           ignore (XC2Sys.dup2 (toR, 0)); ignore (XC2Sys.dup2 (fromW, 1));
           ignore (XC2Sys.close toR); ignore (XC2Sys.close fromW);
           ignore (XC2Sys.exece (cmd, args, env));
           XC2Sys.exit 126)
      | pid =>
          (ignore (XC2Sys.close toR); ignore (XC2Sys.close fromW);
           (pid, XC2P.wrapFd toW, XC2P.wrapFd fromR))
    end

  (* ---- timing.cpp: a time is a number of microseconds since 1970 *)
  fun PolyTimingTicksPerMicroSec () : IntInf.int = 1
  fun PolyTimingGetNow () : IntInf.int = IntInf.fromInt (XC2Sys.timeNow ())
  fun PolyTimingBaseYear () : int = 1970
  fun PolyTimingYearOffset () : int = 0
  val startTime = XC2Sys.timeNow ()
  fun PolyTimingGetReal () : IntInf.int = IntInf.fromInt (XC2Sys.timeNow () - startTime)
  fun us (n : int) : IntInf.int = IntInf.fromInt n
  fun PolyTimingGetUser () = us ((_prim "time_user" : unit -> int) ())
  fun PolyTimingGetSystem () = us ((_prim "time_sys" : unit -> int) ())
  fun PolyTimingGetGCUser () = us ((_prim "time_gc_user" : unit -> int) ())
  fun PolyTimingGetGCSystem () = us ((_prim "time_gc_sys" : unit -> int) ())
  fun PolyTimingGetChildUser () = us (List.nth (XC2Sys.times (), 3))
  fun PolyTimingGetChildSystem () = us (List.nth (XC2Sys.times (), 4))
  (* the seconds of UTC less those of the local time at the time t, as the
     broken-down times give them (Size when there is none) *)
  fun parts (t, loc) = case XC2Sys.dateParts (t, loc) of [] => raise R.Size | l => l
  fun PolyTimingLocalOffset (t : IntInf.int) : IntInf.int =
    let
      val t = IntInf.toInt t handle Overflow => raise R.Size
      fun secs l = (List.nth (l, 2) * 60 + List.nth (l, 1)) * 60 + List.nth (l, 0)
      val g = parts (t, 0) and l = parts (t, 1)
      val off = secs g - secs l
      val (gd, ld) = (List.nth (g, 7), List.nth (l, 7))
      val off = if gd = ld then off
                else if gd = ld + 1 orelse (gd = 0 andalso ld >= 364) then off + 86400
                else off - 86400
    in IntInf.fromInt off end
  fun PolyTimingSummerApplies (t : IntInf.int) : int =
    List.nth (parts (IntInf.toInt t handle Overflow => raise R.Size, 1), 8)
  (* strftime of the local time's zone; an empty result raises Size *)
  fun PolyTimingConvertDateStuct (fmt : string, year : int, month : int, day : int, hour : int,
                                  minute : int, second : int, wday : int, yday : int, isdst : int) =
    case XC2Sys.dateFormat (fmt, [second, minute, hour, day, month, year - 1900, wday, yday, isdst], 1) of
      "" => raise R.Size
    | s => s

  (* ---- arb.cpp: IntInf's; division truncates (quot) *)
  fun PolyAddArbitrary (i, j) = IntInf.+ (i, j)
  fun PolySubtractArbitrary (i, j) = IntInf.- (i, j)
  fun PolyMultiplyArbitrary (i, j) = IntInf.* (i, j)
  fun PolyDivideArbitrary (i, j) = IntInf.quot (i, j)
  fun PolyRemainderArbitrary (i, j) = IntInf.rem (i, j)
  fun PolyQuotRemArbitraryPair (i, j) = IntInf.quotRem (i, j)
  fun PolyCompareArbitrary (i, j) : int = case IntInf.compare (i, j) of LESS => ~1 | EQUAL => 0 | GREATER => 1
  fun PolyOrArbitrary (i, j) = IntInf.orb (i, j)
  fun PolyAndArbitrary (i, j) = IntInf.andb (i, j)
  fun PolyXorArbitrary (i, j) = IntInf.xorb (i, j)
  fun PolyShiftLeftArbitrary (i, w : word) = IntInf.<< (i, w)
  fun PolyShiftRightArbitrary (i, w : word) = IntInf.~>> (i, w)
  (* the position of the highest bit set, ~1 for 0 *)
  fun PolyLog2Arbitrary (i : IntInf.int) : int = if IntInf.<= (i, 0) then ~1 else IntInf.log2 i
  (* the low 64 bits *)
  fun PolyGetLowOrderAsLargeWord (i : IntInf.int) : Word64.word = Word64.fromLargeInt i

  (* ---- reals.cpp *)
  val PolyRealSqrt = Math.sqrt val PolyRealSin = Math.sin val PolyRealCos = Math.cos
  val PolyRealArctan = Math.atan val PolyRealExp = Math.exp val PolyRealLog = Math.ln
  val PolyRealTan = Math.tan val PolyRealArcSin = Math.asin val PolyRealArcCos = Math.acos
  val PolyRealLog10 = Math.log10 val PolyRealSinh = Math.sinh val PolyRealCosh = Math.cosh
  val PolyRealTanh = Math.tanh
  val PolyRealAtan2 = Math.atan2 val PolyRealPow = Math.pow
  val PolyRealCopySign = Real.copySign
  val PolyRealNextAfter = _prim "real_next_after" : real * real -> real
  val PolyRealFloor = Real.realFloor val PolyRealCeil = Real.realCeil
  val PolyRealTrunc = Real.realTrunc
  (* to the nearest, an even one of two *)
  val PolyRealRound = Real.realRound
  (* fmod *)
  val PolyRealRem = Real.rem
  val ldexp = _prim "real_ldexp" : real * int -> real
  fun PolyRealLdexp (x, e : int) = ldexp (x, e)
  (* frexp: the exponent and the fraction, in [0.5, 1) *)
  fun PolyRealFrexp (x : real) : int * real =
    if Real.== (x, 0.0) orelse not (Real.isFinite x) then (0, x)
    else let val {man, exp} = Real.toManExp x in (exp, man) end
  fun PolyFloatArbitraryPrecision (i : IntInf.int) = Real.fromLargeInt i
  (* the single-precision functions, in double precision and rounded *)
  fun f1 g (x : Real32.real) = Real32.fromLarge IEEEReal.TO_NEAREST (g (Real32.toLarge x))
  fun f2 g (x : Real32.real, y : Real32.real) = Real32.fromLarge IEEEReal.TO_NEAREST (g (Real32.toLarge x, Real32.toLarge y))
  val PolyRealFSqrt = f1 Math.sqrt val PolyRealFSin = f1 Math.sin val PolyRealFCos = f1 Math.cos
  val PolyRealFArctan = f1 Math.atan val PolyRealFExp = f1 Math.exp val PolyRealFLog = f1 Math.ln
  val PolyRealFTan = f1 Math.tan val PolyRealFArcSin = f1 Math.asin val PolyRealFArcCos = f1 Math.acos
  val PolyRealFLog10 = f1 Math.log10 val PolyRealFSinh = f1 Math.sinh val PolyRealFCosh = f1 Math.cosh
  val PolyRealFTanh = f1 Math.tanh
  val PolyRealFAtan2 = f2 Math.atan2 val PolyRealFPow = f2 Math.pow
  val PolyRealFCopySign = f2 Real.copySign
  val PolyRealFFloor = f1 Real.realFloor val PolyRealFCeil = f1 Real.realCeil
  val PolyRealFTrunc = f1 Real.realTrunc val PolyRealFRound = f1 Real.realRound
  val PolyRealFRem = f2 Real.rem
  fun PolyRealFNextAfter (x : Real32.real, y : Real32.real) = Real32.nextAfter (x, y)
  (* the rounding modes, 0 nearest, 1 down, 2 up, 3 to zero, which are the
     machine's; setting gives 0, or ~1 for a mode it does not know *)
  val getRound = _prim "real_get_round" : unit -> int
  val setRound = _prim "real_set_round" : int -> unit
  fun PolyGetRoundingMode () = getRound ()
  fun PolySetRoundingMode (m : int) = if m >= 0 andalso m <= 3 then (setRound m; 0) else ~1
  (* PolyRealDoubleToString: C's snprintf with %1.*E, %1.*F or %1.*G, then
     ~ for -, no +, and the exponent without its leading zeros *)
  val fmtE = _prim "real_fmt_e" : real * int -> string
  val fmtF = _prim "real_fmt_f" : real * int -> string
  fun cprintf (conv, p, x) =
    if Real.isNan x then (if Real.signBit x then "-NAN" else "NAN")
    else if not (Real.isFinite x) then (if x < 0.0 then "-INF" else "INF")
    else
      case conv of
        #"E" => fmtE (x, p)
      | #"F" => fmtF (x, p)
      | _ =>
          let
            val p = if p = 0 then 1 else p
            fun parts t = case String.fields (fn c => c = #"e") t of [m, ex] => (m, ex) | _ => (t, "0")
            fun expOf ex = valOf (Int.fromString (String.translate (fn #"+" => "" | #"-" => "~" | c => str c) ex))
            val e = expOf (#2 (parts (fmtE (x, p - 1))))
            fun trim t =
              if not (CharVector.exists (fn c => c = #".") t) then t
              else Substring.string (Substring.dropr (fn c => c = #".") (Substring.dropr (fn c => c = #"0") (Substring.full t)))
          in
            if e < p andalso e >= ~4 then trim (fmtF (x, p - 1 - e))
            else let val (m, ex) = parts (fmtE (x, p - 1)) in trim m ^ "e" ^ ex end
          end
  fun PolyRealDoubleToString (x : real, kind : char, p : int) : string =
    let
      val conv = case kind of #"e" => #"E" | #"E" => #"E" | #"f" => #"F" | #"F" => #"F" | _ => #"G"
      val s = cprintf (conv, p, x)
      fun finish (acc, sz) = String.implode (List.rev (if sz then #"0" :: acc else acc))
      fun run (l, sz, acc) =
        case l of
          [] => finish (acc, sz)
        | ch :: r =>
            (case ch of
               #"-" => run (r, sz, #"~" :: acc)
             | #"+" => run (r, sz, acc)
             | #"e" => run (r, true, #"E" :: acc)
             | #"E" => run (r, true, #"E" :: acc)
             | #"0" => run (r, sz, if sz then acc else #"0" :: acc)
             | ch => run (r, false, ch :: acc))
    in run (String.explode s, false, []) end
end
