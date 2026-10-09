(* Poly/ML: OS.Process.exit of the status of OS.Process.system. On Unix
   system returns the status of waitpid, and exit passes it to C's exit,
   which keeps its low byte: the exit code of the command is lost.
   Run: poly --script bug.sml; echo $?      (expected 3) *)
val st = OS.Process.system "exit 3"
val () = print ("Posix.Process.fromStatus of the status: "
                ^ (case Posix.Process.fromStatus st of
                     Posix.Process.W_EXITED => "W_EXITED"
                   | Posix.Process.W_EXITSTATUS w => "W_EXITSTATUS " ^ Word8.toString w
                   | Posix.Process.W_SIGNALED _ => "W_SIGNALED"
                   | Posix.Process.W_STOPPED _ => "W_STOPPED") ^ "\n")
val () = OS.Process.exit st
