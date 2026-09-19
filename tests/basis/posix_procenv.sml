(* requires: Posix OS TextIO *)
(* uses: fn/posix_child.sml *)
(* Posix.ProcEnv (signature POSIX_PROC_ENV). Expected values follow the text
   of https://smlfamily.github.io/Basis/posix-proc-env.html, and are compared
   with what the standard commands report (id, uname, date, getconf): "a
   property in SML has the same name as the property in C, but without the
   prefix _SC_". Under the runner, standard input is /dev/null, so that no
   descriptor of the test is a terminal. The identities of processes and
   groups are looked at in children (fn/posix_child.sml), so that this
   process keeps its own. *)
structure TestPosixProcEnv =
struct
  structure E = Posix.ProcEnv
  structure P = Posix.Process
  structure C = PosixChild
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqSt = T.eq C.showStatus
  val showW = fn w => "0wx" ^ SysWord.toString w
  val dec = SysWord.fmt StringCvt.DEC
  fun pidWord p = P.pidToWord p

  (* agree show (label, expected, actual): the two thunks give the same
     value; both are computed inside the check. *)
  fun agree show (label, expected : unit -> ''a, actual : unit -> ''a) =
    eqS (label, "agree",
         fn () => let val e = expected () val a = actual ()
                  in if e = a then "agree" else "got " ^ show a ^ ", expected " ^ show e end)
  val agreeW = agree (T.option showW)
  val agreeS = agree (T.option T.string)

  (* ---- user and group ids, against id(1) ---- *)
  val () = agreeW ("Posix.ProcEnv.getuid/id-ru", fn () => C.shellWord "id -ru", fn () => SOME (E.uidToWord (E.getuid ())))
  val () = agreeW ("Posix.ProcEnv.geteuid/id-u", fn () => C.shellWord "id -u", fn () => SOME (E.uidToWord (E.geteuid ())))
  val () = agreeW ("Posix.ProcEnv.getgid/id-rg", fn () => C.shellWord "id -rg", fn () => SOME (E.gidToWord (E.getgid ())))
  val () = agreeW ("Posix.ProcEnv.getegid/id-g", fn () => C.shellWord "id -g", fn () => SOME (E.gidToWord (E.getegid ())))
  val () = eqB ("Posix.ProcEnv.uidToWord/wordToUid", true,
                fn () => E.wordToUid (E.uidToWord (E.getuid ())) = E.getuid ())
  val () = eqB ("Posix.ProcEnv.gidToWord/wordToGid", true,
                fn () => E.wordToGid (E.gidToWord (E.getgid ())) = E.getgid ())
  (* "Note that wordToUid does not ensure that it returns a valid uid." *)
  val () = T.eq showW ("Posix.ProcEnv.wordToUid/no-validation", 0w1999999999,
                       fn () => E.uidToWord (E.wordToUid 0w1999999999))
  val () = T.eq showW ("Posix.ProcEnv.wordToGid/no-validation", 0w1999999999,
                       fn () => E.gidToWord (E.wordToGid 0w1999999999))
  (* "The list of supplementary group IDs of the calling process": what id -G
     lists, which also has the effective group. *)
  fun idG () =
    List.mapPartial (StringCvt.scanString (SysWord.scan StringCvt.DEC))
                    (String.tokens Char.isSpace (C.shell "id -G"))
  val () = eqB ("Posix.ProcEnv.getgroups/in-id-G", true,
                fn () => let val ids = idG ()
                         in List.all (fn g => List.exists (fn x => x = E.gidToWord g) ids) (E.getgroups ()) end)
  val () = eqB ("Posix.ProcEnv.getgroups/id-G-in-them", true,
                fn () => let val groups = List.map E.gidToWord (E.getegid () :: E.getgroups ())
                         in List.all (fn x => List.exists (fn g => g = x) groups) (idG ()) end)

  (* "sets the real user ID and effective user ID to u": to the ones this
     process has is allowed, and changes nothing. *)
  val () = eqB ("Posix.ProcEnv.setuid/own", true,
                fn () => let val u = E.getuid ()
                         in E.setuid u; E.getuid () = u andalso E.geteuid () = u end)
  val () = eqB ("Posix.ProcEnv.setgid/own", true,
                fn () => let val g = E.getgid ()
                         in E.setgid g; E.getgid () = g andalso E.getegid () = g end)
  (* Only the superuser may become the superuser. *)
  val root = E.getuid () = E.wordToUid 0w0
  val () = eqB ("Posix.ProcEnv.setuid/root-raises", true,
                fn () => root orelse ((E.setuid (E.wordToUid 0w0); false) handle OS.SysErr _ => true))
  val () = eqB ("Posix.ProcEnv.setgid/root-raises", true,
                fn () => root orelse E.getgid () = E.wordToGid 0w0
                         orelse ((E.setgid (E.wordToGid 0w0); false) handle OS.SysErr _ => true))

  (* ---- processes ---- *)
  (* The shell that OS.Process.system runs is a child of this process. *)
  val () = agreeW ("Posix.ProcEnv.getpid/PPID-of-shell", fn () => C.shellWord "echo $PPID",
                   fn () => SOME (pidWord (E.getpid ())))
  val () = eqB ("Posix.ProcEnv.getpid/stable", true, fn () => E.getpid () = E.getpid ())
  val () = eqSt ("Posix.ProcEnv.getppid/of-child", P.W_EXITSTATUS (C.w8 3),
                 fn () => let val me = E.getpid () in C.run (fn () => if E.getppid () = me then C.w8 3 else C.w8 4) end)
  val () = eqB ("Posix.ProcEnv.getppid/not-self", true, fn () => E.getppid () <> E.getpid ())
  val () = eqSt ("Posix.ProcEnv.getpid/of-child-differs", P.W_EXITSTATUS (C.w8 3),
                 fn () => let val me = E.getpid () in C.run (fn () => if E.getpid () <> me then C.w8 3 else C.w8 4) end)

  (* "The process group ID of the calling process": a child starts in the
     group of its parent. *)
  val () = eqSt ("Posix.ProcEnv.getpgrp/inherited", P.W_EXITSTATUS (C.w8 3),
                 fn () => let val g = E.getpgrp () in C.run (fn () => if E.getpgrp () = g then C.w8 3 else C.w8 4) end)
  (* setpgid (NONE, NONE): "the calling process becomes a process group
     leader". *)
  val () = eqSt ("Posix.ProcEnv.setpgid/NONE-NONE", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (E.setpgid {pid = NONE, pgid = NONE};
                                           if E.getpgrp () = E.getpid () then C.w8 3 else C.w8 4)))
  (* setpgid (SOME pid, NONE): "the process with process ID pid becomes a
     process group leader"; the child waits until the parent has done it. *)
  val () = T.eq (T.option C.showStatus) ("Posix.ProcEnv.setpgid/SOME-NONE", SOME (P.W_EXITSTATUS (C.w8 3)),
                fn () => let
                           val pid = C.spawn (fn () =>
                                       if C.appears "pgid-set.txt" andalso E.getpgrp () = E.getpid () then C.w8 3 else C.w8 4)
                         in
                           E.setpgid {pid = SOME pid, pgid = NONE};
                           C.write ("pgid-set.txt", "");
                           C.waitBounded pid before OS.FileSys.remove "pgid-set.txt"
                         end)
  (* setpgid (NONE, SOME pgid) and setpgid (SOME pid, SOME pgid): a process
     joins, or is put into, the group of a leader that sleeps. *)
  fun leader () : P.pid =
    let
      val pid = C.fork (fn () => (E.setpgid {pid = NONE, pgid = NONE};
                                  P.exec ("/bin/sh", ["sh", "-c", ": > leader-ready.txt; exec sleep 10"])))
    in
      E.setpgid {pid = SOME pid, pgid = NONE} handle OS.SysErr _ => ();
      ignore (C.appears "leader-ready.txt");
      pid
    end
  fun endLeader (pid : P.pid) =
    (P.kill (P.K_PROC pid, Posix.Signal.kill); ignore (C.status pid); OS.FileSys.remove "leader-ready.txt")
  val () = T.eq (T.option C.showStatus) ("Posix.ProcEnv.setpgid/NONE-SOME", SOME (P.W_EXITSTATUS (C.w8 3)),
                fn () => let
                           val l = leader ()
                           val s = C.waitBounded (C.spawn (fn () => (E.setpgid {pid = NONE, pgid = SOME l};
                                                                     if E.getpgrp () = l then C.w8 3 else C.w8 4)))
                         in endLeader l; s end)
  val () = T.eq (T.option C.showStatus) ("Posix.ProcEnv.setpgid/SOME-SOME", SOME (P.W_EXITSTATUS (C.w8 3)),
                fn () => let
                           val l = leader ()
                           val pid = C.spawn (fn () =>
                                       if C.appears "pgid-moved.txt" andalso E.getpgrp () = l then C.w8 3 else C.w8 4)
                           val () = E.setpgid {pid = SOME pid, pgid = SOME l}
                           val () = C.write ("pgid-moved.txt", "")
                           val s = C.waitBounded pid
                         in endLeader l; OS.FileSys.remove "pgid-moved.txt"; s end)
  val () = T.raises ("Posix.ProcEnv.setpgid/no-such-process", fn OS.SysErr _ => true | _ => false,
                     fn () => let val pid = C.fork (fn () => P.exec ("/bin/sh", ["sh", "-c", "exit 0"]))
                              in ignore (C.status pid); E.setpgid {pid = SOME pid, pgid = NONE} end)
  (* setsid "creates a new session if the calling process is not a process
     group leader, and returns the process group ID of the calling process",
     which is then its own ID; a group leader cannot. *)
  val () = eqSt ("Posix.ProcEnv.setsid/child", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => let val g = E.setsid ()
                                          in if g = E.getpid () andalso E.getpgrp () = g then C.w8 3 else C.w8 4 end))
  val () = eqSt ("Posix.ProcEnv.setsid/group-leader-raises", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (E.setpgid {pid = NONE, pgid = NONE}; ignore (E.setsid ()); C.w8 4)
                                          handle OS.SysErr _ => C.w8 3))

  (* getlogin: "The user name associated with the calling process". Without
     a terminal the system may not know it (OS.SysErr); if it does, it is a
     user of the system. *)
  val () = eqB ("Posix.ProcEnv.getlogin/user-or-SysErr", true,
                fn () => (ignore (Posix.SysDB.getpwnam (E.getlogin ())); true) handle OS.SysErr _ => true)

  (* ---- uname: "A list of name-value pairs including, at least, the names:
     "sysname", "nodename", "release", "version", and "machine"" ---- *)
  fun unameOf (name : string) : string option =
    Option.map #2 (List.find (fn (n, _) => n = name) (E.uname ()))
  fun uname (label, option, name) = agreeS (label, fn () => SOME (C.shell ("uname " ^ option)), fn () => unameOf name)
  val () = uname ("Posix.ProcEnv.uname/sysname", "-s", "sysname")
  val () = uname ("Posix.ProcEnv.uname/nodename", "-n", "nodename")
  val () = uname ("Posix.ProcEnv.uname/release", "-r", "release")
  val () = uname ("Posix.ProcEnv.uname/version", "-v", "version")
  val () = uname ("Posix.ProcEnv.uname/machine", "-m", "machine")
  val () = eqB ("Posix.ProcEnv.uname/names-once", true,
                fn () => List.all (fn n => List.length (List.filter (fn (m, _) => m = n) (E.uname ())) = 1)
                                  ["sysname", "nodename", "release", "version", "machine"])

  (* ---- time: "The elapsed wall time since the Epoch" ---- *)
  val () = eqB ("Posix.ProcEnv.time/now", true,
                fn () => let val (a, b) = (Time.now (), E.time ())
                         in Time.< (if Time.< (a, b) then Time.- (b, a) else Time.- (a, b), C.secs 5) end)
  val () = eqB ("Posix.ProcEnv.time/date", true,
                fn () => case LargeInt.fromString (C.shell "date +%s") of
                           SOME s => LargeInt.<= (LargeInt.abs (LargeInt.- (Time.toSeconds (E.time ()), s)), LargeInt.fromInt 5)
                         | NONE => false)

  (* ---- times: "the wall time (elapsed), user time (utime), system time
     (stime), user CPU time of terminated child processes (cutime), and
     system CPU time of terminated child processes (cstime)" ---- *)
  fun cpu () = let val t = E.times () in Time.+ (#utime t, #stime t) end
  fun children () = let val t = E.times () in Time.+ (#cutime t, #cstime t) end
  val () = eqB ("Posix.ProcEnv.times/not-negative", true,
                fn () => let val {elapsed, utime, stime, cutime, cstime} = E.times ()
                         in List.all (fn t => Time.>= (t, Time.zeroTime)) [elapsed, utime, stime, cutime, cstime] end)
  val () = eqB ("Posix.ProcEnv.times/elapsed-is-wall-time", true,
                fn () => let
                           val t0 = #elapsed (E.times ())
                           val () = OS.Process.sleep (C.ms 300)
                           val d = Time.- (#elapsed (E.times ()), t0)
                         in
                           Time.>= (d, C.ms 200) andalso Time.< (d, C.secs 10)
                         end)
  (* Work makes the CPU time of the process grow (up to 10 s of it). *)
  val () = eqB ("Posix.ProcEnv.times/cpu-time-grows", true,
                fn () => let
                           val t0 = cpu ()
                           fun work (n, acc) = if n = 0 then acc else work (n - 1, (acc * 31 + n) mod 1000003)
                         in
                           C.until (10, fn () => (ignore (work (100000, 1)); Time.> (cpu (), t0)))
                         end)
  (* A child that works and has been waited for adds to cutime and cstime;
     one that sleeps does not add to utime. *)
  val () = eqB ("Posix.ProcEnv.times/children", true,
                fn () => let
                           val t0 = children ()
                           val _ = C.status (C.fork (fn () =>
                                     P.exec ("/bin/sh", ["sh", "-c", "i=0; while [ $i -lt 300000 ]; do i=$((i+1)); done"])))
                         in
                           Time.> (children (), t0)
                         end)

  (* ---- environment: getenv "is equivalent to OS.Process.getEnv" ---- *)
  val () = eqB ("Posix.ProcEnv.getenv/PATH", true,
                fn () => isSome (E.getenv "PATH") andalso E.getenv "PATH" = OS.Process.getEnv "PATH")
  val () = T.eq (T.option T.string) ("Posix.ProcEnv.getenv/unset", NONE,
                                     fn () => E.getenv "RUNE_BASIS_SUITE_SURELY_UNSET_VARIABLE")
  val () = eqB ("Posix.ProcEnv.getenv/shell", true,
                fn () => E.getenv "PATH" = SOME (C.shell "printf '%s\\n' \"$PATH\""))
  fun split (s : string) : string * string =
    let val (n, v) = Substring.splitl (fn c => c <> #"=") (Substring.full s)
    in (Substring.string n, Substring.string (Substring.triml 1 v)) end
  val () = eqB ("Posix.ProcEnv.environ/has-PATH", true,
                fn () => case E.getenv "PATH" of
                           SOME p => List.exists (fn s => s = "PATH=" ^ p) (E.environ ())
                         | NONE => false)
  val () = eqB ("Posix.ProcEnv.environ/name-value", true,
                fn () => List.all (fn s => Char.contains s #"=") (E.environ ()))
  val () = eqB ("Posix.ProcEnv.environ/getenv-agrees", true,
                fn () => List.all (fn s => let val (n, v) = split s
                                           in n = "" orelse isSome (E.getenv n) end)
                                  (E.environ ()))
  val () = eqB ("Posix.ProcEnv.environ/no-unset", true,
                fn () => not (List.exists (String.isPrefix "RUNE_BASIS_SUITE_SURELY_UNSET_VARIABLE=") (E.environ ())))

  (* ---- terminals ---- *)
  (* "A string that represents the pathname of the controlling terminal". *)
  val () = eqB ("Posix.ProcEnv.ctermid/pathname", true,
                fn () => String.isPrefix "/" (E.ctermid ()))
  val stdin = Posix.FileSys.wordToFD 0w0
  (* ttyname "raises OS.SysErr if fd does not denote a valid terminal
     device"; isatty "returns true if fd is a valid file descriptor
     associated with a terminal. Note that isatty will return false if fd is
     a bad file descriptor." *)
  val () = T.raises ("Posix.ProcEnv.ttyname/dev-null", fn OS.SysErr _ => true | _ => false,
                     fn () => E.ttyname stdin)
  val () = T.raises ("Posix.ProcEnv.ttyname/bad-descriptor", fn OS.SysErr _ => true | _ => false,
                     fn () => E.ttyname (Posix.FileSys.wordToFD 0w1000))
  val () = eqB ("Posix.ProcEnv.isatty/dev-null", false, fn () => E.isatty stdin)
  val () = eqB ("Posix.ProcEnv.isatty/bad-descriptor", false, fn () => E.isatty (Posix.FileSys.wordToFD 0w1000))
  (*<< pipe *)
  val () = T.eq (T.pair (T.bool, T.bool)) ("Posix.ProcEnv.isatty/pipe", (false, true),
                fn () => let
                           val {infd, outfd} = Posix.IO.pipe ()
                           val r = (E.isatty infd, (ignore (E.ttyname outfd); false) handle OS.SysErr _ => true)
                         in
                           Posix.IO.close infd; Posix.IO.close outfd; r
                         end)
  (*>> pipe *)

  (* ---- sysconf: "returns the integer value for the POSIX configurable
     system variable s. It raises OS.SysErr if s does not denote a supported
     POSIX system variable." ---- *)
  fun sysconf (label, name, getconf) =
    agreeW (label, fn () => C.shellWord ("getconf " ^ getconf), fn () => SOME (E.sysconf name))
  val () = sysconf ("Posix.ProcEnv.sysconf/ARG_MAX", "ARG_MAX", "ARG_MAX")
  val () = sysconf ("Posix.ProcEnv.sysconf/CHILD_MAX", "CHILD_MAX", "CHILD_MAX")
  val () = sysconf ("Posix.ProcEnv.sysconf/CLK_TCK", "CLK_TCK", "CLK_TCK")
  val () = sysconf ("Posix.ProcEnv.sysconf/NGROUPS_MAX", "NGROUPS_MAX", "NGROUPS_MAX")
  val () = sysconf ("Posix.ProcEnv.sysconf/OPEN_MAX", "OPEN_MAX", "OPEN_MAX")
  val () = sysconf ("Posix.ProcEnv.sysconf/STREAM_MAX", "STREAM_MAX", "STREAM_MAX")
  val () = sysconf ("Posix.ProcEnv.sysconf/JOB_CONTROL", "JOB_CONTROL", "_POSIX_JOB_CONTROL")
  val () = sysconf ("Posix.ProcEnv.sysconf/SAVED_IDS", "SAVED_IDS", "_POSIX_SAVED_IDS")
  val () = sysconf ("Posix.ProcEnv.sysconf/VERSION", "VERSION", "_POSIX_VERSION")
  (* TZNAME_MAX may have no limit (getconf prints "undefined"): then there is
     no value to give. *)
  val () = eqB ("Posix.ProcEnv.sysconf/TZNAME_MAX", true,
                fn () => case C.shellWord "getconf TZNAME_MAX" of
                           SOME w => E.sysconf "TZNAME_MAX" = w
                         | NONE => ((ignore (E.sysconf "TZNAME_MAX"); true) handle OS.SysErr _ => true))
  val () = eqB ("Posix.ProcEnv.sysconf/CLK_TCK-positive", true, fn () => E.sysconf "CLK_TCK" > 0w0)
  val () = T.raises ("Posix.ProcEnv.sysconf/unknown", fn OS.SysErr _ => true | _ => false,
                     fn () => E.sysconf "NO_SUCH_VARIABLE")

  val () = List.app (fn f => OS.FileSys.remove f handle _ => ())
                    ["pgid-set.txt", "pgid-moved.txt", "leader-ready.txt", "posix-shell-out.txt"]
end
