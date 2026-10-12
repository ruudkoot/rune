(* Subprocess: a child started in a directory and in a process group of its
   own, waited for with what it cost, polled while it runs, and its group
   ended as one. The program is the shell of the system: sh on POSIX, and
   cmd.exe (COMSPEC) on Windows; uname says which. *)
val windows = List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
val shell = if windows then valOf (OS.Process.getEnv "COMSPEC") else "/bin/sh"
fun run (dir, command) =
  Subprocess.spawn {program = shell, args = if windows then [shell, "/d", "/c", command] else ["sh", "-c", command],
                    env = NONE, search = false, dir = dir, stdin = NONE, stdout = NONE, stderr = NONE,
                    group = true, limits = Subprocess.unlimited}
fun statusOf (e : Subprocess.ended) =
  case #status e of
    Posix.Process.W_EXITED => "exited 0"
  | Posix.Process.W_EXITSTATUS w => "exited " ^ Int.toString (Word8.toInt w)
  | Posix.Process.W_SIGNALED s => "signal " ^ Int.toString (SysWord.toInt (Posix.Signal.toWord s))
  | Posix.Process.W_STOPPED _ => "stopped"

(* an exit status, and what the child cost *)
val e = Subprocess.wait (SOME (run (NONE, "exit 3")))
val () = print ("exit: " ^ statusOf e ^ "\n")
val () = print ("costs: " ^ Bool.toString (Time.>= (#user e, Time.zeroTime) andalso Time.>= (#system e, Time.zeroTime)
                                           andalso #peakResident e >= 0) ^ "\n")

(* the directory it starts in: it writes a file there *)
val dir = "tests/out/basis.subprocess.dir"
val () = OS.FileSys.mkDir dir handle OS.SysErr _ => ()
val _ = Subprocess.wait (SOME (run (SOME dir, if windows then "echo here> mark.txt" else "echo here > mark.txt")))
val () = print ("dir: " ^ Bool.toString (OS.FileSys.access (dir ^ "/mark.txt", [])) ^ "\n")
val () = (OS.FileSys.remove (dir ^ "/mark.txt"); OS.FileSys.rmDir dir) handle OS.SysErr _ => ()

(* a group that runs, polled, then ended as one *)
val p = run (NONE, if windows then "ping -n 30 127.0.0.1 > NUL" else "sleep 30 & sleep 30")
val () = print ("poll: " ^ (if isSome (Subprocess.poll (SOME p)) then "ended" else "running") ^ "\n")
val () = Subprocess.kill (p, Posix.Signal.term)
val () = print ("killed: " ^ statusOf (Subprocess.wait (SOME p)) ^ "\n")

(* no such child *)
val () = print ("no child: " ^ ((ignore (Subprocess.wait (SOME 999999)); "returned") handle OS.SysErr _ => "OS.SysErr") ^ "\n")

(* the clock goes on, and there is a processor *)
val t = Runtime.clock ()
val () = print ("clock: " ^ Bool.toString (Time.<= (t, Runtime.clock ())) ^ "\n")
val () = print ("processors: " ^ Bool.toString (Runtime.processors () >= 1) ^ "\n")
