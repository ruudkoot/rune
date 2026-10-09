(* rt.save: a world restored from an image catches the user's interrupt as
   the program that saved it did, with the mask it had (docs/runtime.md,
   Interrupts): the restored world interrupts itself, which would end it
   were SIGINT not caught again. *)
fun interrupt () = Posix.Process.kill (Posix.Process.K_PROC (Posix.ProcEnv.getpid ()), Posix.Signal.int)
fun spin (n : int) = if n = 0 then 0 else spin (n - 1)
fun say s = print (s ^ "\n")

val _ = Runtime.catchInterrupt ()
val _ = Runtime.maskInterrupt true
val () =
  case Runtime.save "tests/out/rt.save_interrupt.img" of
    Runtime.Saved => say "saved"
  | Runtime.Restored =>
      (say ("restored, masked: " ^ Bool.toString (Runtime.maskInterrupt true));
       say ((interrupt (); "held: " ^ Int.toString (spin 1000)) handle SML90.Interrupt => "raised while masked");
       say ((ignore (Runtime.maskInterrupt false); "missed") handle SML90.Interrupt => "raised as the mask went"))
