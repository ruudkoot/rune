(* requires: Posix OS TextIO *)
(* uses: fn/posix_child.sml *)
(* Posix.Process (signature POSIX_PROCESS). Expected values follow the text
   of https://smlfamily.github.io/Basis/posix-process.html and, for W, of
   https://smlfamily.github.io/Basis/bit-flags.html.

   Children that run SML code end by executing /bin/sh (PosixChild.leave),
   except in the checks of exit itself, which wait for them with a time
   limit (fn/posix_child.sml says why). Every check waits for the children it
   makes, so that wait and W_ANY_CHILD see only their own. *)
structure TestPosixProcess =
struct
  structure P = Posix.Process
  structure C = PosixChild
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqSt = T.eq C.showStatus
  val showW = fn w => "0wx" ^ SysWord.toString w
  val dec = SysWord.fmt StringCvt.DEC

  fun sh (script : string) () : unit = P.exec ("/bin/sh", ["sh", "-c", script])

  (* ---- pid ---- *)
  val () = eqB ("Posix.Process.pidToWord/wordToPid", true,
                fn () => let val p = Posix.ProcEnv.getpid () in P.wordToPid (P.pidToWord p) = p end)
  val () = eqB ("Posix.Process.pidToWord/positive", true,
                fn () => P.pidToWord (Posix.ProcEnv.getpid ()) > 0w0)
  (* "there is no validation that a pid value generated using wordToPid is
     legal on the given system" *)
  val () = T.eq showW ("Posix.Process.wordToPid/no-validation", 0w4000000,
                       fn () => P.pidToWord (P.wordToPid 0w4000000))

  (* ---- fork: "returns NONE in the child process, and the pid of the child
     in the parent process" ---- *)
  val () = eqS ("Posix.Process.fork/pid-of-child", "same",
                fn () => let
                           val pid = C.spawn (fn () =>
                                       (C.write ("fork-pid.txt", dec (P.pidToWord (Posix.ProcEnv.getpid ()))); C.w8 0))
                         in
                           ignore (C.status pid);
                           if C.slurp "fork-pid.txt" = dec (P.pidToWord pid) then "same" else "different"
                         end)
  val () = eqB ("Posix.Process.fork/parent-keeps-pid", true,
                fn () => let val parent = Posix.ProcEnv.getpid ()
                         in ignore (C.run (fn () => C.w8 0)); Posix.ProcEnv.getpid () = parent end)
  (* "The new child process is a copy of the calling parent process" *)
  val () = eqSt ("Posix.Process.fork/child-is-a-copy", P.W_EXITSTATUS (C.w8 42),
                 fn () => let val r = ref 41 in r := 42; C.run (fn () => Word8.fromInt (!r)) end)
  val () = eqB ("Posix.Process.fork/child-changes-are-its-own", true,
                fn () => let val r = ref 1 in ignore (C.run (fn () => (r := 2; C.w8 0))); !r = 1 end)

  (* ---- wait, waitpid ---- *)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.wait/child", (true, P.W_EXITSTATUS (C.w8 9)),
                fn () => let val pid = C.spawn (fn () => C.w8 9) val (p, s) = P.wait () in (p = pid, s) end)
  (* "If status information is available prior to the execution of wait,
     return is immediate." *)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.wait/already-ended", (true, P.W_EXITSTATUS (C.w8 8)),
                fn () => let
                           val pid = C.spawn (fn () => C.w8 8)
                         in
                           OS.Process.sleep (C.ms 300);
                           let val (p, s) = P.wait () in (p = pid, s) end
                         end)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.W_ANY_CHILD/child", (true, P.W_EXITSTATUS (C.w8 7)),
                fn () => let val pid = C.spawn (fn () => C.w8 7) val (p, s) = P.waitpid (P.W_ANY_CHILD, []) in (p = pid, s) end)
  (* W_CHILD waits for that child, not for another that ends first. *)
  val () = T.eq (T.list C.showStatus) ("Posix.Process.W_CHILD/that-child", [P.W_EXITSTATUS (C.w8 2), P.W_EXITSTATUS (C.w8 1)],
                fn () => let
                           val first = C.spawn (fn () => C.w8 1)
                           val second = C.fork (sh "sleep 1; exit 2")
                           val (p2, s2) = P.waitpid (P.W_CHILD second, [])
                           val (p1, s1) = P.waitpid (P.W_CHILD first, [])
                         in
                           if p2 = second andalso p1 = first then [s2, s1] else []
                         end)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.W_SAME_GROUP/child", (true, P.W_EXITSTATUS (C.w8 6)),
                fn () => let val pid = C.spawn (fn () => C.w8 6) val (p, s) = P.waitpid (P.W_SAME_GROUP, []) in (p = pid, s) end)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.W_GROUP/own-group", (true, P.W_EXITSTATUS (C.w8 5)),
                fn () => let
                           val pid = C.spawn (fn () => C.w8 5)
                           val (p, s) = P.waitpid (P.W_GROUP (Posix.ProcEnv.getpgrp ()), [])
                         in (p = pid, s) end)
  (* A child that leads a group of its own: W_GROUP of that group finds it.
     Parent and child both make the group, so that it exists whichever runs
     first. *)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.W_GROUP/group-of-child", (true, P.W_EXITSTATUS (C.w8 4)),
                fn () => let
                           val pid = C.spawn (fn () => (Posix.ProcEnv.setpgid {pid = NONE, pgid = NONE}; C.w8 4))
                           val () = Posix.ProcEnv.setpgid {pid = SOME pid, pgid = NONE} handle OS.SysErr _ => ()
                           val (p, s) = P.waitpid (P.W_GROUP pid, [])
                         in (p = pid, s) end)
  val () = T.raises ("Posix.Process.waitpid/no-child", fn OS.SysErr _ => true | _ => false,
                     fn () => P.waitpid (P.W_ANY_CHILD, []))
  val () = T.raises ("Posix.Process.wait/no-child", fn OS.SysErr _ => true | _ => false, fn () => P.wait ())

  (* ---- exit_status: "terminate successfully, terminate with the given
     value, terminate upon receipt of the given signal, and stop upon
     receipt of the given signal. The value carried by W_EXITSTATUS must
     never be zero." ---- *)
  val () = eqSt ("Posix.Process.W_EXITED/exit-0", P.W_EXITED, fn () => C.status (C.fork (sh "exit 0")))
  val () = eqSt ("Posix.Process.W_EXITSTATUS/exit-3", P.W_EXITSTATUS (C.w8 3), fn () => C.status (C.fork (sh "exit 3")))
  val () = eqSt ("Posix.Process.W_EXITSTATUS/exit-255", P.W_EXITSTATUS (C.w8 255), fn () => C.status (C.fork (sh "exit 255")))
  val () = eqSt ("Posix.Process.W_EXITSTATUS/exit-256-is-0", P.W_EXITED, fn () => C.status (C.fork (sh "exit 256")))
  val () = eqSt ("Posix.Process.W_SIGNALED/term", P.W_SIGNALED Posix.Signal.term,
                 fn () => C.status (C.fork (sh "kill -TERM $$")))
  (* stopped: reported to waitpid with W.untraced. *)
  val () = T.eq (T.list (T.option C.showStatus)) ("Posix.Process.W_STOPPED/stop",
                                                  [SOME (P.W_STOPPED Posix.Signal.stop), SOME (P.W_EXITSTATUS (C.w8 7))],
                fn () => let
                           val pid = C.fork (sh "kill -STOP $$; exit 7")
                           val s = C.stopped pid
                         in
                           P.kill (P.K_PROC pid, Posix.Signal.cont);
                           [s, C.waitBounded pid]
                         end)

  (* ---- exec, exece, execp ---- *)
  val () = eqSt ("Posix.Process.exec/status", P.W_EXITSTATUS (C.w8 5),
                 fn () => C.status (C.fork (fn () => P.exec ("/bin/sh", ["sh", "-c", "exit 5"]))))
  (* "The args argument is a list of string arguments to be passed to the
     new program. By convention, the first item in args is some form of the
     filename of the new program": it is the program's argument 0. *)
  val () = eqS ("Posix.Process.exec/args", "2:a:b c:",
                fn () => (ignore (C.status (C.fork (fn () =>
                            P.exec ("/bin/sh", ["sh", "-c", "printf '%s:%s:%s:' $# \"$1\" \"$2\" > exec-args.txt",
                                                "name", "a", "b c"]))));
                          C.slurp "exec-args.txt"))
  val () = eqS ("Posix.Process.exec/argument-0", "custom-name",
                fn () => (ignore (C.status (C.fork (fn () =>
                            P.exec ("/bin/sh", ["custom-name", "-c", "printf %s \"$0\" > exec-arg0.txt"]))));
                          C.slurp "exec-arg0.txt"))
  (* The new image is the same process. *)
  val () = eqS ("Posix.Process.exec/same-process", "same",
                fn () => let val pid = C.fork (sh "printf %s $$ > exec-pid.txt")
                         in ignore (C.status pid);
                            if C.slurp "exec-pid.txt" = dec (P.pidToWord pid) then "same" else "different"
                         end)
  (* "Normally, the new image is given the same environment as the calling
     program." *)
  val () = eqB ("Posix.Process.exec/same-environment", true,
                fn () => (ignore (C.status (C.fork (sh "printf %s \"$PATH\" > exec-path.txt")));
                          SOME (C.slurp "exec-path.txt") = OS.Process.getEnv "PATH"))
  (* "In the first two forms, the path argument specifies the pathname of
     the executable file": a name without a slash is not looked for on
     PATH. *)
  val () = eqSt ("Posix.Process.exec/not-searched", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (P.exec ("sh", ["sh", "-c", "exit 0"]); C.w8 1)
                                          handle OS.SysErr _ => C.w8 3))
  (* "There is no return from a successful call"; a failed one raises. *)
  val () = eqSt ("Posix.Process.exec/missing-file-raises", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (P.exec ("./no-such-program", ["no-such-program"]); C.w8 1)
                                          handle OS.SysErr (_, SOME e) => if e = Posix.Error.noent then C.w8 3 else C.w8 4))
  (* "The env argument in exece allows the program to specify a new
     environment." *)
  val () = eqSt ("Posix.Process.exece/environment", P.W_EXITSTATUS (C.w8 4),
                 fn () => C.status (C.fork (fn () =>
                            P.exece ("/bin/sh", ["sh", "-c", "test \"$A:$B\" = \"1:two words\" && test -z \"${HOME+set}\" && exit 4; exit 5"],
                                     ["A=1", "B=two words"]))))
  val () = eqSt ("Posix.Process.exece/empty-environment", P.W_EXITSTATUS (C.w8 4),
                 fn () => C.status (C.fork (fn () =>
                            P.exece ("/bin/sh", ["sh", "-c", "test -z \"${HOME+set}${A+set}\" && exit 4; exit 5"], []))))
  val () = eqSt ("Posix.Process.exece/missing-file-raises", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (P.exece ("./no-such-program", ["no-such-program"], []); C.w8 1)
                                          handle OS.SysErr _ => C.w8 3))
  (* "if file contains a slash character, it is treated as the pathname for
     the executable file; otherwise, an executable file with name file is
     searched for in the directories specified by the environment variable
     PATH." *)
  val () = eqSt ("Posix.Process.execp/searched", P.W_EXITSTATUS (C.w8 6),
                 fn () => C.status (C.fork (fn () => P.execp ("sh", ["sh", "-c", "exit 6"]))))
  val () = eqSt ("Posix.Process.execp/with-slash", P.W_EXITSTATUS (C.w8 4),
                 fn () => (C.write ("execp-script", "#!/bin/sh\nexit 4\n");
                           Posix.FileSys.chmod ("execp-script", Posix.FileSys.S.irwxu);
                           C.status (C.fork (fn () => P.execp ("./execp-script", ["execp-script"])))))
  val () = eqSt ("Posix.Process.execp/missing-raises", P.W_EXITSTATUS (C.w8 3),
                 fn () => C.run (fn () => (P.execp ("rune-basis-suite-no-such-program", ["x"]); C.w8 1)
                                          handle OS.SysErr _ => C.w8 3))

  (* ---- waitpid_nh: "the call does not suspend if status information for
     one of the children specified by procs is not immediately
     available" ---- *)
  val () = T.eq (T.pair (T.bool, C.showStatus)) ("Posix.Process.waitpid_nh/running-child", (true, P.W_SIGNALED Posix.Signal.kill),
                fn () => let
                           val pid = C.fork (sh "exec sleep 10")
                           val r = P.waitpid_nh (P.W_CHILD pid, [])
                         in
                           P.kill (P.K_PROC pid, Posix.Signal.kill);
                           (r = NONE, C.status pid)
                         end)
  val () = T.eq (T.option C.showStatus) ("Posix.Process.waitpid_nh/ended-child", SOME (P.W_EXITSTATUS (C.w8 3)),
                fn () => let
                           val pid = C.fork (sh "exit 3")
                           val got = ref NONE
                         in
                           ignore (C.until (10, fn () => case P.waitpid_nh (P.W_CHILD pid, []) of
                                                           SOME (p, s) => (got := SOME (if p = pid then s else P.W_EXITED); true)
                                                         | NONE => false));
                           !got
                         end)
  val () = T.raises ("Posix.Process.waitpid_nh/no-child", fn OS.SysErr _ => true | _ => false,
                     fn () => P.waitpid_nh (P.W_ANY_CHILD, []))

  (* ---- W: BIT_FLAGS and untraced ---- *)
  val w = P.W.toWord
  val () = eqB ("Posix.Process.W.untraced/in-all", true, fn () => P.W.allSet (P.W.untraced, P.W.all))
  val () = eqB ("Posix.Process.W.untraced/nonempty", true, fn () => w P.W.untraced <> 0w0)
  (* "In systems supporting job control, this flag requests the status of
     child processes that are stopped": W_STOPPED/stop above, and waitpid
     without it does not report a stopped child. *)
  val () = eqB ("Posix.Process.W.untraced/waitpid-without-it", true,
                fn () => let
                           val pid = C.fork (sh "kill -STOP $$; exit 7")
                           val () = OS.Process.sleep (C.ms 300)
                           val r = P.waitpid_nh (P.W_CHILD pid, [])
                         in
                           P.kill (P.K_PROC pid, Posix.Signal.kill);
                           ignore (C.status pid);
                           r = NONE
                         end)
  (* BIT_FLAGS: "flags [] denotes the empty set", "intersect [] denotes
     all", clear is the set difference, allSet inclusion, anySet a non-empty
     intersection, "fromWord o toWord must be the identity function, and
     toWord o fromWord must be equivalent to fn w => SysWord.andb (w, toWord
     all)". *)
  val () = T.eq showW ("Posix.Process.W.flags/empty", 0w0, fn () => w (P.W.flags []))
  val () = eqB ("Posix.Process.W.flags/one", true, fn () => P.W.flags [P.W.untraced] = P.W.untraced)
  val () = eqB ("Posix.Process.W.flags/union", true,
                fn () => w (P.W.flags [P.W.untraced, P.W.all]) = SysWord.orb (w P.W.untraced, w P.W.all))
  val () = eqB ("Posix.Process.W.all/union-of-all", true,
                fn () => P.W.flags [P.W.all, P.W.untraced] = P.W.all)
  val () = eqB ("Posix.Process.W.intersect/empty-is-all", true, fn () => P.W.intersect [] = P.W.all)
  val () = eqB ("Posix.Process.W.intersect/two", true,
                fn () => P.W.intersect [P.W.untraced, P.W.all] = P.W.untraced
                         andalso P.W.intersect [P.W.untraced, P.W.flags []] = P.W.flags [])
  val () = eqB ("Posix.Process.W.clear/difference", true,
                fn () => P.W.clear (P.W.untraced, P.W.untraced) = P.W.flags []
                         andalso P.W.clear (P.W.flags [], P.W.untraced) = P.W.untraced)
  val () = eqB ("Posix.Process.W.clear/formula", true,
                fn () => P.W.clear (P.W.untraced, P.W.all)
                         = P.W.fromWord (SysWord.andb (SysWord.notb (w P.W.untraced), w P.W.all)))
  val () = eqB ("Posix.Process.W.allSet/inclusion", true,
                fn () => P.W.allSet (P.W.untraced, P.W.all) andalso P.W.allSet (P.W.flags [], P.W.untraced)
                         andalso not (P.W.allSet (P.W.untraced, P.W.flags [])))
  val () = eqB ("Posix.Process.W.anySet/intersection", true,
                fn () => P.W.anySet (P.W.untraced, P.W.all) andalso not (P.W.anySet (P.W.flags [], P.W.all))
                         andalso not (P.W.anySet (P.W.untraced, P.W.flags [])))
  val () = eqB ("Posix.Process.W.fromWord/of-toWord", true,
                fn () => P.W.fromWord (w P.W.untraced) = P.W.untraced andalso P.W.fromWord (w P.W.all) = P.W.all)
  val () = eqB ("Posix.Process.W.toWord/of-fromWord", true,
                fn () => List.all (fn x => w (P.W.fromWord x) = SysWord.andb (x, w P.W.all))
                                  [0w0, 0w1, 0w2, 0w3, 0w255, SysWord.notb 0w0])

  (* ---- fromStatus: "returns a concrete view of the given status" ---- *)
  val () = eqSt ("Posix.Process.fromStatus/success", P.W_EXITED, fn () => P.fromStatus OS.Process.success)
  val () = eqB ("Posix.Process.fromStatus/failure", true,
                fn () => case P.fromStatus OS.Process.failure of P.W_EXITSTATUS w => w <> C.w8 0 | _ => false)
  val () = eqSt ("Posix.Process.fromStatus/system-exit-0", P.W_EXITED, fn () => P.fromStatus (OS.Process.system "exit 0"))
  val () = eqSt ("Posix.Process.fromStatus/system-exit-3", P.W_EXITSTATUS (C.w8 3), fn () => P.fromStatus (OS.Process.system "exit 3"))
  val () = eqSt ("Posix.Process.fromStatus/system-exit-200", P.W_EXITSTATUS (C.w8 200),
                 fn () => P.fromStatus (OS.Process.system "exit 200"))
  val () = eqSt ("Posix.Process.fromStatus/system-killed", P.W_SIGNALED Posix.Signal.term,
                 fn () => P.fromStatus (OS.Process.system "kill -TERM $$"))

  (* ---- kill ---- *)
  (* A program that has started (it wrote the file name) and sleeps. *)
  fun sleeper (name : string) (setGroup : bool) : P.pid =
    C.fork (fn () => (if setGroup then Posix.ProcEnv.setpgid {pid = NONE, pgid = NONE} else ();
                      P.exec ("/bin/sh", ["sh", "-c", ": > " ^ name ^ "; exec sleep 10"])))
  val () = eqSt ("Posix.Process.kill/term", P.W_SIGNALED Posix.Signal.term,
                 fn () => let val pid = sleeper "kill-ready.txt" false
                          in ignore (C.appears "kill-ready.txt"); P.kill (P.K_PROC pid, Posix.Signal.term); C.status pid end)
  val () = eqSt ("Posix.Process.K_PROC/kill", P.W_SIGNALED Posix.Signal.kill,
                 fn () => let val pid = C.fork (sh "exec sleep 10")
                          in P.kill (P.K_PROC pid, Posix.Signal.kill); C.status pid end)
  val () = T.raises ("Posix.Process.kill/no-such-process", fn OS.SysErr _ => true | _ => false,
                     fn () => let val pid = C.fork (sh "exit 0")
                              in ignore (C.status pid); P.kill (P.K_PROC pid, Posix.Signal.term) end)
  val () = eqSt ("Posix.Process.K_GROUP/term", P.W_SIGNALED Posix.Signal.term,
                 fn () => let val pid = sleeper "group-ready.txt" true
                          in
                            Posix.ProcEnv.setpgid {pid = SOME pid, pgid = NONE} handle OS.SysErr _ => ();
                            ignore (C.appears "group-ready.txt");
                            P.kill (P.K_GROUP pid, Posix.Signal.term);
                            C.status pid
                          end)
  (* All processes of our group, this one included, get cont: a stopped
     child continues, and this process, which is not stopped, goes on. *)
  val () = T.eq (T.list (T.option C.showStatus)) ("Posix.Process.K_SAME_GROUP/cont",
                                                  [SOME (P.W_STOPPED Posix.Signal.stop), SOME (P.W_EXITSTATUS (C.w8 7))],
                fn () => let
                           val pid = C.fork (sh "kill -STOP $$; exit 7")
                           val s = C.stopped pid
                         in
                           P.kill (P.K_SAME_GROUP, Posix.Signal.cont);
                           [s, C.waitBounded pid]
                         end)

  (* ---- alarm, pause, sleep ---- *)
  (* "If there is a previous alarm request with time remaining, the alarm
     function returns a nonzero value corresponding to the number of seconds
     remaining on the previous request. Zero time is returned if there are
     no outstanding calls." An alarm of zero seconds asks for none (POSIX),
     so the alarm of this process is cancelled again. *)
  val () = eqB ("Posix.Process.alarm/none-outstanding", true,
                fn () => let val r = P.alarm (C.secs 100)
                         in ignore (P.alarm Time.zeroTime); r = Time.zeroTime end)
  val () = eqB ("Posix.Process.alarm/remaining", true,
                fn () => let
                           val _ = P.alarm (C.secs 100)
                           val r = P.alarm Time.zeroTime
                         in
                           Time.<= (C.secs 90, r) andalso Time.<= (r, C.secs 100)
                         end)
  val () = eqB ("Posix.Process.alarm/cancelled", true, fn () => P.alarm Time.zeroTime = Time.zeroTime)
  (* "causes the system to send an alarm signal (alrm) to the calling
     process after t seconds", whose default action ends it; pause "suspends
     the calling process until the delivery of a signal that is either
     caught or that terminates the process". *)
  val () = T.eq (T.option C.showStatus) ("Posix.Process.pause/until-alarm", SOME (P.W_SIGNALED Posix.Signal.alrm),
                fn () => C.waitBounded (C.spawn (fn () => (ignore (P.alarm (C.secs 1)); P.pause (); C.w8 1))))
  val () = T.eq (T.pair (T.bool, T.option C.showStatus)) ("Posix.Process.pause/until-signal", (true, SOME (P.W_SIGNALED Posix.Signal.usr1)),
                fn () => let
                           val pid = C.spawn (fn () => (P.pause (); C.w8 1))
                           val () = OS.Process.sleep (C.ms 300)
                           val waiting = P.waitpid_nh (P.W_CHILD pid, []) = NONE
                         in
                           P.kill (P.K_PROC pid, Posix.Signal.usr1);
                           (waiting, C.waitBounded pid)
                         end)
  (* "suspended from execution until either t seconds have elapsed, or until
     the receipt of a signal". The page does not say what the result is;
     POSIX sleep returns the time that is left, which is (about) nothing
     here. *)
  val () = eqB ("Posix.Process.sleep/one-second", true,
                fn () => let
                           val start = Time.now ()
                           val r = P.sleep (C.secs 1)
                         in
                           Time.< (r, C.ms 100)
                           andalso Time.>= (Time.- (Time.now (), start), C.ms 900)
                         end)
  val () = eqB ("Posix.Process.sleep/zero", true,
                fn () => let
                           val start = Time.now ()
                           val r = P.sleep Time.zeroTime
                         in
                           r = Time.zeroTime andalso Time.< (Time.- (Time.now (), start), C.secs 1)
                         end)

  (* ---- exit: "terminates the calling process ... the exit status i is
     made available to it"; it "does not flush or close any open IO
     streams, nor does it call OS.Process.atExit". ---- *)
  (*<< exit *)
  val () = T.eq (T.option C.showStatus) ("Posix.Process.exit/status", SOME (P.W_EXITSTATUS (C.w8 7)),
                fn () => C.waitBounded (C.fork (fn () => P.exit (C.w8 7))))
  val () = T.eq (T.option C.showStatus) ("Posix.Process.exit/zero", SOME P.W_EXITED,
                fn () => C.waitBounded (C.fork (fn () => P.exit (C.w8 0))))
  val () = T.eq (T.pair (T.option C.showStatus, T.bool)) ("Posix.Process.exit/no-atExit", (SOME (P.W_EXITSTATUS (C.w8 3)), false),
                fn () => let
                           val pid = C.fork (fn () =>
                                       (OS.Process.atExit (fn () => C.write ("exit-atexit.txt", "ran"));
                                        P.exit (C.w8 3)))
                           val s = C.waitBounded pid
                         in
                           (s, OS.FileSys.access ("exit-atexit.txt", []))
                         end)
  val () = T.eq (T.pair (T.option C.showStatus, T.string)) ("Posix.Process.exit/no-flush", (SOME (P.W_EXITSTATUS (C.w8 3)), ""),
                fn () => let
                           val pid = C.fork (fn () =>
                                       let val out = TextIO.openOut "exit-unflushed.txt"
                                       in
                                         TextIO.StreamIO.setBufferMode (TextIO.getOutstream out, IO.BLOCK_BUF);
                                         TextIO.output (out, "buffered");
                                         P.exit (C.w8 3)
                                       end)
                           val s = C.waitBounded pid
                         in
                           (s, C.slurp "exit-unflushed.txt")
                         end)
  (* The result has any type. *)
  val () = T.eq T.int ("Posix.Process.exit/result-has-any-type", 1,
                       fn () => if T.range (1, 1) = 1 then 1 else P.exit (C.w8 1))
  (*>> exit *)

  val () = List.app (fn f => OS.FileSys.remove f handle _ => ())
                    ["fork-pid.txt", "exec-args.txt", "exec-arg0.txt", "exec-pid.txt", "exec-path.txt", "execp-script",
                     "kill-ready.txt", "group-ready.txt", "exit-atexit.txt", "exit-unflushed.txt", "posix-shell-out.txt"]
end
