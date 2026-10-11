(* requires: Repl *)
(* Repl matches REPL, which is Rune's own signature and has no transcription
   under spec-sigs: functions of strings, and nothing abstract. *)
structure TestReplSig =
struct
  val () = T.check ("Repl:REPL/command-takes-a-line", fn () => (ignore (Repl.command : string -> unit); true))
end
