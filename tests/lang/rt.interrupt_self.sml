(* rt.interrupt: Runtime.catchInterrupt and Runtime.maskInterrupt
   (docs/runtime.md, Interrupts). The program interrupts itself -- SIGINT to
   its own process, as Ctrl-C at a terminal sends it -- which sets the flag
   before kill returns; the next jump back or call raises SML90.Interrupt,
   unless the mask holds it. Uncaught, it ends the program as an exception
   does. *)
fun interrupt () = Posix.Process.kill (Posix.Process.K_PROC (Posix.ProcEnv.getpid ()), Posix.Signal.int)

fun spin (n : int) = if n = 0 then 0 else spin (n - 1)

fun say s = print (s ^ "\n")

val () = say ("caught: " ^ Bool.toString (Runtime.catchInterrupt ()))

(* raised where the program next polls, into its handler *)
val () = say ((interrupt (); "ran on: " ^ Int.toString (spin 1000)) handle SML90.Interrupt => "interrupted")

(* what the handler needs is as it was, whichever poll raised it *)
fun guarded x =
  let
    val y = x * 3
    fun loop (n, acc) = if n = 0 then acc else loop (n - 1, acc + 1)
  in
    (interrupt (); loop (100000, 0)) handle SML90.Interrupt => y + 1
  end
val () = say ("the handler's value: " ^ Int.toString (guarded 14))

(* masked, it waits: the loop runs to its end, and the mask going raises it,
   once *)
val () = say ("the mask was: " ^ Bool.toString (Runtime.maskInterrupt true))
val () = say ((interrupt (); interrupt (); "ran on while masked: " ^ Int.toString (spin 1000))
              handle SML90.Interrupt => "raised while masked")
val () = say ((ignore (Runtime.maskInterrupt false); "missed") handle SML90.Interrupt => "raised as the mask went")
val () = say ("then nothing waits: " ^ Int.toString (spin 1000))
val () = say ("the mask is: " ^ Bool.toString (Runtime.maskInterrupt false))

(* a section the mask keeps whole *)
fun section f =
  let val was = Runtime.maskInterrupt true
  in (f () before ignore (Runtime.maskInterrupt was)) handle e => (ignore (Runtime.maskInterrupt was); raise e) end
val steps = ref 0
val () = say ((section (fn () => (interrupt (); steps := spin 1000 + 1)); "missed") handle SML90.Interrupt => "raised after the section")
val () = say ("the section's steps: " ^ Int.toString (!steps))

(* uncaught: raised as the mask goes, a place that is the same at every
   level of optimisation, where the next poll after a kill is not *)
val _ = Runtime.maskInterrupt true
val () = interrupt ()
val _ = Runtime.maskInterrupt false
val () = say ("not reached: " ^ Int.toString (spin 10))
