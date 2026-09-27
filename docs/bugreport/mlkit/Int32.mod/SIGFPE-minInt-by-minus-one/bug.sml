(* Int32.mod (minInt, ~1) and Int64.mod (minInt, ~1) should be 0 ("It raises
   Div when j = 0"; nothing else), but the program is killed by SIGFPE.
   Run as `./bug CASE`, one case per process, since the crash ends it. *)
fun say s = (print s; TextIO.flushOut TextIO.stdOut)
fun try name f = (say (name ^ " = "); say ((f () handle e => "raises " ^ exnName e) ^ "\n"))
val min32 = valOf Int32.minInt
val min64 = valOf Int64.minInt
val () =
  case CommandLine.arguments () of
    ["contrast"] =>
      (try "Int.mod (minInt, ~1)   " (fn () => Int.toString (Int.mod (valOf Int.minInt, ~1)));
       try "Int32.rem (minInt, ~1) " (fn () => Int32.toString (Int32.rem (min32, ~1)));
       try "Int64.rem (minInt, ~1) " (fn () => Int64.toString (Int64.rem (min64, ~1)));
       try "Int32.div (minInt, ~1) " (fn () => Int32.toString (Int32.div (min32, ~1)));
       try "Int64.div (minInt, ~1) " (fn () => Int64.toString (Int64.div (min64, ~1))))
  | ["Int32.mod"] => try "Int32.mod (minInt, ~1) " (fn () => Int32.toString (Int32.mod (min32, ~1)))
  | ["Int64.mod"] => try "Int64.mod (minInt, ~1) " (fn () => Int64.toString (Int64.mod (min64, ~1)))
  | ["int32-mod"] =>  (* the overloaded operator at int32 *)
      try "(minInt : Int32.int) mod ~1" (fn () => Int32.toString (min32 mod ~1))
  | _ => say "usage: bug contrast | Int32.mod | Int64.mod | int32-mod\n"
