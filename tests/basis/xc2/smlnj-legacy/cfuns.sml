(* The C functions of SML/NJ's runtime (base/runtime/c-libs), which its
   library binds with CInterface.c_function "LIB" "NAME" and rewrite.awk
   names XC2NC.LIB_NAME, made of the primitives of Rune's machine. They
   are typed where the library binds them: an s_int is an int, an s_word
   and a SysWord.word a Word64.word, a Position.int an Int64.int, a
   Word8Vector.vector a string. A call that fails raises SysErr with C's
   errno, as the runtime's RAISE_SYSERR does; one the shim does not make
   raises XC2.Unimplemented (the generated stubs). *)
structure XC2NCImpl =
struct
  val w64 = Word64.fromInt
  (* SML/NJ passes all ones for "no change" (an owner, a time): signed *)
  val w64i = Word64.toIntX
  val i64 = Int64.fromInt
  val i64i = Int64.toInt
  val c = XC2Sys.posixConst
  (* RAISE_SYSERR and RAISE_ERROR *)
  fun syserr () = let val e = XC2Sys.sysErrno () in raise XC2N.SysErr (XC2Sys.errorMsg e, SOME e) end
  fun error msg = raise XC2N.SysErr (msg, NONE)
  fun check (r : int) = if r = ~1 then syserr () else r
  fun unit (r : int) = ignore (check r)
  (* a table of named constants, the machine's value of each name *)
  fun osval (names : (string * string) list) (name : string) : int =
    case List.find (fn (n, _) => n = name) names of
      NONE => error "system constant not defined"
    | SOME (_, cname) => (case c cname of ~1 => 0 | v => v)

  (* ---- POSIX-Error: the names of errno, as the runtime's table has them *)
  val errnos =
    [("EACCES", "acces"), ("EAGAIN", "again"), ("EWOULDBLOCK", "wouldblock"), ("EBADF", "badf"),
     ("EBADMSG", "badmsg"), ("EBUSY", "busy"), ("ECANCELED", "canceled"), ("ECHILD", "child"),
     ("EDEADLK", "deadlk"), ("EDOM", "dom"), ("EEXIST", "exist"), ("EFAULT", "fault"), ("EFBIG", "fbig"),
     ("EINPROGRESS", "inprogress"), ("EINTR", "intr"), ("EINVAL", "inval"), ("EIO", "io"),
     ("EISDIR", "isdir"), ("ELOOP", "loop"), ("EMFILE", "mfile"), ("EMLINK", "mlink"),
     ("EMSGSIZE", "msgsize"), ("ENAMETOOLONG", "nametoolong"), ("ENFILE", "nfile"), ("ENODEV", "nodev"),
     ("ENOENT", "noent"), ("ENOEXEC", "noexec"), ("ENOLCK", "nolck"), ("ENOMEM", "nomem"),
     ("ENOSPC", "nospc"), ("ENOSYS", "nosys"), ("ENOTDIR", "notdir"), ("ENOTEMPTY", "notempty"),
     ("ENOTSUP", "notsup"), ("ENOTTY", "notty"), ("ENXIO", "nxio"), ("EPERM", "perm"), ("EPIPE", "pipe"),
     ("ERANGE", "range"), ("EROFS", "rofs"), ("ESPIPE", "spipe"), ("ESRCH", "srch"), ("E2BIG", "toobig"),
     ("EXDEV", "xdev")]
  val errorTable = List.filter (fn (v, _) => v <> ~1) (List.map (fn (cn, n) => (c cn, n)) errnos)
  fun POSIX_Error_listerrors () = errorTable
  fun POSIX_Error_geterror (e : int) =
    case List.find (fn (v, _) => v = e) errorTable of SOME x => x | NONE => (~1, "<UNKNOWN>")
  val POSIX_Error_errmsg = XC2Sys.errorMsg

  (* ---- the constants of the libraries *)
  val POSIX_Signal_osval = osval
    (List.map (fn n => (n, "SIG" ^ String.map Char.toUpper n))
       ["abrt", "alrm", "bus", "chld", "cont", "fpe", "hup", "ill", "int", "kill", "pipe", "quit",
        "segv", "stop", "term", "tstp", "ttin", "ttou", "usr1", "usr2"])
  val fsval = osval
    (List.map (fn n => (n, n)) ["O_APPEND", "O_CREAT", "O_DSYNC", "O_EXCL", "O_NOCTTY", "O_NONBLOCK",
                                "O_RDONLY", "O_RDWR", "O_RSYNC", "O_SYNC", "O_TRUNC", "O_WRONLY"]
     @ List.map (fn n => (n, "S_" ^ String.map Char.toUpper n))
         ["irgrp", "iroth", "irusr", "irwxg", "irwxo", "irwxu", "isgid", "isuid", "iwgrp", "iwoth",
          "iwusr", "ixgrp", "ixoth", "ixusr"])
  (* the modes of access, which are not among the machine's constants: F_OK,
     R_OK, W_OK and X_OK are 0, 4, 2 and 1 wherever there is POSIX *)
  val accessModes = [("A_FILE", 0), ("A_READ", 4), ("A_WRITE", 2), ("A_EXEC", 1)]
  fun POSIX_FileSys_osval name =
    case List.find (fn (n, _) => n = name) accessModes of SOME (_, v) => v | NONE => fsval name
  val POSIX_IO_osval = osval
    ([("F_GETLK", "F_GETLK"), ("F_RDLCK", "F_RDLCK"), ("F_SETLK", "F_SETLK"), ("F_SETLKW", "F_SETLKW"),
      ("F_UNLCK", "F_UNLCK"), ("F_WRLCK", "F_WRLCK"), ("SEEK_CUR", "SEEK_CUR"), ("SEEK_END", "SEEK_END"),
      ("SEEK_SET", "SEEK_SET"), ("append", "O_APPEND"), ("cloexec", "FD_CLOEXEC"), ("dsync", "O_DSYNC"),
      ("nonblock", "O_NONBLOCK"), ("rsync", "O_RSYNC"), ("sync", "O_SYNC")])
  val POSIX_Process_osval = osval [("WNOHANG", "WNOHANG"), ("WUNTRACED", "WUNTRACED")]
  val POSIX_TTY_osval = osval
    (List.map (fn n => (n, n))
       ["B0", "B110", "B1200", "B134", "B150", "B1800", "B19200", "B200", "B2400", "B300", "B38400",
        "B4800", "B50", "B600", "B75", "B9600", "BRKINT", "CLOCAL", "CREAD", "CS5", "CS6", "CS7", "CS8",
        "CSIZE", "CSTOPB", "ECHO", "ECHOE", "ECHOK", "ECHONL", "HUPCL", "ICANON", "ICRNL", "IEXTEN",
        "IGNBRK", "IGNCR", "IGNPAR", "INLCR", "INPCK", "ISIG", "ISTRIP", "IXOFF", "IXON", "NCCS",
        "NOFLSH", "OPOST", "PARENB", "PARMRK", "PARODD", "TCIFLUSH", "TCIOFF", "TCIOFLUSH", "TCION",
        "TCOFLUSH", "TCOOFF", "TCOON", "TCSADRAIN", "TCSAFLUSH", "TCSANOW", "TOSTOP"]
     @ [("EOF", "VEOF"), ("EOL", "VEOL"), ("ERASE", "VERASE"), ("INTR", "VINTR"), ("KILL", "VKILL"),
        ("MIN", "VMIN"), ("QUIT", "VQUIT"), ("START", "VSTART"), ("STOP", "VSTOP"), ("SUSP", "VSUSP"),
        ("TIME", "VTIME")])

  (* ---- POSIX-ProcEnv *)
  fun POSIX_ProcEnv_getpid () = XC2Sys.getpid ()
  fun POSIX_ProcEnv_getppid () = XC2Sys.getppid ()
  fun POSIX_ProcEnv_getuid () = w64 (XC2Sys.getuid ())
  fun POSIX_ProcEnv_geteuid () = w64 (XC2Sys.geteuid ())
  fun POSIX_ProcEnv_getgid () = w64 (XC2Sys.getgid ())
  fun POSIX_ProcEnv_getegid () = w64 (XC2Sys.getegid ())
  fun POSIX_ProcEnv_setuid (u : Word64.word) = unit (XC2Sys.setuid (w64i u))
  fun POSIX_ProcEnv_setgid (g : Word64.word) = unit (XC2Sys.setgid (w64i g))
  fun POSIX_ProcEnv_getgroups () = List.map w64 (XC2Sys.getgroups ())
  fun POSIX_ProcEnv_getlogin () = case XC2Sys.getlogin () of "" => error "no login name" | s => s
  fun POSIX_ProcEnv_getpgrp () = XC2Sys.getpgrp ()
  fun POSIX_ProcEnv_setsid () = check (XC2Sys.setsid ())
  fun POSIX_ProcEnv_setpgid (p : int, g : int) = unit (XC2Sys.setpgid (p, g))
  fun POSIX_ProcEnv_uname () =
    case XC2Sys.uname () of
      [a, b, cc, d, e] => [("sysname", a), ("nodename", b), ("release", cc), ("version", d), ("machine", e)]
    | _ => syserr ()
  fun POSIX_ProcEnv_sysconf (name : string) : Word64.word =
    case XC2Sys.sysconf name of ~1 => (if XC2Sys.sysErrno () = 0 then error "unsupported POSIX feature" else syserr ()) | v => w64 v
  fun POSIX_ProcEnv_time () : Int32.int = Int32.fromInt (XC2Sys.timeNow () div 1000000)
  (* in clock ticks: the machine's times are microseconds *)
  fun POSIX_ProcEnv_times () =
    case XC2Sys.times () of
      [e, u, s, cu, cs] =>
        let val tck = XC2Sys.sysconf "CLK_TCK"
            fun t us = Int32.fromInt (us * tck div 1000000)
        in (t e, t u, t s, t cu, t cs) end
    | _ => syserr ()
  fun POSIX_ProcEnv_getenv (name : string) = XC2Sys.getenv name
  fun POSIX_ProcEnv_environ () = XC2Sys.environ ()
  fun POSIX_ProcEnv_ctermid () = XC2Sys.ctermid ()
  fun POSIX_ProcEnv_ttyname (fd : int) = case XC2Sys.ttyname fd of "" => syserr () | s => s
  fun POSIX_ProcEnv_isatty (fd : int) = XC2Sys.isatty fd = 1

  (* ---- POSIX-Process *)
  fun POSIX_Process_fork () = check (XC2Sys.fork ())
  fun POSIX_Process_exec (path : string, args : string list) = (unit (XC2Sys.exec (path, args, 0)); raise Fail "xc2: exec returned")
  fun POSIX_Process_execp (path : string, args : string list) = (unit (XC2Sys.exec (path, args, 1)); raise Fail "xc2: exec returned")
  fun POSIX_Process_exece (path : string, args : string list, env : string list) =
    (unit (XC2Sys.exece (path, args, env)); raise Fail "xc2: exec returned")
  fun POSIX_Process_waitpid (pid : int, flags : Word64.word) =
    case XC2Sys.waitpid (pid, w64i flags) of [p, how, v] => (p, how, v) | _ => syserr ()
  fun POSIX_Process_exit (status : Word8.word) = XC2Sys.exit (Word8.toInt status)
  fun POSIX_Process_kill (pid : int, s : int) = unit (XC2Sys.kill (pid, s))
  (* alarm.c and sleep.c: times in nanoseconds; alarm in whole seconds,
     sleep (nanosleep) to the microsecond here, with nothing left over *)
  fun POSIX_Process_alarm (ns : Word64.word) =
    Word64.* (w64 (XC2Sys.alarm (w64i (Word64.div (ns, 0w1000000000)))), 0w1000000000)
  fun POSIX_Process_pause () = ignore (XC2Sys.pause ())
  fun POSIX_Process_sleep (ns : Word64.word) =
    ((_prim "time_sleep" : int -> unit) (w64i (Word64.div (ns, 0w1000))); 0w0 : Word64.word)

  (* ---- POSIX-FileSys: stat as mkStatRep of stat.c makes it -- the file
     type as its S_IF bits, the permissions, and the times in nanoseconds *)
  fun kindBits k = case k of 0 => 0x8000 | 1 => 0x4000 | 2 => 0xA000 | 4 => 0x1000 | 5 => 0xC000
                           | 6 => 0x2000 | 7 => 0x6000 | _ => 0
  fun ns s = Word64.* (w64 s, 0w1000000000)
  fun statrep l =
    case l of
      kind :: mode :: ino :: dev :: nlink :: uid :: gid :: sz :: at :: mt :: ct :: _ =>
        (kindBits kind, w64 (mode mod 4096), w64 ino, w64 dev, w64 nlink, w64 uid, w64 gid, i64 sz, ns at, ns mt, ns ct)
    | _ => syserr ()
  fun POSIX_FileSys_stat (p : string) = statrep (XC2Sys.stat (p, 0, ~1))
  fun POSIX_FileSys_lstat (p : string) = statrep (XC2Sys.stat (p, 1, ~1))
  fun POSIX_FileSys_fstat (fd : int) = statrep (XC2Sys.stat ("", 0, fd))
  (* C's R_OK, W_OK and X_OK (4, 2, 1) are the machine's 1, 2 and 4 *)
  fun POSIX_FileSys_access (p : string, m : Word64.word) =
    let val m = w64i m
    in XC2Sys.osAccess (p, (if m div 4 mod 2 = 1 then 1 else 0) + (if m div 2 mod 2 = 1 then 2 else 0)
                           + (if m mod 2 = 1 then 4 else 0), 0) = 1
    end
  fun POSIX_FileSys_chdir (p : string) = unit (XC2Sys.osChdir p)
  fun POSIX_FileSys_getcwd () = case XC2Sys.osGetcwd () of "" => syserr () | d => d
  fun POSIX_FileSys_chmod (p : string, m : Word64.word) = unit (XC2Sys.chmod (p, ~1, w64i m))
  fun POSIX_FileSys_fchmod (fd : int, m : Word64.word) = unit (XC2Sys.chmod ("", fd, w64i m))
  fun POSIX_FileSys_chown (p : string, u : Word64.word, g : Word64.word) = unit (XC2Sys.chown (p, ~1, w64i u, w64i g))
  fun POSIX_FileSys_fchown (fd : int, u : Word64.word, g : Word64.word) = unit (XC2Sys.chown ("", fd, w64i u, w64i g))
  fun POSIX_FileSys_ftruncate (fd : int, n : Int64.int) = unit (XC2Sys.ftruncate (fd, i64i n))
  fun POSIX_FileSys_link (a : string, b : string) = unit (XC2Sys.link (a, b))
  fun POSIX_FileSys_symlink (a : string, b : string) = unit (XC2Sys.symlink (a, b))
  fun POSIX_FileSys_readlink (p : string) = case XC2Sys.osReadLink p of "" => syserr () | s => s
  fun POSIX_FileSys_rename (a : string, b : string) = unit (XC2Sys.osRename (a, b))
  fun POSIX_FileSys_rmdir (p : string) = unit (XC2Sys.osRmdir p)
  fun POSIX_FileSys_unlink (p : string) = unit (XC2Sys.osRemove p)
  (* mkdir (p, mode): the mode less the umask *)
  fun POSIX_FileSys_mkdir (p : string, m : Word64.word) =
    let val mask = XC2Sys.umask 0
        val _ = XC2Sys.umask mask
    in
      unit (XC2Sys.osMkdir p);
      unit (XC2Sys.chmod (p, ~1, Word.toInt (Word.andb (Word.fromInt (w64i m), Word.notb (Word.fromInt mask)))))
    end
  fun POSIX_FileSys_mkfifo (p : string, m : Word64.word) = unit (XC2Sys.mkfifo (p, w64i m))
  fun POSIX_FileSys_umask (m : Word64.word) = w64 (XC2Sys.umask (w64i m))
  fun POSIX_FileSys_openf (p : string, flags : Word64.word, mode : Word64.word) = check (XC2Sys.openf (p, w64i flags, w64i mode))
  fun dirOf (PrimTypes.XC2NDir d) = d
    | dirOf _ = error "not a directory stream"
  fun POSIX_FileSys_opendir (p : string) = case XC2Sys.osOpenDir p of ~1 => syserr () | d => PrimTypes.XC2NDir d
  (* the next name, "" at the end (readdir.c) *)
  fun POSIX_FileSys_readdir (d : PrimTypes.object) =
    case XC2Sys.osReadDir (dirOf d) of SOME n => n | NONE => (if XC2Sys.sysErrno () <> 0 then syserr () else "")
  fun POSIX_FileSys_rewinddir (d : PrimTypes.object) = unit (XC2Sys.osRewindDir (dirOf d))
  fun POSIX_FileSys_closedir (d : PrimTypes.object) = unit (XC2Sys.osCloseDir (dirOf d))
  (* NONE for no limit *)
  fun pathconf (p, fd, name) =
    case XC2Sys.pathconf (p, fd, name) of [~1] => NONE | [v] => SOME (w64 v) | _ => syserr ()
  fun POSIX_FileSys_pathconf (p : string, name : string) = pathconf (p, ~1, name)
  fun POSIX_FileSys_fpathconf (fd : int, name : string) = pathconf ("", fd, name)
  (* the times in nanoseconds; all ones for now *)
  fun POSIX_FileSys_utime (p : string, a : Word64.word, m : Word64.word) =
    if a = 0wxFFFFFFFFFFFFFFFF then let val t = XC2Sys.timeNow () div 1000000 in unit (XC2Sys.utime (p, t, t)) end
    else unit (XC2Sys.utime (p, Word64.toInt (Word64.div (a, 0w1000000000)), Word64.toInt (Word64.div (m, 0w1000000000))))
  (* tmpname.c: mkstemp of /tmp/SMLNJ-XXXXXX, the file closed *)
  fun POSIX_OS_tmpname () =
    let
      val letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
      fun name k = "/tmp/SMLNJ-" ^ CharVector.tabulate (6, fn i => String.sub (letters, (k div (i + 1) + 7 * i) mod 62))
      fun try k =
        let val p = name (XC2Sys.timeNow () + k * 7919)
        in case XC2Sys.openf (p, c "O_RDWR" + c "O_CREAT" + c "O_EXCL", 384) of
             ~1 => if k < 100 then try (k + 1) else syserr ()
           | fd => (ignore (XC2Sys.close fd); p)
        end
    in try 0 end

  (* ---- POSIX-IO *)
  fun POSIX_IO_close (fd : int) = unit (XC2Sys.close fd)
  fun POSIX_IO_dup (fd : int) = check (XC2Sys.dup fd)
  fun POSIX_IO_dup2 (a : int, b : int) = unit (XC2Sys.dup2 (a, b))
  fun POSIX_IO_fcntl_d (fd : int, base : int) = check (XC2Sys.fcntl (fd, c "F_DUPFD", base))
  fun POSIX_IO_fcntl_gfd (fd : int) = w64 (check (XC2Sys.fcntl (fd, c "F_GETFD", 0)))
  fun POSIX_IO_fcntl_sfd (fd : int, f : Word64.word) = unit (XC2Sys.fcntl (fd, c "F_SETFD", w64i f))
  (* the flags and the access mode; fcntl_gfl.c asks F_GETFD for them, not
     F_GETFL, and so does this *)
  fun POSIX_IO_fcntl_gfl (fd : int) =
    let
      val f = Word64.fromInt (check (XC2Sys.fcntl (fd, c "F_GETFD", 0)))
      val acc = case c "O_ACCMODE" of ~1 => 0w3 | a => w64 a
    in (Word64.andb (f, Word64.notb acc), Word64.andb (f, acc)) end
  fun POSIX_IO_fcntl_sfl (fd : int, f : Word64.word) = unit (XC2Sys.fcntl (fd, c "F_SETFL", w64i f))
  fun POSIX_IO_fcntl_l (fd : int, cmd : int, (typ : int, whence : int, start : Int64.int, len : Int64.int, _ : int)) =
    case XC2Sys.lock (fd, cmd, typ, whence, i64i start, i64i len) of
      [t, w, st, l, pid] => (t, w, i64 st, i64 l, pid)
    | _ => syserr ()
  fun POSIX_IO_fsync (fd : int) = unit (XC2Sys.fsync fd)
  fun POSIX_IO_lseek (fd : int, off : Int64.int, whence : int) =
    case XC2Sys.lseek (fd, i64i off, whence) of ~1 => syserr () | p => i64 p
  fun POSIX_IO_pipe () = case XC2Sys.pipe () of [r, w] => (r, w) | _ => syserr ()
  fun POSIX_IO_read (fd : int, n : int) : string =
    if n = 0 then ""
    else case XC2Sys.read (fd, n) of "" => (if XC2Sys.sysErrno () <> 0 then syserr () else "") | s => s
  fun POSIX_IO_readbuf (fd : int, a : Word8.word array, n : int, off : int) =
    let val s = POSIX_IO_read (fd, n)
    in CharVector.appi (fn (i, ch) => Array.update (a, off + i, Word8.fromInt (Char.ord ch))) s; size s end
  fun POSIX_IO_writebuf (fd : int, v : string, n : int, off : int) = check (XC2Sys.write (fd, String.substring (v, off, n)))

  (* ---- SMLNJ-Signals: the signals of the runtime's table (unix-signals.c)
     that the machine has, and GC, the runtime's own; each in its default
     state, as no handler is installed (signal handlers are not made) *)
  val signals =
    List.filter (fn (v, _) => v <> ~1)
      (List.map (fn n => (c ("SIG" ^ n), n))
         ["HUP", "INT", "QUIT", "ALRM", "TERM", "PIPE", "USR1", "USR2", "CHLD", "WINCH", "URG", "IO",
          "TSTP", "CONT", "TTIN", "TTOU", "VTALRM"])
    @ [(65, "GC")]
  fun SMLNJ_Signals_listSignals () = signals
  fun SMLNJ_Signals_getSigState (_ : int * string) = 1
  fun SMLNJ_Signals_setSigState (_ : (int * string) * int) = ()
  fun SMLNJ_Signals_getSigMask () : (int * string) list option = NONE
  fun SMLNJ_Signals_setSigMask (_ : (int * string) list option) = ()
  fun SMLNJ_Signals_pause () = ignore (XC2Sys.pause ())

  (* ---- SMLNJ-Sockets: the kinds of socket and address families of the
     runtime's tables (tbl-sock-type.c, tbl-addr-family.c) that the machine
     has *)
  fun known l = List.filter (fn (v, _) => v <> ~1) (List.map (fn (cn, n) => (c cn, n)) l)
  val sockTypes = known [("SOCK_STREAM", "STREAM"), ("SOCK_DGRAM", "DGRAM")]
  val addrFamilies = known [("AF_UNIX", "UNIX"), ("AF_INET", "INET")]
  fun SMLNJ_Sockets_listSockTypes () = sockTypes
  fun SMLNJ_Sockets_listAddrFamilies () = addrFamilies
  (* ML_SysConst: the entry of a table, or (~1, "<UNKNOWN>") *)
  fun sysConst tbl (v : int) = case List.find (fn (x, _) => x = v) tbl of SOME e => e | NONE => (~1, "<UNKNOWN>")
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
    val unixAddr = _prim "socket_unix_addr" : string -> string
    val hostByName = _prim "netdb_host_byname" : string -> string list
    val hostByAddr = _prim "netdb_host_byaddr" : string -> string list
    val hostname = _prim "netdb_hostname" : unit -> string
    val protoByName = _prim "netdb_proto_byname" : string -> string list
    val protoByNumber = _prim "netdb_proto_bynumber" : int -> string list
    val servByName = _prim "netdb_serv_byname" : string * string -> string list
    val servByPort = _prim "netdb_serv_byport" : int * string -> string list
  end
  fun flag (b, name) = if b then c name else 0
  fun bytes (a : Word8.word array, i, n) = CharVector.tabulate (n, fn k => Char.chr (Word8.toInt (Array.sub (a, i + k))))
  fun toArr (a : Word8.word array, i, s) = CharVector.appi (fn (k, ch) => Array.update (a, i + k, Word8.fromInt (Char.ord ch))) s
  fun SMLNJ_Sockets_socket (d : int, t : int, p : int) = check (Sock.create (d, t, p))
  fun SMLNJ_Sockets_socketPair (d : int, t : int, p : int) =
    case Sock.pair (d, t, p) of [a, b] => (a, b) | _ => syserr ()
  (* accept.c: the new socket and the address of its peer *)
  fun SMLNJ_Sockets_accept (fd : int) =
    case Sock.accept fd of ~1 => syserr () | s => (s, Sock.peer s)
  fun SMLNJ_Sockets_bind (fd : int, a : string) = unit (Sock.bind (fd, a))
  fun SMLNJ_Sockets_connect (fd : int, a : string) = unit (Sock.connect (fd, a))
  fun SMLNJ_Sockets_listen (fd : int, n : int) = unit (Sock.listen (fd, n))
  fun SMLNJ_Sockets_close (fd : int) = unit (XC2Sys.close fd)
  fun SMLNJ_Sockets_shutdown (fd : int, how : int) = unit (Sock.shutdown (fd, how))
  (* util-sockopt.c: get the flag, or set it and give what was set *)
  fun ctl (level, opt) (fd : int, v : int option) : int =
    case v of
      NONE => (case Sock.getopt (fd, c level, c opt) of ~1 => syserr () | x => x)
    | SOME x => (unit (Sock.setopt (fd, c level, c opt, x)); x)
  fun ctlFlag opt (fd : int, b : bool option) = ctl ("SOL_SOCKET", opt) (fd, Option.map (fn b => if b then 1 else 0) b) <> 0
  val SMLNJ_Sockets_ctlDEBUG = ctlFlag "SO_DEBUG"
  val SMLNJ_Sockets_ctlREUSEADDR = ctlFlag "SO_REUSEADDR"
  val SMLNJ_Sockets_ctlKEEPALIVE = ctlFlag "SO_KEEPALIVE"
  val SMLNJ_Sockets_ctlDONTROUTE = ctlFlag "SO_DONTROUTE"
  val SMLNJ_Sockets_ctlBROADCAST = ctlFlag "SO_BROADCAST"
  val SMLNJ_Sockets_ctlOOBINLINE = ctlFlag "SO_OOBINLINE"
  fun SMLNJ_Sockets_ctlNODELAY (fd : int, b : bool option) =
    ctl ("IPPROTO_TCP", "TCP_NODELAY") (fd, Option.map (fn b => if b then 1 else 0) b) <> 0
  (* the library binds ctlSNDBUF for getRCVBUF and setRCVBUF as well *)
  val SMLNJ_Sockets_ctlSNDBUF = ctl ("SOL_SOCKET", "SO_SNDBUF")
  (* ctlLINGER.c: NONE gets, SOME NONE turns it off, SOME (SOME t) on with
     the time t, which it gives back *)
  fun SMLNJ_Sockets_ctlLINGER (fd : int, v : int option option) : int option =
    case v of
      NONE => (case Sock.linger (fd, 0, 0) of [t] => if t < 0 then NONE else SOME t | _ => syserr ())
    | SOME NONE => (case Sock.linger (fd, 1, ~1) of [_] => NONE | _ => syserr ())
    | SOME (SOME t) => (case Sock.linger (fd, 1, t) of [_] => SOME t | _ => syserr ())
  fun SMLNJ_Sockets_getTYPE (fd : int) = sysConst sockTypes (ctl ("SOL_SOCKET", "SO_TYPE") (fd, NONE))
  fun SMLNJ_Sockets_getERROR (fd : int) = ctl ("SOL_SOCKET", "SO_ERROR") (fd, NONE) <> 0
  fun SMLNJ_Sockets_getPeerName (fd : int) = case Sock.peer fd of "" => syserr () | a => a
  fun SMLNJ_Sockets_getSockName (fd : int) = case Sock.name fd of "" => syserr () | a => a
  fun SMLNJ_Sockets_getNREAD (fd : int) = case Sock.query (fd, 0) of ~1 => syserr () | n => n
  fun SMLNJ_Sockets_getATMARK (fd : int) = case Sock.query (fd, 1) of ~1 => syserr () | n => n <> 0
  fun SMLNJ_Sockets_setNBIO (fd : int, b : bool) =
    let
      val f = Word.fromInt (check (XC2Sys.fcntl (fd, c "F_GETFL", 0)))
      val nb = Word.fromInt (c "O_NONBLOCK")
    in unit (XC2Sys.fcntl (fd, c "F_SETFL", Word.toInt (if b then Word.orb (f, nb) else Word.andb (f, Word.notb nb)))) end
  (* getaddrfamily.c looks up ntohs of the family, which Linux keeps in the
     machine's order: on a little-endian machine INET is 512, and not found *)
  fun SMLNJ_Sockets_getAddrFamily (a : string) =
    if size a < 2 then (~1, "<UNKNOWN>")
    else sysConst addrFamilies (Char.ord (String.sub (a, 0)) * 256 + Char.ord (String.sub (a, 1)))
  (* sendbuf.c: the flags are OOB, then DONTROUTE; the library sends from a
     vector and from an array (sendBufArr, basis.patch) *)
  fun sendFlags (oob, dr) = flag (oob, "MSG_OOB") + flag (dr, "MSG_DONTROUTE")
  fun recvFlags (oob, peek) = flag (oob, "MSG_OOB") + flag (peek, "MSG_PEEK")
  fun SMLNJ_Sockets_sendBuf (fd : int, v : string, i : int, n : int, oob : bool, dr : bool) =
    check (Sock.send (fd, String.substring (v, i, n), sendFlags (oob, dr)))
  fun SMLNJ_Sockets_sendBufArr (fd : int, a : Word8.word array, i : int, n : int, oob : bool, dr : bool) =
    check (Sock.send (fd, bytes (a, i, n), sendFlags (oob, dr)))
  fun SMLNJ_Sockets_sendBufTo (fd : int, v : string, i : int, n : int, oob : bool, dr : bool, to : string) =
    check (Sock.sendto (fd, String.substring (v, i, n), sendFlags (oob, dr), to))
  fun SMLNJ_Sockets_sendBufToArr (fd : int, a : Word8.word array, i : int, n : int, oob : bool, dr : bool, to : string) =
    check (Sock.sendto (fd, bytes (a, i, n), sendFlags (oob, dr), to))
  (* recv.c allocates the n bytes it asks for; the machine's primitives take
     at most its longest string, which is all they ask for *)
  fun most n = Int.min (n, 0x3fffffff)
  fun SMLNJ_Sockets_recv (fd : int, n : int, oob : bool, peek : bool) : string =
    let val r = Sock.recv (fd, most n, recvFlags (oob, peek))
    in if r = "" andalso XC2Sys.sysErrno () <> 0 then syserr () else r end
  fun SMLNJ_Sockets_recvBuf (fd : int, a : Word8.word array, i : int, n : int, oob : bool, peek : bool) =
    let val r = SMLNJ_Sockets_recv (fd, n, oob, peek) in toArr (a, i, r); size r end
  fun SMLNJ_Sockets_recvFrom (fd : int, n : int, oob : bool, peek : bool) : string * string =
    case Sock.recvfrom (fd, most n, recvFlags (oob, peek)) of [r, from] => (r, from) | _ => syserr ()
  fun SMLNJ_Sockets_recvBufFrom (fd : int, a : Word8.word array, i : int, n : int, oob : bool, peek : bool) =
    let val (r, from) = SMLNJ_Sockets_recvFrom (fd, n, oob, peek) in toArr (a, i, r); (size r, from) end
  (* INET addresses: an in_addr is its 4 bytes, the port of an address is
     in the network's order (bytes 2 and 3 of a sockaddr_in) *)
  fun dotted (a : string) = String.concatWith "." (List.tabulate (4, fn k => Int.toString (Char.ord (String.sub (a, k)))))
  fun SMLNJ_Sockets_toInetAddr (a : string, port : int) =
    case Sock.inetAddr (dotted a, port) of "" => syserr () | s => s
  fun SMLNJ_Sockets_fromInetAddr (a : string) =
    (String.substring (a, 4, 4), Char.ord (String.sub (a, 2)) * 256 + Char.ord (String.sub (a, 3)))
  fun SMLNJ_Sockets_inetany (port : int) = SMLNJ_Sockets_toInetAddr ("\000\000\000\000", port)
  fun SMLNJ_Sockets_toUnixAddr (path : string) = case Sock.unixAddr path of "" => syserr () | s => s
  (* from-unixaddr.c: the C string of sun_path, which follows the family *)
  fun SMLNJ_Sockets_fromUnixAddr (a : string) =
    let val p = if size a > 2 then String.extract (a, 2, NONE) else ""
    in Substring.string (#1 (Substring.splitl (fn ch => ch <> #"\000") (Substring.full p))) end
  (* the databases (util-mkhostent.c, ...): an entry or NONE *)
  fun num s = getOpt (Int.fromString s, 0)
  fun inAddr d = CharVector.fromList (List.map (Char.chr o num) (String.fields (fn ch => ch = #".") d))
  fun hostent l =
    case l of
      [] => NONE
    | [name] => SOME (name, [], sysConst addrFamilies (c "AF_INET"), [])
    | name :: addrs :: aliases =>
        SOME (name, aliases, sysConst addrFamilies (c "AF_INET"),
              List.map inAddr (String.tokens (fn ch => ch = #" ") addrs))
  fun SMLNJ_Sockets_getHostName () = case Sock.hostname () of "" => syserr () | h => h
  fun SMLNJ_Sockets_getHostByName (n : string) = hostent (Sock.hostByName n)
  fun SMLNJ_Sockets_getHostByAddr (a : string) = hostent (Sock.hostByAddr (dotted a))
  fun protoent l = case l of name :: p :: aliases => SOME (name, aliases, num p) | _ => NONE
  fun SMLNJ_Sockets_getProtByName (n : string) = protoent (Sock.protoByName n)
  fun SMLNJ_Sockets_getProtByNum (p : int) = protoent (Sock.protoByNumber p)
  fun servent l = case l of name :: port :: proto :: aliases => SOME (name, aliases, num port, proto) | _ => NONE
  fun SMLNJ_Sockets_getServByName (n : string, p : string option) = servent (Sock.servByName (n, getOpt (p, "")))
  (* getservbyport.c passes the port as it is, where C takes it in the
     network's order; the machine's primitive turns it round (htons) *)
  val littleEndian = Char.ord (String.sub (Sock.inetAddr ("", 0), 0)) <> 0
  fun SMLNJ_Sockets_getServByPort (port : int, p : string option) =
    if port < 0 orelse port > 65535 then NONE
    else servent (Sock.servByPort (if littleEndian then port mod 256 * 256 + port div 256 else port, getOpt (p, "")))

  (* ---- POSIX-OS: poll.c, whose ML_Poll is select on Linux: the bits are 1
     read, 2 write and 4 an exceptional condition, as the machine's poll has
     them; select fails for a descriptor that is not open (EBADF) and for a
     negative time (EINVAL), which poll does not; the time in microseconds *)
  fun failWith e = raise XC2N.SysErr (XC2Sys.errorMsg e, SOME e)
  fun POSIX_OS_poll (l : (int * word) list, t : (Int32.int * int) option) : (int * word) list =
    let
      val fds = List.map #1 l
      val evs = List.map (fn (_, w) => Word.toInt (Word.andb (w, 0w7))) l
      val us = case t of NONE => ~1 | SOME (s, u) => Int32.toInt s * 1000000 + u
    in
      if List.exists (fn fd => XC2Sys.fcntl (fd, c "F_GETFD", 0) = ~1) fds then failWith (c "EBADF")
      else if (case t of SOME (s, u) => s < 0 orelse u < 0 orelse u >= 1000000 | NONE => false) then failWith (c "EINVAL")
      else case (l, XC2Sys.osPoll (fds, evs, us)) of
        ([], _) => []
      | (_, []) => syserr ()
      | (_, got) =>
          (* what was asked for and is so *)
          List.mapPartial (fn ((fd, e), r) =>
                             case Word.andb (Word.fromInt e, Word.fromInt r) of 0w0 => NONE | w => SOME (fd, w))
            (ListPair.zip (ListPair.zip (fds, evs), got))
    end

  (* ---- POSIX-SysDB: an entry, or SysErr with errno *)
  fun pw l = case l of [n, dir, sh, u, g] => (n, w64 (num u), w64 (num g), dir, sh) | _ => syserr ()
  fun gr l = case l of n :: g :: m => (n, w64 (num g), m) | _ => syserr ()
  (* the name "" is no user (Rune's machine takes it for a lookup by number) *)
  fun POSIX_SysDB_getpwnam (n : string) = pw (if n = "" then [] else XC2Sys.getpw (n, 0))
  fun POSIX_SysDB_getpwuid (u : Word64.word) = pw (XC2Sys.getpw ("", w64i u))
  fun POSIX_SysDB_getgrnam (n : string) = gr (if n = "" then [] else XC2Sys.getgr (n, 0))
  fun POSIX_SysDB_getgrgid (g : Word64.word) = gr (XC2Sys.getgr ("", w64i g))

  (* ---- POSIX-TTY: termio_rep is the four flags, the control characters
     as a string and the two speeds; the machine's primitives take the
     speeds before the characters *)
  val tcop = _prim "posix_tcop" : int * int * int -> int
  fun POSIX_TTY_tcgetattr (fd : int) =
    case XC2Sys.tcgetattr fd of
      i :: oflag :: cflag :: l :: is :: os :: cc =>
        (w64 i, w64 oflag, w64 cflag, w64 l, CharVector.fromList (List.map Char.chr cc), w64 is, w64 os)
    | _ => syserr ()
  fun POSIX_TTY_tcsetattr (fd : int, action : int,
                           (i : Word64.word, oflag : Word64.word, cflag : Word64.word, l : Word64.word,
                            cc : string, is : Word64.word, os : Word64.word)) =
    unit (XC2Sys.tcsetattr (fd, action, [w64i i, w64i oflag, w64i cflag, w64i l, w64i is, w64i os]
                                        @ List.map Char.ord (String.explode cc)))
  fun POSIX_TTY_tcsendbreak (fd : int, d : int) = unit (tcop (3, fd, d))
  fun POSIX_TTY_tcdrain (fd : int) = unit (tcop (0, fd, 0))
  fun POSIX_TTY_tcflush (fd : int, q : int) = unit (tcop (1, fd, q))
  fun POSIX_TTY_tcflow (fd : int, a : int) = unit (tcop (2, fd, a))
  (* tcgetpgrp.c gives what C gives, ~1 on failure *)
  fun POSIX_TTY_tcgetpgrp (fd : int) = tcop (4, fd, 0)
  fun POSIX_TTY_tcsetpgrp (fd : int, p : int) = unit (tcop (5, fd, p))
  (* getwinsz.c: the machine has no primitive for TIOCGWINSZ; NONE, as for
     a descriptor that is no terminal *)
  fun POSIX_TTY_getwinsz (_ : int) : (int * int) option = NONE

  (* ---- SMLNJ-Date: a tm is (sec, min, hour, mday, mon, year, wday, yday,
     isdst), the year in full; C's struct tm and the machine's primitives
     count it from 1900. A time is in nanoseconds (ns_to_time). *)
  (* REC_SELINT: an int of C *)
  fun cint x = let val m = x mod 4294967296 in if m >= 2147483648 then m - 4294967296 else m end
  fun tmOf [sec, min, hour, mday, mon, year, wday, yday, isdst] = (sec, min, hour, mday, mon, year + 1900, wday, yday, isdst)
    | tmOf _ = syserr ()
  fun partsOf (sec, min, hour, mday, mon, year, wday, yday, isdst) =
    List.map cint [sec, min, hour, mday, mon, cint year - 1900, wday, yday, isdst]
  fun secs (ns : Word64.word) = Word64.toInt (Word64.div (ns, 0w1000000000))
  fun SMLNJ_Date_localTime (ns : Word64.word) = tmOf (XC2Sys.dateParts (secs ns, 1))
  fun SMLNJ_Date_gmTime (ns : Word64.word) = tmOf (XC2Sys.dateParts (secs ns, 0))
  (* mktime.c: a negative time is an invalid date *)
  fun SMLNJ_Date_mkTime tm =
    case XC2Sys.dateSeconds (partsOf tm, 1) of
      t :: _ => if t < 0 then error "Invalid date" else Word64.* (w64 t, 0w1000000000)
    | [] => error "Invalid date"
  (* strftime.c: an unknown daylight saving (isdst < 0) is settled by
     mktime first; an empty result, or one of 512 bytes or more, fails *)
  fun SMLNJ_Date_strfTime (fmt : string, tm) =
    let
      val parts = partsOf tm
      val parts =
        if List.nth (parts, 8) >= 0 then parts
        else case XC2Sys.dateSeconds (parts, 1) of _ :: p => p | [] => error "strftime failed: invalid tm struct"
      val s = XC2Sys.dateFormat (fmt, parts, 1)
    in if s = "" orelse size s >= 512 then error "strftime failed" else s end
  (* localoffset.c: the time of the broken-down UTC time read as a local
     one, with the local daylight saving, less the time *)
  fun localOffset (t : int) : Int32.int =
    let
      val isdst = case XC2Sys.dateParts (t, 1) of [_, _, _, _, _, _, _, _, d] => d | _ => syserr ()
      val utc = case XC2Sys.dateParts (t, 0) of [] => syserr () | l => List.take (l, 8) @ [isdst]
      val t2 = case XC2Sys.dateSeconds (utc, 1) of t2 :: _ => t2 | [] => ~1
    in Int32.fromInt (t2 - t) end
  fun SMLNJ_Date_localOffset () = localOffset (XC2Sys.timeNow () div 1000000)
  fun SMLNJ_Date_localOffsetForTime (ns : Word64.word) = localOffset (secs ns)

  (* ---- SMLNJ-Math: ctlrndmode.c, SML/NJ's modes 0 nearest, 1 to zero, 2
     up, 3 down; the machine's 0 nearest, 1 down, 2 up, 3 to zero. Setting
     gives what fesetround does, 0. *)
  fun SMLNJ_Math_ctlRoundingMode (m : int option) : int =
    let
      fun swap k = case k of 1 => 3 | 3 => 1 | k => k
    in
      case m of
        NONE => swap ((_prim "real_get_round" : unit -> int) ())
      | SOME k => ((_prim "real_set_round" : int -> unit) (swap k); 0)
    end

  (* ---- SMLNJ-RunT *)
  (* argv.c, raw-argv.c, cmd-name.c and shift-argv.c: the program's
     arguments, which shiftArgv drops one of; the raw ones have the name *)
  val cmdName = _prim "command_name" : unit -> string
  val cmdArgs = _prim "command_args" : unit -> string list
  val shifted = ref 0
  fun SMLNJ_RunT_argv () = List.drop (cmdArgs (), Int.min (!shifted, length (cmdArgs ())))
  fun SMLNJ_RunT_rawArgv () = cmdName () :: cmdArgs ()
  fun SMLNJ_RunT_cmdName () = cmdName ()
  fun SMLNJ_RunT_shiftArgv () = if null (SMLNJ_RunT_argv ()) then () else shifted := !shifted + 1
  fun SMLNJ_RunT_debug (s : string) = ignore (XC2Sys.write (2, s))
  (* sysinfo.c: the system's name, from uname, and an AMD64 without polling
     or multiprocessing *)
  fun SMLNJ_RunT_sysInfo (name : string) : string option =
    case name of
      "OS_NAME" => SOME (case XC2Sys.uname () of sys :: _ => sys | [] => "Linux")
    | "OS_VERSION" => SOME "<unknown>"
    | "HEAP_SUFFIX" => SOME "amd64-linux"
    | "ARCH_NAME" => SOME "AMD64"
    | "HAS_SOFT_POLL" => SOME "NO"
    | "HAS_MP" => SOME "NO"
    | _ => NONE

  (* ---- time *)
  fun SMLNJ_Time_timeofday () = Word64.* (w64 (XC2Sys.timeNow ()), 0w1000)
  fun SMLNJ_Time_gettime () =
    let val ns = fn us => i64 (us * 1000)
    in (ns ((_prim "time_user" : unit -> int) ()), ns ((_prim "time_sys" : unit -> int) ()),
        ns ((_prim "time_gc_user" : unit -> int) ()))
    end
end
