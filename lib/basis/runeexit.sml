(* What a program does when it ends: the actions of OS.Process.atExit, and
   the flushing of the streams that hold output, run by the epilogue that
   every program is compiled with, and by OS.Process.exit and Unix.exit. *)
(* OS.Process.status: abstract, as the specification has it. It is an int: 0
   is success, 1 to 255 what the process exited with, 256 and the signal that
   ended it, 512 and the one that stopped it. *)
structure RuneStatus :>
sig
  eqtype status
  val toInt : status -> int
  val fromInt : int -> status
end =
struct
  type status = int
  fun toInt (s : status) = s
  fun fromInt (s : int) : status = s
end

structure RuneExit =
struct
  val actions : (unit -> unit) list ref = ref []
  val running = ref false

  (* "Calls in f to atExit are ignored": once the actions run, none is added. *)
  fun atExit f = if !running then () else actions := f :: !actions

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
