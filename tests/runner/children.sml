(* Commands inside a supervised test stay in that test's process group.
   Creating another group here would let a grandchild survive cancellation
   of the SML coordinator. The outer supervisor detects and kills leaks;
   an inner deadline kills/reaps its leader before the case reports failure. *)
structure Children =
struct
  open Sh
  fun exec limits envf {cmd, dir, stdin, stdout, stderr, timeout} =
    let
      val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr,
                                      Posix.FileSys.S.irgrp, Posix.FileSys.S.iroth]
      fun input "" = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
        | input "-" = Posix.IO.dup Posix.FileSys.stdin
        | input file = Posix.FileSys.openf (file, Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
      fun output "" = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [])
        | output file = Posix.FileSys.creat (file, mode)
      val i = input stdin
      val out = output stdout
      val err = if stderr = stdout andalso stdout <> "" then out else output stderr
      fun close () = (Posix.IO.close i; Posix.IO.close out; if err = out then () else Posix.IO.close err)
      fun n fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
      val search = not (String.isSubstring "/" (hd cmd))
      val program = if search orelse not (isSome dir) then hd cmd else fromRoot (hd cmd)
      val pid = (Subprocess.spawn {program = program, args = cmd, env = SOME (envf (Posix.ProcEnv.environ ())),
                   search = search, dir = dir, stdin = SOME (n i), stdout = SOME (n out), stderr = SOME (n err),
                   group = false, limits = limits} handle e => (close (); raise e))
      val () = close ()
      fun code status = case status of Posix.Process.W_EXITED => 0
        | Posix.Process.W_EXITSTATUS w => Word8.toInt w
        | Posix.Process.W_SIGNALED signal => 128 + SysWord.toInt (Posix.Signal.toWord signal)
        | Posix.Process.W_STOPPED signal => 128 + SysWord.toInt (Posix.Signal.toWord signal)
      val start = Runtime.clock ()
      fun wait () = case Subprocess.poll (SOME pid) of
          SOME {status, ...} => code status
        | NONE => if Time.>= (Time.- (Runtime.clock (), start), Time.fromSeconds (LargeInt.fromInt timeout)) then
            ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.kill)
              handle OS.SysErr _ => ()); ignore (Subprocess.wait (SOME pid)); 124)
          else (OS.Process.sleep (Time.fromMilliseconds 10); wait ())
    in if timeout <= 0 then code (#status (Subprocess.wait (SOME pid))) else wait () end
end
