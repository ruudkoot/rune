(* Poly/ML: OS.Process.exit of the status of a command that a signal ended,
   which connotes no exit value: exit should act as though called with
   failure (1 here); it exits with the number of the signal (15).
   Run: poly --script bug-signal.sml; echo $?      (expected 1) *)
val () = OS.Process.exit (OS.Process.system "kill -TERM $$")
