(* requires: Posix OS TextIO *)
(* uses: fn/posix_child.sml *)
(* Posix.Signal (signature POSIX_SIGNAL), after
   https://smlfamily.github.io/Basis/posix-signal.html: "The name of the
   corresponding POSIX signal can be derived by capitalizing all letters and
   adding the string SIG as a prefix". So the number of Posix.Signal.term is
   the one that `kill -l` of the shell names TERM, and a shell that sends
   itself SIGTERM ends with W_SIGNALED Posix.Signal.term. The signals whose
   default action dumps core (abrt, bus, fpe, ill, quit, segv) and those
   that a runner started in the background ignores (int, quit) or that only
   stop the process are checked by their number only. *)
structure TestPosixSignal =
struct
  structure S = Posix.Signal
  structure C = PosixChild
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val showW = fn w => "0wx" ^ SysWord.toString w

  (* named (label, NAME, s): kill -l names the number of s NAME, and toWord
     and fromWord convert it both ways. *)
  fun named (label, name, s) =
    (eqS (label ^ "kill-l", name, fn () => C.shell ("kill -l " ^ SysWord.fmt StringCvt.DEC (S.toWord s)));
     eqB (label ^ "toWord-fromWord", true, fn () => S.toWord s <> 0w0 andalso S.fromWord (S.toWord s) = s))

  val () = named ("Posix.Signal.abrt/", "ABRT", S.abrt)
  val () = named ("Posix.Signal.alrm/", "ALRM", S.alrm)
  val () = named ("Posix.Signal.bus/", "BUS", S.bus)
  val () = named ("Posix.Signal.fpe/", "FPE", S.fpe)
  val () = named ("Posix.Signal.hup/", "HUP", S.hup)
  val () = named ("Posix.Signal.ill/", "ILL", S.ill)
  val () = named ("Posix.Signal.int/", "INT", S.int)
  val () = named ("Posix.Signal.kill/", "KILL", S.kill)
  val () = named ("Posix.Signal.pipe/", "PIPE", S.pipe)
  val () = named ("Posix.Signal.quit/", "QUIT", S.quit)
  val () = named ("Posix.Signal.segv/", "SEGV", S.segv)
  val () = named ("Posix.Signal.term/", "TERM", S.term)
  val () = named ("Posix.Signal.usr1/", "USR1", S.usr1)
  val () = named ("Posix.Signal.usr2/", "USR2", S.usr2)
  val () = named ("Posix.Signal.chld/", "CHLD", S.chld)
  val () = named ("Posix.Signal.cont/", "CONT", S.cont)
  val () = named ("Posix.Signal.stop/", "STOP", S.stop)
  val () = named ("Posix.Signal.tstp/", "TSTP", S.tstp)
  val () = named ("Posix.Signal.ttin/", "TTIN", S.ttin)
  val () = named ("Posix.Signal.ttou/", "TTOU", S.ttou)

  val all = [S.abrt, S.alrm, S.bus, S.fpe, S.hup, S.ill, S.int, S.kill, S.pipe, S.quit,
             S.segv, S.term, S.usr1, S.usr2, S.chld, S.cont, S.stop, S.tstp, S.ttin, S.ttou]
  fun distinct [] = true
    | distinct (x :: r) = not (List.exists (fn y => y = x) r) andalso distinct r
  val () = eqB ("Posix.Signal.toWord/distinct", true, fn () => distinct (List.map S.toWord all))
  val () = eqB ("Posix.Signal.fromWord/of-toWord-all", true,
                fn () => List.all (fn s => S.fromWord (S.toWord s) = s) all)
  (* "fromWord does not check that the result corresponds to a valid POSIX
     signal" *)
  val () = T.eq showW ("Posix.Signal.fromWord/no-check", 0w200, fn () => S.toWord (S.fromWord 0w200))
  val () = eqB ("Posix.Signal.fromWord/equal-words-equal-signals", true,
                fn () => S.fromWord (S.toWord S.term) = S.term andalso S.fromWord (S.toWord S.hup) <> S.term)

  (* ---- delivery: a shell that sends itself the signal ---- *)
  fun selfKill (name : string) : Posix.Process.exit_status =
    C.status (C.fork (fn () => Posix.Process.exec ("/bin/sh", ["sh", "-c", "kill -" ^ name ^ " $$; exit 7"])))
  fun ends (label, name, s) =
    T.eq C.showStatus (label, Posix.Process.W_SIGNALED s, fn () => selfKill name)
  val () = ends ("Posix.Signal.term/ends-shell", "TERM", S.term)
  val () = ends ("Posix.Signal.hup/ends-shell", "HUP", S.hup)
  val () = ends ("Posix.Signal.kill/ends-shell", "KILL", S.kill)
  val () = ends ("Posix.Signal.alrm/ends-shell", "ALRM", S.alrm)
  val () = ends ("Posix.Signal.usr1/ends-shell", "USR1", S.usr1)
  val () = ends ("Posix.Signal.usr2/ends-shell", "USR2", S.usr2)
  val () = ends ("Posix.Signal.pipe/ends-shell", "PIPE", S.pipe)
  (* The default action of chld is to ignore it, and of cont to continue. *)
  val () = T.eq C.showStatus ("Posix.Signal.chld/ignored-by-default", Posix.Process.W_EXITSTATUS (C.w8 7),
                              fn () => selfKill "CHLD")
  val () = T.eq C.showStatus ("Posix.Signal.cont/continues", Posix.Process.W_EXITSTATUS (C.w8 7),
                              fn () => selfKill "CONT")
  (* stop stops the process: waitpid with W.untraced reports it. A watchdog
     continues the process after 5 seconds, so that a waitpid that does not
     report stopped processes returns all the same. *)
  val () = T.eq (T.list C.showStatus) ("Posix.Signal.stop/stops-shell",
                                       [Posix.Process.W_STOPPED S.stop, Posix.Process.W_EXITSTATUS (C.w8 7)],
                fn () =>
                  let
                    val pid = C.fork (fn () => Posix.Process.exec ("/bin/sh", ["sh", "-c", "kill -STOP $$; exit 7"]))
                    val word = SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord pid)
                    val dog = C.fork (fn () => Posix.Process.exec ("/bin/sh", ["sh", "-c", "sleep 5; kill -CONT " ^ word]))
                    val (_, first) = Posix.Process.waitpid (Posix.Process.W_CHILD pid, [Posix.Process.W.untraced])
                    val () = Posix.Process.kill (Posix.Process.K_PROC pid, S.cont) handle OS.SysErr _ => ()
                    val last = case first of Posix.Process.W_STOPPED _ => C.status pid | _ => first
                  in
                    Posix.Process.kill (Posix.Process.K_PROC dog, S.kill);
                    ignore (C.status dog);
                    [first, last]
                  end)
end
