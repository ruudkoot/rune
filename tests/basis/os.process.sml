(* requires: OS TextIO *)
(* OS.Process (signature OS_PROCESS) and the top level of OS (SysErr,
   errorMsg, errorName, syserror). Expected values follow the text of
   https://smlfamily.github.io/Basis/os-process.html and
   https://smlfamily.github.io/Basis/os.html.

   exit, terminate and the effect of atExit end the program, so that only
   their types and the registration can be checked here; see the atExit
   section for what a test of the finished process has to look at. The
   commands given to system assume a POSIX shell ("On Unix systems, the
   default shell is /bin/sh"). *)
structure TestOSProcess =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string

  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end

  (* ---- success, failure, isSuccess ---- *)
  val () = eqB ("OS.Process.success/isSuccess", true, fn () => OS.Process.isSuccess OS.Process.success)
  val () = eqB ("OS.Process.failure/not-isSuccess", false, fn () => OS.Process.isSuccess OS.Process.failure)
  val () = eqB ("OS.Process.isSuccess/twice", true,
                fn () => OS.Process.isSuccess OS.Process.success andalso OS.Process.isSuccess OS.Process.success)
  val () = eqB ("OS.Process.status/list-of-statuses", true,
                fn () => List.map OS.Process.isSuccess ([OS.Process.success, OS.Process.failure] : OS.Process.status list)
                         = [true, false])

  (* ---- exit, terminate: status -> 'a. They do not return, so their result
     has any type; the branch that calls them is not taken. ---- *)
  val () = T.eq T.int ("OS.Process.exit/result-has-any-type", 1,
                       fn () => if T.range (1, 1) = 1 then 1 else OS.Process.exit OS.Process.failure)
  val () = eqS ("OS.Process.exit/result-has-any-type-string", "kept",
                fn () => if T.range (1, 1) = 1 then "kept" else OS.Process.exit OS.Process.success)
  val () = T.eq T.int ("OS.Process.terminate/result-has-any-type", 1,
                       fn () => if T.range (1, 1) = 1 then 1 else OS.Process.terminate OS.Process.failure)
  val () = eqS ("OS.Process.terminate/result-has-any-type-string", "kept",
                fn () => if T.range (1, 1) = 1 then "kept" else OS.Process.terminate OS.Process.success)

  (* ---- OS.SysErr of string * syserror option ---- *)
  val () = eqS ("OS.SysErr/carries-message", "boom",
                fn () => (raise OS.SysErr ("boom", NONE)) handle OS.SysErr (s, NONE) => s | OS.SysErr (_, SOME _) => "SOME")
  val () = T.raises ("OS.SysErr/is-raised", fn OS.SysErr _ => true | _ => false,
                     fn () => raise OS.SysErr ("boom", NONE))
  val () = eqB ("OS.SysErr/is-not-Fail", false,
                fn () => (raise OS.SysErr ("boom", NONE)) handle Fail _ => true | _ => false)
  val () = eqB ("OS.SysErr/syserror-option-type", true,
                fn () => let val none : OS.syserror option = NONE
                         in (raise OS.SysErr ("m", none)) handle OS.SysErr ("m", NONE) => true | _ => false end)
  (* "OS.SysErr if an actual system call was done and failed": opening a file
     that does not exist. *)
  val () = eqB ("OS.SysErr/cause-of-failed-open", true,
                fn () => (TextIO.closeIn (TextIO.openIn "no-such-file.txt"); false)
                         handle IO.Io {cause = OS.SysErr _, ...} => true | _ => false)

  (*<< syserror *)
  (* sysErrOf f: the SysErr (s, SOME e) that is the cause of the Io that f raises. *)
  fun sysErrOf (f : unit -> unit) : (string * OS.syserror) option =
    (f (); NONE) handle IO.Io {cause = OS.SysErr (s, SOME e), ...} => SOME (s, e) | _ => NONE
  (* No such file; and a path through a plain file ("not a directory"). *)
  fun noEntry () = sysErrOf (fn () => TextIO.closeIn (TextIO.openIn "no-such-file.txt"))
  fun notDir () = (write ("plain.txt", "x"); sysErrOf (fn () => TextIO.closeIn (TextIO.openIn "plain.txt/x")))

  val () = eqB ("OS.SysErr/failed-open-has-syserror", true, fn () => isSome (noEntry ()) andalso isSome (notDir ()))
  (* "if a SysErr exception has the form SysErr(s,SOME e), then we have errorMsg e = s" *)
  val () = eqB ("OS.errorMsg/is-the-message-of-SysErr", true,
                fn () => case noEntry () of SOME (s, e) => OS.errorMsg e = s | NONE => false)
  val () = eqB ("OS.errorMsg/is-the-message-of-SysErr-notdir", true,
                fn () => case notDir () of SOME (s, e) => OS.errorMsg e = s | NONE => false)
  val () = eqB ("OS.errorMsg/nonempty", true,
                fn () => case noEntry () of SOME (_, e) => String.size (OS.errorMsg e) > 0 | NONE => false)
  (* "If e is a syserror, then it should be the case that SOME e = syserror(errorName e)" *)
  val () = eqB ("OS.errorName/syserror-inverts", true,
                fn () => case noEntry () of SOME (_, e) => SOME e = OS.syserror (OS.errorName e) | NONE => false)
  val () = eqB ("OS.syserror/inverts-errorName-notdir", true,
                fn () => case notDir () of SOME (_, e) => SOME e = OS.syserror (OS.errorName e) | NONE => false)
  (* "returns a unique name used for the syserror value" *)
  val () = eqB ("OS.errorName/unique", true,
                fn () => case (noEntry (), notDir ()) of
                           (SOME (_, e1), SOME (_, e2)) => e1 <> e2 andalso OS.errorName e1 <> OS.errorName e2
                         | _ => false)
  val () = eqB ("OS.errorName/stable", true,
                fn () => case (noEntry (), noEntry ()) of
                           (SOME (_, e1), SOME (_, e2)) => e1 = e2 andalso OS.errorName e1 = OS.errorName e2
                         | _ => false)
  (* "returns the syserror whose name is s, if it exists" *)
  val () = eqB ("OS.syserror/unknown-name", true,
                fn () => OS.syserror "no such error name in any system" = NONE)
  val () = eqB ("OS.syserror/empty-name", true, fn () => OS.syserror "" = NONE)
  val () = eqB ("OS.SysErr/carries-syserror", true,
                fn () => case noEntry () of
                           SOME (_, e) => ((raise OS.SysErr ("m", SOME e)) handle OS.SysErr (_, SOME e') => e' = e
                                                                                 | _ => false)
                         | NONE => false)
  (*>> syserror *)

  (*<< getEnv *)
  (* "returns the value of the environment variable s, if defined. Otherwise,
     it returns NONE." *)
  val () = T.eq (T.option T.string) ("OS.Process.getEnv/unset", NONE,
                                     fn () => OS.Process.getEnv "RUNE_BASIS_SUITE_SURELY_UNSET_VARIABLE")
  val () = eqB ("OS.Process.getEnv/PATH-is-set", true, fn () => isSome (OS.Process.getEnv "PATH"))
  val () = eqB ("OS.Process.getEnv/stable", true, fn () => OS.Process.getEnv "PATH" = OS.Process.getEnv "PATH")
  (* "scans the environment for a pair whose first component equals s": the
     whole name, not one that begins with it or has the value attached. *)
  val () = T.eq (T.option T.string) ("OS.Process.getEnv/name-that-extends-a-set-name", NONE,
                                     fn () => OS.Process.getEnv "PATH_RUNE_BASIS_SUITE_SURELY_UNSET")
  val () = eqB ("OS.Process.getEnv/name-with-value-attached", true,
                fn () => case OS.Process.getEnv "PATH" of
                           SOME v => OS.Process.getEnv ("PATH=" ^ v) = NONE
                         | NONE => false)
  (*>> getEnv *)

  (*<< system *)
  (* "passes the command string cmd to the operating system's default shell to
     execute. It returns the termination status resulting from executing the
     command." *)
  val () = eqB ("OS.Process.system/exit-0", true, fn () => OS.Process.isSuccess (OS.Process.system "exit 0"))
  val () = eqB ("OS.Process.system/exit-3", false, fn () => OS.Process.isSuccess (OS.Process.system "exit 3"))
  val () = eqB ("OS.Process.system/exit-1", false, fn () => OS.Process.isSuccess (OS.Process.system "exit 1"))
  val () = eqB ("OS.Process.system/exit-255", false, fn () => OS.Process.isSuccess (OS.Process.system "exit 255"))
  val () = eqB ("OS.Process.system/true", true, fn () => OS.Process.isSuccess (OS.Process.system "true"))
  val () = eqB ("OS.Process.system/false", false, fn () => OS.Process.isSuccess (OS.Process.system "false"))
  val () = eqB ("OS.Process.system/empty-command", true, fn () => OS.Process.isSuccess (OS.Process.system ""))
  (* The shell reports a command it cannot find with a failure status. *)
  val () = eqB ("OS.Process.system/unknown-command", false,
                fn () => OS.Process.isSuccess (OS.Process.system "rune-basis-suite-no-such-command 2> /dev/null"))
  (* A process that a signal ended has not succeeded ("isSuccess ... returns
     true only when Unix.fromStatus sts is Unix.W_EXITED"). *)
  val () = eqB ("OS.Process.isSuccess/killed-by-signal", false,
                fn () => OS.Process.isSuccess (OS.Process.system "kill -KILL $$"))
  (* It is a shell that runs the command (redirection, sequencing, variables),
     in the current directory, and system returns when the command is done. *)
  val () = eqS ("OS.Process.system/shell-redirection", "hello\n",
                fn () => (ignore (OS.Process.system "echo hello > system-echo.txt"); slurp "system-echo.txt"))
  val () = eqS ("OS.Process.system/current-directory", "copied by cat\n",
                fn () => (write ("system-in.txt", "copied by cat\n");
                          ignore (OS.Process.system "cat system-in.txt > system-copy.txt");
                          slurp "system-copy.txt"))
  val () = eqS ("OS.Process.system/shell-syntax", "a-b\n",
                fn () => (ignore (OS.Process.system "X=a; Y=b; if test \"$X\" = a; then echo \"$X-$Y\"; fi > system-syntax.txt");
                          slurp "system-syntax.txt"))
  val () = eqB ("OS.Process.system/status-of-last-command", false,
                fn () => OS.Process.isSuccess (OS.Process.system "true; false"))
  val () = eqB ("OS.Process.system/status-of-and-list", true,
                fn () => OS.Process.isSuccess (OS.Process.system "true && test -f system-in.txt"))
  val () = eqB ("OS.Process.system/waits-for-the-command", true,
                fn () => (ignore (OS.Process.system "sleep 1; echo done > system-wait.txt");
                          slurp "system-wait.txt" = "done\n"))
  (* Output that this process has buffered is not lost or duplicated by
     running a command. *)
  val () = eqS ("OS.Process.system/keeps-buffered-output", "before after\n",
                fn () => let val out = TextIO.openOut "system-buffer.txt"
                         in
                           TextIO.output (out, "before ");
                           ignore (OS.Process.system "true");
                           TextIO.output (out, "after\n");
                           TextIO.closeOut out;
                           slurp "system-buffer.txt"
                         end)
  (*>> system *)

  (*<< getEnv-system *)
  (* The command inherits the environment that getEnv reads. *)
  val () = eqB ("OS.Process.getEnv/agrees-with-the-shell", true,
                fn () => (ignore (OS.Process.system "printf '%s' \"$PATH\" > system-path.txt");
                          OS.Process.getEnv "PATH" = SOME (slurp "system-path.txt")))
  val () = T.eq (T.option T.string) ("OS.Process.getEnv/not-set-by-a-command", NONE,
                fn () => (ignore (OS.Process.system "RUNE_BASIS_SUITE_SET_BY_COMMAND=1; export RUNE_BASIS_SUITE_SET_BY_COMMAND");
                          OS.Process.getEnv "RUNE_BASIS_SUITE_SET_BY_COMMAND"))
  (*>> getEnv-system *)

  (*<< sleep *)
  (* "suspends the calling process for the time specified by t. If t is zero
     or negative, then the calling process does not sleep, but returns
     immediately. No exception is raised." elapsed f: the wall-clock time
     f () takes.

     A negative time is deliberately not tried: SML/NJ never returns from
     sleep (Time.fromReal ~1.0) (110.79: from ~1 s down; 110.99.9: any
     negative time), which would hang the test instead of failing a check,
     and Poly/ML 5.7.1 raises SysErr ("Invalid time", NONE). *)
  fun elapsed (f : unit -> unit) : Time.time =
    let val start = Time.now () in f (); Time.- (Time.now (), start) end
  val () = eqB ("OS.Process.sleep/zero", true,
                fn () => Time.< (elapsed (fn () => OS.Process.sleep Time.zeroTime), Time.fromReal 1.0))
  val () = eqB ("OS.Process.sleep/positive", true,
                fn () => Time.>= (elapsed (fn () => OS.Process.sleep (Time.fromReal 0.2)), Time.fromReal 0.2))
  val () = eqB ("OS.Process.sleep/positive-not-much-longer", true,
                fn () => Time.< (elapsed (fn () => OS.Process.sleep (Time.fromReal 0.05)), Time.fromReal 5.0))
  (*>> sleep *)

  (*<< atExit *)
  (* "registers an action f to be executed when the current SML program calls
     exit": not when it is registered. What the actions do can only be seen
     once the process has ended, which the runner does not look at: after the
     exit in finish.sml the file atexit.txt in the scratch directory must
     contain "31" ("Actions will be executed in the reverse order of
     registration. Exceptions raised when f is invoked that escape it are
     trapped and ignored. Calls in f to atExit are ignored."). *)
  val ran = ref false
  fun note s = let val out = TextIO.openAppend "atexit.txt" in TextIO.output (out, s); TextIO.closeOut out end
  val () = eqB ("OS.Process.atExit/not-run-at-registration", false,
                fn () => (OS.Process.atExit (fn () => (ran := true; note "1")); !ran))
  val () = eqB ("OS.Process.atExit/action-that-raises", false,
                fn () => (OS.Process.atExit (fn () => (ran := true; raise Fail "ignored")); !ran))
  val () = eqB ("OS.Process.atExit/action-that-registers", false,
                fn () => (OS.Process.atExit (fn () => (ran := true; note "3";
                                                       OS.Process.atExit (fn () => note "X")));
                          !ran))
  (*>> atExit *)
end
