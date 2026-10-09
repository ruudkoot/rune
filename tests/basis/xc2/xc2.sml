(* What the shims of the xc2 configurations share (tests/basis/xc2/README.md):
   compiled after Rune's library and before a host's prologue and shim. *)
structure XC2 =
struct
  exception Unimplemented of string
  fun unimplemented what = raise Unimplemented what

  (* An array of a host's. MLton and MLKit allocate an array before they have
     an element to fill it with, and Rune cannot: the cells are made at the
     first update, and until then only the length is known. A ref, so that
     every array admits equality, as Rune's arrays do. *)
  datatype 'a cells = Cells of 'a Array.array | Uninit of int
  type 'a array = 'a cells ref

  structure Array =
  struct
    fun alloc n : 'a array = ref (Uninit n)
    fun length (ref (Cells a) : 'a array) = Array.length a
      | length (ref (Uninit n)) = n
    fun sub (ref (Cells a) : 'a array, i) = Array.sub (a, i)
      | sub (ref (Uninit _), _) = raise Fail "xc2: an element of an array read before any is written"
    fun update (r as ref (Uninit n) : 'a array, i, x) =
          if i < 0 orelse i >= n then raise Subscript else r := Cells (Array.array (n, x))
      | update (ref (Cells a), i, x) = Array.update (a, i, x)
    fun toVector (ref (Cells a) : 'a array) = Array.vector a
      | toVector (ref (Uninit 0)) = Vector.fromList []
      | toVector (ref (Uninit _)) = raise Fail "xc2: a vector of an array never written"
  end

end

(* The exceptions of Rune's that a host's library takes for its own: those
   Rune's machine raises (Overflow, Div, Subscript, Size, Bind and Match are
   the compiler's anyway) and those the shims' use of Rune's library can. *)
structure XC2RuneExn =
struct
  exception Chr = Chr
  exception Div = Div
  exception Domain = Domain
  exception Fail = Fail
  exception Overflow = Overflow
  exception Size = Size
  exception Span = Span
  exception Subscript = Subscript
end

(* The primitives of Rune's machine that the shims use: C's functions with
   Rune's types. A call that fails returns ~1, or what its line of
   vm/prims.def says, and leaves its error in sys_errno. *)
structure XC2Sys =
struct
  val sysErrno = _prim "sys_errno" : unit -> int
  val errorMsg = _prim "sys_error_msg" : int -> string
  val timeNow = _prim "time_now" : unit -> int
  val dateParts = _prim "date_parts" : int * int -> int list
  val dateSeconds = _prim "date_seconds" : int list * int -> int list
  val dateOffset = _prim "date_offset" : int -> int
  val dateFormat = _prim "date_format" : string * int list * int -> string
  val getenv = _prim "os_getenv" : string -> string option
  val osMkdir = _prim "os_mkdir" : string -> int
  val osRmdir = _prim "os_rmdir" : string -> int
  val osChdir = _prim "os_chdir" : string -> int
  val osGetcwd = _prim "os_getcwd" : unit -> string
  val osRemove = _prim "os_remove" : string -> int
  val osRename = _prim "os_rename" : string * string -> int
  val osAccess = _prim "os_access" : string * int * int -> int
  val osReadLink = _prim "os_read_link" : string -> string
  val osOpenDir = _prim "os_open_dir" : string -> int
  val osReadDir = _prim "os_read_dir" : int -> string option
  val osRewindDir = _prim "os_rewind_dir" : int -> int
  val osCloseDir = _prim "os_close_dir" : int -> int
  val osPoll = _prim "os_poll" : int list * int list * int -> int list
  val system = _prim "os_system" : string -> int
  val posixConst = _prim "posix_const" : string -> int
  val fork = _prim "posix_fork" : unit -> int
  val exec = _prim "posix_exec" : string * string list * int -> int
  val exece = _prim "posix_exece" : string * string list * string list -> int
  val waitpid = _prim "posix_waitpid" : int * int -> int list
  val kill = _prim "posix_kill" : int * int -> int
  val alarm = _prim "posix_alarm" : int -> int
  val pause = _prim "posix_pause" : unit -> int
  val getpid = _prim "posix_getpid" : unit -> int
  val getppid = _prim "posix_getppid" : unit -> int
  val getuid = _prim "posix_getuid" : unit -> int
  val geteuid = _prim "posix_geteuid" : unit -> int
  val getgid = _prim "posix_getgid" : unit -> int
  val getegid = _prim "posix_getegid" : unit -> int
  val setuid = _prim "posix_setuid" : int -> int
  val setgid = _prim "posix_setgid" : int -> int
  val getgroups = _prim "posix_getgroups" : unit -> int list
  val getlogin = _prim "posix_getlogin" : unit -> string
  val getpgrp = _prim "posix_getpgrp" : unit -> int
  val setsid = _prim "posix_setsid" : unit -> int
  val setpgid = _prim "posix_setpgid" : int * int -> int
  val uname = _prim "posix_uname" : unit -> string list
  val times = _prim "posix_times" : unit -> int list
  val environ = _prim "posix_environ" : unit -> string list
  val ctermid = _prim "posix_ctermid" : unit -> string
  val ttyname = _prim "posix_ttyname" : int -> string
  val isatty = _prim "posix_isatty" : int -> int
  val sysconf = _prim "posix_sysconf" : string -> int
  val openf = _prim "posix_openf" : string * int * int -> int
  val close = _prim "posix_close" : int -> int
  val dup = _prim "posix_dup" : int -> int
  val dup2 = _prim "posix_dup2" : int * int -> int
  val pipe = _prim "posix_pipe" : unit -> int list
  val read = _prim "posix_read" : int * int -> string
  val write = _prim "posix_write" : int * string -> int
  val lseek = _prim "posix_lseek" : int * int * int -> int
  val fsync = _prim "posix_fsync" : int -> int
  val fcntl = _prim "posix_fcntl" : int * int * int -> int
  val ftruncate = _prim "posix_ftruncate" : int * int -> int
  val stat = _prim "posix_stat" : string * int * int -> int list
  val chmod = _prim "posix_chmod" : string * int * int -> int
  val chown = _prim "posix_chown" : string * int * int * int -> int
  val link = _prim "posix_link" : string * string -> int
  val symlink = _prim "posix_symlink" : string * string -> int
  val mkfifo = _prim "posix_mkfifo" : string * int -> int
  val umask = _prim "posix_umask" : int -> int
  val getpw = _prim "posix_getpw" : string * int -> string list
  val getgr = _prim "posix_getgr" : string * int -> string list
  val lock = _prim "posix_lock" : int * int * int * int * int * int -> int list
  val pathconf = _prim "posix_pathconf" : string * int * string -> int list
  val utime = _prim "posix_utime" : string * int * int -> int
  val tcgetattr = _prim "posix_tcgetattr" : int -> int list
  val tcsetattr = _prim "posix_tcsetattr" : int * int * int list -> int
  val exit = _prim "posix_exit" : int -> 'a
end
