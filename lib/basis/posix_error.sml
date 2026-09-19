(* Posix.Error: the errors the system reports. A syserror is an errno value,
   the same one OS.SysErr carries. *)
structure RunePosixError =
struct
  type syserror = RuneError.syserror

  local
    val const = _prim "posix_const" : string -> int
    (* The names of POSIX, and the names the C library gives them. *)
    val table =
      [("toobig", "E2BIG"), ("acces", "EACCES"), ("addrinuse", "EADDRINUSE"),
       ("addrnotavail", "EADDRNOTAVAIL"), ("afnosupport", "EAFNOSUPPORT"), ("again", "EAGAIN"),
       ("already", "EALREADY"), ("badf", "EBADF"), ("badmsg", "EBADMSG"), ("busy", "EBUSY"),
       ("canceled", "ECANCELED"), ("child", "ECHILD"), ("connaborted", "ECONNABORTED"),
       ("connrefused", "ECONNREFUSED"), ("connreset", "ECONNRESET"), ("deadlk", "EDEADLK"),
       ("destaddrreq", "EDESTADDRREQ"), ("dom", "EDOM"), ("dquot", "EDQUOT"), ("exist", "EEXIST"),
       ("fault", "EFAULT"), ("fbig", "EFBIG"), ("hostunreach", "EHOSTUNREACH"), ("idrm", "EIDRM"),
       ("ilseq", "EILSEQ"), ("inprogress", "EINPROGRESS"), ("intr", "EINTR"), ("inval", "EINVAL"),
       ("io", "EIO"), ("isconn", "EISCONN"), ("isdir", "EISDIR"), ("loop", "ELOOP"),
       ("mfile", "EMFILE"), ("mlink", "EMLINK"), ("msgsize", "EMSGSIZE"), ("multihop", "EMULTIHOP"),
       ("nametoolong", "ENAMETOOLONG"), ("netdown", "ENETDOWN"), ("netreset", "ENETRESET"),
       ("netunreach", "ENETUNREACH"), ("nfile", "ENFILE"), ("nobufs", "ENOBUFS"),
       ("nodev", "ENODEV"), ("noent", "ENOENT"), ("noexec", "ENOEXEC"), ("nolck", "ENOLCK"),
       ("nolink", "ENOLINK"), ("nomem", "ENOMEM"), ("nomsg", "ENOMSG"), ("noprotoopt", "ENOPROTOOPT"),
       ("nospc", "ENOSPC"), ("nosys", "ENOSYS"), ("notconn", "ENOTCONN"), ("notdir", "ENOTDIR"),
       ("notempty", "ENOTEMPTY"), ("notsock", "ENOTSOCK"), ("notsup", "ENOTSUP"), ("notty", "ENOTTY"),
       ("nxio", "ENXIO"), ("overflow", "EOVERFLOW"), ("perm", "EPERM"), ("pipe", "EPIPE"),
       ("proto", "EPROTO"), ("protonosupport", "EPROTONOSUPPORT"), ("prototype", "EPROTOTYPE"),
       ("range", "ERANGE"), ("rofs", "EROFS"), ("spipe", "ESPIPE"), ("srch", "ESRCH"),
       ("stale", "ESTALE"), ("timedout", "ETIMEDOUT"), ("txtbsy", "ETXTBSY"), ("xdev", "EXDEV")]
  in
    fun toWord (e : syserror) = Word.fromInt e
    fun fromWord w = Word.toInt w
    val errorMsg = RuneError.errorMsg
    fun errorName e =
      let
        val cName = RuneError.errorName e
        fun go [] = cName
          | go ((name, c) :: rest) = if c = cName then name else go rest
      in go table end
    fun syserror name =
      let
        fun go [] = NONE
          | go ((n, c) :: rest) = if n = name then (case const c of ~1 => NONE | v => SOME v) else go rest
      in go table end

    (* The named errors, as the specification lists them. *)
    fun named name = case syserror name of SOME e => e | NONE => 0
    val noerr = 0
    val toobig = named "toobig"       val acces = named "acces"
    val addrinuse = named "addrinuse" val addrnotavail = named "addrnotavail"
    val afnosupport = named "afnosupport" val again = named "again"
    val already = named "already"     val badf = named "badf"
    val badmsg = named "badmsg"       val busy = named "busy"
    val canceled = named "canceled"   val child = named "child"
    val connaborted = named "connaborted" val connrefused = named "connrefused"
    val connreset = named "connreset" val deadlk = named "deadlk"
    val destaddrreq = named "destaddrreq" val dom = named "dom"
    val dquot = named "dquot"         val exist = named "exist"
    val fault = named "fault"         val fbig = named "fbig"
    val hostunreach = named "hostunreach" val idrm = named "idrm"
    val ilseq = named "ilseq"         val inprogress = named "inprogress"
    val intr = named "intr"           val inval = named "inval"
    val io = named "io"               val isconn = named "isconn"
    val isdir = named "isdir"         val loop = named "loop"
    val mfile = named "mfile"         val mlink = named "mlink"
    val msgsize = named "msgsize"     val multihop = named "multihop"
    val nametoolong = named "nametoolong" val netdown = named "netdown"
    val netreset = named "netreset"   val netunreach = named "netunreach"
    val nfile = named "nfile"         val nobufs = named "nobufs"
    val nodev = named "nodev"         val noent = named "noent"
    val noexec = named "noexec"       val nolck = named "nolck"
    val nolink = named "nolink"       val nomem = named "nomem"
    val nomsg = named "nomsg"         val noprotoopt = named "noprotoopt"
    val nospc = named "nospc"         val nosys = named "nosys"
    val notconn = named "notconn"     val notdir = named "notdir"
    val notempty = named "notempty"   val notsock = named "notsock"
    val notsup = named "notsup"       val notty = named "notty"
    val nxio = named "nxio"           val overflow = named "overflow"
    val perm = named "perm"           val pipe = named "pipe"
    val proto = named "proto"         val protonosupport = named "protonosupport"
    val prototype = named "prototype" val range = named "range"
    val rofs = named "rofs"           val spipe = named "spipe"
    val srch = named "srch"           val stale = named "stale"
    val timedout = named "timedout"   val txtbsy = named "txtbsy"
    val xdev = named "xdev"
  end
end
