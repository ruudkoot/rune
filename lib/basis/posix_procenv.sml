(* Posix.ProcEnv: the process and the world it runs in. *)
structure RunePosixProcEnv =
struct
  type pid = RunePosixProcess.pid
  type uid = int
  type gid = int
  type file_desc = int

  local
    val getpid' = _prim "posix_getpid" : unit -> int
    val getppid' = _prim "posix_getppid" : unit -> int
    val getuid' = _prim "posix_getuid" : unit -> int
    val geteuid' = _prim "posix_geteuid" : unit -> int
    val getgid' = _prim "posix_getgid" : unit -> int
    val getegid' = _prim "posix_getegid" : unit -> int
    val setuid' = _prim "posix_setuid" : int -> int
    val setgid' = _prim "posix_setgid" : int -> int
    val getgroups' = _prim "posix_getgroups" : unit -> int list
    val getlogin' = _prim "posix_getlogin" : unit -> string
    val getpgrp' = _prim "posix_getpgrp" : unit -> int
    val setsid' = _prim "posix_setsid" : unit -> int
    val setpgid' = _prim "posix_setpgid" : int * int -> int
    val uname' = _prim "posix_uname" : unit -> string list
    val times' = _prim "posix_times" : unit -> int list
    val environ' = _prim "posix_environ" : unit -> string list
    val ctermid' = _prim "posix_ctermid" : unit -> string
    val ttyname' = _prim "posix_ttyname" : int -> string
    val isatty' = _prim "posix_isatty" : int -> int
    val sysconf' = _prim "posix_sysconf" : string -> int
    val getenv' = _prim "os_getenv" : string -> string option
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun checkString s = if s = "" then raise RuneError.lastError () else s
  in
    fun uidToWord (u : uid) = Word.fromInt u
    fun wordToUid w = Word.toInt w
    fun gidToWord (g : gid) = Word.fromInt g
    fun wordToGid w = Word.toInt w

    fun getpid () = getpid' ()
    fun getppid () = getppid' ()
    fun getuid () = getuid' ()
    fun geteuid () = geteuid' ()
    fun getgid () = getgid' ()
    fun getegid () = getegid' ()
    fun setuid u = ignore (check (setuid' u))
    fun setgid g = ignore (check (setgid' g))
    fun getgroups () = getgroups' ()
    fun getlogin () = checkString (getlogin' ())
    fun getpgrp () = getpgrp' ()
    fun setsid () = check (setsid' ())
    fun setpgid {pid, pgid} =
      ignore (check (setpgid' (case pid of NONE => 0 | SOME p => p,
                               case pgid of NONE => 0 | SOME p => p)))

    fun uname () =
      case uname' () of
        [sysname, nodename, release, version, machine] =>
          [("sysname", sysname), ("nodename", nodename), ("release", release),
           ("version", version), ("machine", machine)]
      | _ => raise RuneError.lastError ()

    fun time () = Time.now ()

    fun times () =
      case times' () of
        [elapsed, user, system, childUser, childSystem] =>
          {elapsed = Time.ofMicros elapsed, utime = Time.ofMicros user, stime = Time.ofMicros system,
           cutime = Time.ofMicros childUser, cstime = Time.ofMicros childSystem}
      | _ => raise RuneError.lastError ()

    fun getenv name = getenv' name
    fun environ () = environ' ()
    fun ctermid () = checkString (ctermid' ())
    fun ttyname (fd : file_desc) = checkString (ttyname' fd)
    fun isatty (fd : file_desc) = isatty' fd = 1
    (* "It raises OS.SysErr if s does not denote a supported POSIX system
       variable"; a variable without a limit (sysconf gives ~1 and leaves
       errno alone) has no value either. *)
    fun sysconf name =
      case sysconf' name of
        ~1 => (case RuneError.lastError () of
                 RuneError.SysErr (_, SOME 0) => raise RuneError.SysErr ("sysconf: " ^ name ^ " has no limit", NONE)
               | e => raise e)
      | v => Word.fromInt v
  end
end
