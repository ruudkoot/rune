(* The process's own identity: who it is, who owns it, which group and
   session it belongs to, and what its environment holds.

   The user and group identities come in two kinds. The *real* one is who
   started the process; the *effective* one is whose permissions it acts
   with, and the two differ for a program whose set-user-id bit is set. A
   process may set them back to what they already are, and only a privileged
   process may set them to anything else.

   `uname`, `time`, `times` and `sysconf` ask the system about itself rather
   than about the process.

   Area: The operating system

   Status: optional

   See also: `POSIX`, `POSIX_SYS_DB`, `POSIX_PROCESS`, `OS_PROCESS`, `TIME`

   Erratum: `POSIX_PROC_ENV/flexible-types`. The types `pid` and `file_desc`
   are left flexible here, as on the page; `POSIX` fixes `pid` to
   `Posix.Process.pid`, and `file_desc` is the one `FileSys` and `IO` use.

   Implementation: `Posix.ProcEnv/what-a-check-can-expect`. What these report
   is whatever `id`, `uname`, `date` and `getconf` report on the machine, so
   that is what the suite compares them with. The test runner gives every
   program `/dev/null` for its standard input, so no descriptor a check sees
   is a terminal.

   Pinned by: `Posix.ProcEnv.isatty/dev-null`, `Posix.ProcEnv.ttyname/dev-null` *)
signature POSIX_PROC_ENV =
sig
  (* The type of the number that names a process, the one of `Posix.Process`. *)
  eqtype pid

  (* The type of the number that names a user.

     Deviation: `Posix.ProcEnv.uid/is-an-int`. The specification leaves the
     type abstract; in Rune it is `int`, and the structure is not sealed. *)
  eqtype uid

  (* The type of the number that names a group. *)
  eqtype gid

  (* The type of an open file descriptor, the one of `Posix.FileSys`. *)
  eqtype file_desc

  (* `uidToWord u` is the number of the user `u`. *)
  val uidToWord : uid -> SysWord.word

  (* `wordToUid w` is the user numbered `w`, whether or not there is such a user. *)
  val wordToUid : SysWord.word -> uid

  (* `gidToWord g` is the number of the group `g`. *)
  val gidToWord : gid -> SysWord.word

  (* `wordToGid w` is the group numbered `w`. *)
  val wordToGid : SysWord.word -> gid

  (* `getpid ()` is the number of this process. *)
  val getpid : unit -> pid

  (* `getppid ()` is the number of the process that made this one. *)
  val getppid : unit -> pid

  (* `getuid ()` is the user that started this process. *)
  val getuid : unit -> uid

  (* `geteuid ()` is the user whose permissions this process acts with. *)
  val geteuid : unit -> uid

  (* `getgid ()` is the group of the user that started this process. *)
  val getgid : unit -> gid

  (* `getegid ()` is the group whose permissions this process acts with. *)
  val getegid : unit -> gid

  (* `setuid u` makes `u` the user of this process.

     Raises: `OS.SysErr` if the process may not become `u`.

     Reading: `Posix.ProcEnv.setuid/own-is-allowed`. Setting the user to the
     one the process already has is allowed and changes nothing. Becoming
     another user, the superuser above all, is refused unless the process is
     privileged already.

     Pinned by: `Posix.ProcEnv.setuid/own`, `Posix.ProcEnv.setuid/root-raises` *)
  val setuid : uid -> unit

  (* `setgid g` makes `g` the group of this process.

     Raises: `OS.SysErr` if the process may not take the group `g`.

     Reading: `Posix.ProcEnv.setgid/own-is-allowed`. As for `setuid`: a process
     may always take the group it has, and only a privileged one may take
     another.

     Pinned by: `Posix.ProcEnv.setgid/own`, `Posix.ProcEnv.setgid/root-raises` *)
  val setgid : gid -> unit

  (* `getgroups ()` is the supplementary groups of this process.

     Implementation: `Posix.ProcEnv.getgroups/compared-with-id-G`. The suite
     compares the list with what `id -G` prints, which also lists the
     effective group, so that group is added before comparing.

     Pinned by: `Posix.ProcEnv.getgroups/*` *)
  val getgroups : unit -> gid list

  (* `getlogin ()` is the name the user logged in under.

     Raises: `OS.SysErr` if the system does not know it.

     Reading: `Posix.ProcEnv.getlogin/may-not-be-known`. Without a terminal
     the system may have no login name to give; the suite accepts either
     `OS.SysErr` or a name that is a user of the machine.

     Pinned by: `Posix.ProcEnv.getlogin/user-or-SysErr` *)
  val getlogin : unit -> string

  (* `getpgrp ()` is the process group this process is in. *)
  val getpgrp : unit -> pid

  (* `setsid ()` starts a new session with this process alone in it, and is its new process group.

     Raises: `OS.SysErr` if this process already leads a process group.

     Reading: `Posix.ProcEnv.setsid/group-is-the-pid`. The process group it
     returns is the process's own number, since the process becomes the
     leader of a group of its own.

     Pinned by: `Posix.ProcEnv.setsid/*` *)
  val setsid : unit -> pid

  (* `setpgid {pid, pgid}` puts the process `pid` into the process group `pgid`, `NONE` meaning this process.

     Raises: `OS.SysErr` if the move is refused. *)
  val setpgid : {pid : pid option, pgid : pid option} -> unit

  (* `uname ()` is what the system says about itself, as pairs of a field and its value.

     The fields are `"sysname"`, `"nodename"`, `"release"`, `"version"` and
     `"machine"`.

     Raises: `OS.SysErr` if the system cannot be asked. *)
  val uname : unit -> (string * string) list

  (* `time ()` is the time now, as `Time.now` gives it. *)
  val time : unit -> Time.time

  (* `times ()` is how much time this process and the children it has waited for have used.

     `elapsed` is wall-clock time from a fixed point in the past, `utime` and
     `stime` this process's own user and system time, and `cutime` and
     `cstime` those of the children it has waited for. *)
  val times : unit
              -> {elapsed : Time.time,
                  utime : Time.time,
                  stime : Time.time,
                  cutime : Time.time,
                  cstime : Time.time}

  (* `getenv name` is `SOME` of the value of the environment variable `name`, or `NONE`. *)
  val getenv : string -> string option

  (* `environ ()` is the whole environment, each entry written `"name=value"`. *)
  val environ : unit -> string list

  (* `ctermid ()` is the path of this process's controlling terminal, or the empty string when it has none. *)
  val ctermid : unit -> string

  (* `ttyname fd` is the path of the terminal that `fd` is open on.

     Raises: `OS.SysErr` if `fd` is not a terminal. *)
  val ttyname : file_desc -> string

  (* `isatty fd` is `true` when `fd` is open on a terminal. *)
  val isatty : file_desc -> bool

  (* `sysconf name` is the value the system gives for the limit or option `name`, such as `"CLK_TCK"`.

     Raises: `OS.SysErr` if the system does not know `name`.

     Reading: `Posix.ProcEnv.sysconf/no-limit-raises`. A variable the system
     knows but leaves unbounded is reported the same way as an unknown one --
     the call gives `~1` and sets no `errno` -- so this raises for both. *)
  val sysconf : string -> SysWord.word
end
