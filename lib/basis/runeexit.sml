(* What a program does when it ends: the actions of OS.Process.atExit, run by
   the epilogue that every program is compiled with, and by
   OS.Process.exit. *)
structure RuneExit =
struct
  val actions : (unit -> unit) list ref = ref []
  val running = ref false

  fun atExit f = actions := f :: !actions

  (* "The actions are executed in the reverse order of registration", and an
     action that raises an exception, or registers another, is ignored. *)
  fun run () =
    if !running then ()
    else
      (running := true;
       let
         fun go () =
           case !actions of
             [] => ()
           | f :: rest => (actions := rest; (f () handle _ => ()); go ())
       in go () end)
end
