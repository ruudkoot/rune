(* What a program does when it ends: the actions of OS.Process.atExit, and
   the flushing of the streams that hold output, run by the epilogue that
   every program is compiled with, and by OS.Process.exit and Unix.exit. *)
structure RuneExit =
struct
  val actions : (unit -> unit) list ref = ref []
  val running = ref false

  fun atExit f = actions := f :: !actions

  (* "exit ... flushes and closes all I/O streams opened using the Library":
     a stream over a writer of the program's own keeps its output until it
     flushes, and is here while it holds some (a stream on a file hands its
     output to the VM, which flushes it). *)
  val holding : (int * (unit -> unit)) list ref = ref []
  val next = ref 0
  fun hold flush = let val id = !next in next := id + 1; holding := (id, flush) :: !holding; id end
  fun release id =
    let fun drop [] = [] | drop ((k, f) :: rest) = if k = id then rest else (k, f) :: drop rest
    in holding := drop (!holding) end

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
         fun flushAll () =
           case !holding of
             [] => ()
           | (_, f) :: rest => (holding := rest; (f () handle _ => ()); flushAll ())
       in go (); flushAll () end)
end
