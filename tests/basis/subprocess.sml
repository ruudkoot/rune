(* requires: Subprocess Runtime Posix OS Time List Word8 SysWord TextIO String *)
(* Subprocess (signature SUBPROCESS, Rune's own): children started in a
   directory, in a process group of their own and under limits, waited for
   with what they cost, and a group ended as one (docs/plans/unit-testing.md,
   M2). lib/basis/subprocess.sml is `host = no`, so this file runs on Rune
   alone. The program is the system's shell: sh on POSIX, cmd.exe (COMSPEC)
   on Windows. The limits of a file's size and of processor time, and the
   end of a grandchild with its group, are checked on POSIX alone, where a
   signal says which limit ended a child. *)
structure TestSubprocess =
struct
  val windows = List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
  val shell = if windows then valOf (OS.Process.getEnv "COMSPEC") else "/bin/sh"
  fun args command = if windows then [shell, "/d", "/c", command] else ["sh", "-c", command]

  fun start {command, env, group, limits, stdout} =
    Subprocess.spawn {program = shell, args = args command, env = env, search = false, dir = NONE, stdin = NONE,
                      stdout = stdout, stderr = NONE, group = group, limits = limits}
  fun run command = start {command = command, env = NONE, group = true, limits = Subprocess.unlimited, stdout = NONE}
  fun statusOf command = #status (Subprocess.wait (SOME (run command)))

  fun signalled name (Posix.Process.W_SIGNALED s) = SysWord.toInt (Posix.Signal.toWord s) = SysWord.toInt (Posix.Signal.toWord name)
    | signalled _ _ = false

  val () = T.check ("Subprocess.unlimited/no-limits",
                    fn () => Subprocess.unlimited = {addressSpace = NONE, cpuTime = NONE, fileSize = NONE, core = NONE})
  val () = T.check ("Subprocess.wait/exit-0", fn () => statusOf "exit 0" = Posix.Process.W_EXITED)
  val () = T.check ("Subprocess.wait/exit-7", fn () => statusOf "exit 7" = Posix.Process.W_EXITSTATUS 0w7)

  (* the environment given, and only it, with what each system's shell needs to start *)
  val () = T.check ("Subprocess.spawn/env",
                    fn () =>
                      let
                        val keep = List.mapPartial (fn n => Option.map (fn v => n ^ "=" ^ v) (OS.Process.getEnv n))
                                     ["PATH", "SystemRoot", "COMSPEC"]
                        val p = start {command = if windows then "exit %CODE%" else "exit $CODE", env = SOME ("CODE=5" :: keep),
                                       group = false, limits = Subprocess.unlimited, stdout = NONE}
                      in #status (Subprocess.wait (SOME p)) = Posix.Process.W_EXITSTATUS 0w5 end)

  val () = T.skipUnless (not windows, "sh is found on PATH on POSIX")
             (fn () => T.check ("Subprocess.spawn/search",
                                fn () => #status (Subprocess.wait (SOME (Subprocess.spawn
                                           {program = "sh", args = ["sh", "-c", "exit 0"], env = NONE, search = true,
                                            dir = NONE, stdin = NONE, stdout = NONE, stderr = NONE, group = false,
                                            limits = Subprocess.unlimited}))) = Posix.Process.W_EXITED))

  (* standard output to a pipe *)
  val () = T.check ("Subprocess.spawn/stdout",
                    fn () =>
                      let
                        val {infd, outfd} = Posix.IO.pipe ()
                        val p = start {command = "echo hello", env = NONE, group = false, limits = Subprocess.unlimited,
                                       stdout = SOME (SysWord.toInt (Posix.FileSys.fdToWord outfd))}
                        val () = Posix.IO.close outfd
                        val text = Byte.bytesToString (Posix.IO.readVec (infd, 100))
                        val () = Posix.IO.close infd
                      in
                        ignore (Subprocess.wait (SOME p)); String.isPrefix "hello" text
                      end)

  (* any child, and no child *)
  val () = T.check ("Subprocess.wait/any-child",
                    fn () => let val p = run "exit 2" in #pid (Subprocess.wait NONE) = p end)
  val () = T.check ("Subprocess.wait/no-child",
                    fn () => (ignore (Subprocess.wait (SOME 999999)); false) handle OS.SysErr _ => true)
  val () = T.check ("Subprocess.poll/running",
                    fn () =>
                      let
                        val p = run (if windows then "ping -n 30 127.0.0.1 > NUL" else "sleep 30")
                        val running = not (isSome (Subprocess.poll (SOME p)))
                      in
                        Subprocess.kill (p, Posix.Signal.term); ignore (Subprocess.wait (SOME p)); running
                      end)

  (* the group ends as one: a grandchild too *)
  val () = T.skipUnless (not windows, "a process group, and the signal that ended it, are POSIX's")
             (fn () => T.check ("Subprocess.kill/the-group",
                                fn () =>
                                  let
                                    val file = OS.FileSys.tmpName ()
                                    val p = run ("sleep 30 & echo $! > " ^ file ^ "; wait")
                                    fun grandchild () =
                                      let val s = TextIO.openIn file
                                      in Option.mapPartial Int.fromString (TextIO.inputLine s) before TextIO.closeIn s end
                                      handle IO.Io _ => NONE
                                    fun waitFor 0 = NONE
                                      | waitFor n = case grandchild () of SOME g => SOME g | NONE => (OS.Process.sleep (Time.fromMilliseconds 10); waitFor (n - 1))
                                    val g = waitFor 500
                                    val () = Subprocess.kill (p, Posix.Signal.term)
                                    val killed = signalled Posix.Signal.term (#status (Subprocess.wait (SOME p)))
                                    (* gone once signal 0, which only asks, finds no such
                                       process: a grandchild killed with its group may be a
                                       zombie for a moment, until init reaps it *)
                                    fun gone (g, 0) = false
                                      | gone (g, n) =
                                          ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt g)),
                                                                Posix.Signal.fromWord 0w0);
                                            OS.Process.sleep (Time.fromMilliseconds 10); gone (g, n - 1))
                                           handle OS.SysErr _ => true)
                                    val gone = case g of SOME g => gone (g, 200) | NONE => false
                                  in
                                    OS.FileSys.remove file handle OS.SysErr _ => ();
                                    killed andalso gone
                                  end))

  (* the limits: a file too long ends the writer by a signal (SIGXFSZ),
     processor time too (SIGXCPU), which POSIX_SIGNAL does not name, and what
     a busy child cost is counted *)
  val () = T.skipUnless (not windows, "the limits of a file and of processor time are signals of POSIX")
             (fn () =>
                let
                  val file = OS.FileSys.tmpName ()
                  val big = start {command = "exec head -c 100000 /dev/zero > " ^ file, env = NONE, group = false,
                                   limits = {addressSpace = NONE, cpuTime = NONE, fileSize = SOME 1000, core = SOME 0},
                                   stdout = NONE}
                  val () = T.check ("Subprocess.spawn/file-size-limit",
                                    fn () => case #status (Subprocess.wait (SOME big)) of Posix.Process.W_SIGNALED _ => true | _ => false)
                  val () = OS.FileSys.remove file handle OS.SysErr _ => ()
                  val busy = start {command = "while :; do :; done", env = NONE, group = false,
                                    limits = {addressSpace = NONE, cpuTime = SOME 1, fileSize = NONE, core = SOME 0},
                                    stdout = NONE}
                  val e = Subprocess.wait (SOME busy)
                in
                  T.check ("Subprocess.spawn/cpu-time-limit", fn () => case #status e of Posix.Process.W_SIGNALED _ => true | _ => false);
                  T.check ("Subprocess.wait/user-time", fn () => Time.>= (#user e, Time.fromMilliseconds 500));
                  T.check ("Subprocess.wait/peak-resident", fn () => #peakResident e > 0)
                end)
end
