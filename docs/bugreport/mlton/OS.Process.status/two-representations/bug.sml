(* MLton: OS.Process.exit of the status of OS.Process.system. system returns
   the status of waitpid (768 for `exit 3`), and exit takes only 0 to 255,
   so it raises Fail; the command's exit code is not passed on.
   Run: mlton bug.sml && ./bug; echo $?        (expected 3) *)
val st = OS.Process.system "exit 3"
val () = print ("Posix.Process.fromStatus of the status: "
                ^ (case Posix.Process.fromStatus st of
                     Posix.Process.W_EXITED => "W_EXITED"
                   | Posix.Process.W_EXITSTATUS w => "W_EXITSTATUS " ^ Word8.toString w
                   | Posix.Process.W_SIGNALED _ => "W_SIGNALED"
                   | Posix.Process.W_STOPPED _ => "W_STOPPED") ^ "\n")
val () = OS.Process.exit st
