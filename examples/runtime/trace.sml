(* Where a program was when something went wrong.

   A handler sees the stack as it was at the raise only if it looks before it
   unwinds -- which is what the VM itself does when nothing handles an
   exception. What a handler can do is say where it is, which is often
   enough to tell one caller from another. *)

exception Bad of string

fun parse s =
  case Int.fromString s of
    SOME n => n
  | NONE => raise Bad s

fun total strings = List.foldl (fn (s, acc) => acc + parse s) 0 strings

fun tryIt what strings =
  print (what ^ ": " ^ Int.toString (total strings) ^ "\n")
  handle Bad s =>
    (print (what ^ ": " ^ s ^ " is not a number, caught in\n");
     Runtime.printTrace TextIO.stdOut)

val () = tryIt "good" ["1", "2", "3"]
val () = tryIt "bad" ["1", "two", "3"]

(* Nothing handles this one, so the VM prints the message and the frames
   under it, and the program ends with status 1. *)
val () = print "and now one that nothing handles:\n"
val () = ignore (total ["4", "five"])
