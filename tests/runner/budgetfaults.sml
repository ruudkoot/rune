(* Planted defects at the real budget driver's child and golden boundaries.
   The shell programs here are deliberately fake compiler/VM subjects. *)
structure BudgetFaults =
struct
  open Sh
  fun need (name, ok) = if ok then () else say ("FAIL budget fault: " ^ name ^ "\n")
  fun script (file, body) =
    (write (file, "#!/bin/sh\n" ^ body ^ "\n");
     Posix.FileSys.chmod (file, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
  fun one payload () =
    let
      val base = run ^ "/budget-faults"
      val () = mkdirs base
      val compiler = "while [ $# -gt 0 ]; do case $1 in -o) output=$2; shift 2 ;; *) shift ;; esac; done\nprintf RUNE > \"$output\""
      fun vm count = "printf 'PASS fake\\n'\nprintf 'runevm: count: " ^ count ^ " instructions, 1 bytes, 1 objects\\n' >&2"
      fun attempt (name, cc, body, expected, timeout, cap) =
        let
          val dir = base ^ "/" ^ name
          val () = mkdirs (dir ^ "/tests/perf")
          val () = mkdirs (dir ^ "/bin")
          val () = mkdirs (dir ^ "/tests/out/perf")
          val () = write (dir ^ "/tests/out/perf/probe.rbc", "STALE bytecode must not be reused\n")
          val () = write (dir ^ "/tests/perf/probe.sml", "val () = ()\n")
          val () = write (dir ^ "/tests/perf/probe.expected", expected)
          val () = write (dir ^ "/tests/perf/probe.budget", "instructions 10\nbytes 10\nobjects 10\n")
          val () = script (dir ^ "/bin/compiler", cc)
          val () = script (dir ^ "/bin/vm", body)
          val env = setEnv ("RUNE_TEST_ROOT", dir) (setEnv ("RUNE", dir ^ "/bin/compiler")
                   (setEnv ("RUNEVM", dir ^ "/bin/vm") (Posix.ProcEnv.environ ())))
          val command = {program = fromRoot "bin/runevm", args = [fromRoot "bin/runevm", payload], env = env, dir = dir,
            stdin = "/dev/null", stdout = dir ^ "/stdout", stderr = dir ^ "/stderr", timeout = Time.fromSeconds timeout,
            cap = cap, cost = 0.0, cpus = 1, memory = 100, pools = [], exclusive = false, failedLast = false, deps = []} : Supervisor.command
          val result = ref NONE : Supervisor.result option ref
          val () = Supervisor.run {commands = Vector.fromList [command], cpus = 1, memory = 100,
                      finished = fn (_, r) => (result := SOME r; Supervisor.Passed), tick = fn _ => ()}
        in (valOf (!result), dir) end
      val good = "PASS fake\n"
      val (healthy, _) = attempt ("healthy", compiler, vm "1", good, 10, 1000000)
      val () = need ("healthy driver", #outcome healthy = Supervisor.Exited 0 andalso not (#leaked healthy))
      val (counts, dir) = attempt ("wrong-count", compiler, vm "11", good, 10, 1000000)
      val () = need ("budget exceeded", #outcome counts = Supervisor.Exited 1 andalso String.isSubstring "budget 10" (read (dir ^ "/stdout")))
      val (golden, dir) = attempt ("wrong-golden", compiler, vm "1", "wrong result\n", 10, 1000000)
      val () = need ("wrong checksum", #outcome golden = Supervisor.Exited 1 andalso String.isSubstring "checksum differs" (read (dir ^ "/stdout")))
      val (missing, dir) = attempt ("missing-bytecode", "exit 0", vm "1", good, 10, 1000000)
      val () = need ("empty producer cannot pass", #outcome missing = Supervisor.Exited 1
                         andalso String.isSubstring "no bytecode" (read (dir ^ "/stdout")))
      val (fails, _) = attempt ("pass-before-failure", compiler, vm "1" ^ "\nexit 7", good, 10, 1000000)
      val () = need ("PASS before failure", #outcome fails = Supervisor.Exited 1)
      val (crashes, _) = attempt ("crash", compiler, "kill -SEGV $$", good, 10, 1000000)
      val () = need ("crashed VM", #outcome crashes = Supervisor.Exited 1)
      val (loops, _) = attempt ("loop", compiler, "printf 'PASS fake\\n'; exec sleep 30", good, 1, 1000000)
      val () = need ("looping VM", #outcome loops = Supervisor.TimedOut)
      val (floods, _) = attempt ("flood", compiler, "exec yes FLOOD", good, 10, 10000)
      val () = need ("output flood", case #outcome floods of Supervisor.Exited 1 => true | Supervisor.Capped => true | Supervisor.Signalled _ => true | _ => false)
      val (leaks, _) = attempt ("leak", compiler, "sleep 30 &\n" ^ vm "1", good, 10, 1000000)
      val () = need ("descendant supervised", #outcome leaks = Supervisor.Exited 0 andalso #leaked leaks)
      val file = base ^ "/large-counters"
      val () = write (file, "runevm: count: 4294967296 instructions, 18446744073709551615 bytes, 1 objects\n")
      val () = need ("unsigned counter widths", Budgets.counters file = [4294967296, 18446744073709551615, 1])
      val () = write (file, "runevm: count: 1 instructions, 2 bytes, 3 objects trailing\n")
      val () = need ("malformed counters", ((Budgets.counters file; false) handle Budgets.Failed _ => true))
      val () = write (file, "runevm: count: 1 instructions, 2 bytes, 3 objects\n")
      val () = Budgets.update file [11, 20, 0]
      val () = need ("explicit update uses integer margin", read file = "runevm: count: 1 instructions, 2 bytes, 3 objects\ninstructions 12\nbytes 22\nobjects 0\n")
    in () end
end
