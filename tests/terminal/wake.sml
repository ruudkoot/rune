(* A resize that arrived before the read still ends it. The first resizes
   installs the handler; the signal is raised then, and the read must
   return at once rather than wait out its time. Linux's SIGWINCH is 28
   on every architecture this VM runs (asm-generic). *)
fun say s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut)
fun fail s = (say s; OS.Process.exit OS.Process.failure)

val () = Terminal.enter {undo = ""}
val earlier = Terminal.resizes ()
val winch = Posix.Signal.fromWord 0w28
val () = Posix.Process.kill (Posix.Process.K_PROC (Posix.ProcEnv.getpid ()), winch)
val t0 = Time.now ()
val got = Terminal.read (SOME (Time.fromMilliseconds 1500))
val ms = LargeInt.toInt (Time.toMilliseconds (Time.- (Time.now (), t0))) handle Overflow => 1000000
val after = Terminal.resizes ()
val () =
  if after = earlier then fail "count unchanged"
  else if ms > 400 then fail ("waited " ^ Int.toString ms)
  else
    case got of
      SOME "" => ()
    | SOME s => fail ("bytes " ^ s)
    | NONE => fail "end"
val () = Terminal.leave ()
val () = say "woke"
