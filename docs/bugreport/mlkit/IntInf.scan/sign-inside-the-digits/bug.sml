(* IntInf.scan (and fromString, which is scanString (scan DEC)) take a sign
   that follows the digits, or the sign, for the sign of a further group of
   digits.  The format is [+~-]?[0-9]+ (DEC): "1~2" is 1 followed by "~2",
   and "~~5", "~-1" and "++5" are no numbers at all (NONE). *)
fun reader s i = if i < String.size s then SOME (String.sub (s, i), i + 1) else NONE
fun say s = (print s; TextIO.flushOut TextIO.stdOut)
fun scan s =
  case IntInf.scan StringCvt.DEC (reader s) 0 of
    NONE => "NONE"
  | SOME (n, i) => "SOME (" ^ IntInf.toString n ^ ", \"" ^ String.extract (s, i, NONE) ^ "\")"
val () = List.app (fn s => say ("IntInf.scan DEC " ^ s ^ " = " ^ scan s ^ "\n"))
                  ["1~2", "1-2", "1+2", "12~34", "123456789+1", "++5"]
val () = say ("IntInf.fromString \"1~2\" = "
              ^ (case IntInf.fromString "1~2" of NONE => "NONE" | SOME n => "SOME " ^ IntInf.toString n) ^ "\n")
(* A second sign right after the first gives a value that is not a number:
   it is negative, but neither ~5 nor 5, and IntInf.toString does not return
   on it. *)
val () =
  case IntInf.fromString "~~5" of
    NONE => say "IntInf.fromString \"~~5\" = NONE\n"
  | SOME x =>
      (say ("IntInf.fromString \"~~5\" = SOME x: sign x = " ^ Int.toString (IntInf.sign x)
            ^ ", x = ~5: " ^ Bool.toString (x = IntInf.fromInt ~5)
            ^ ", x = 5: " ^ Bool.toString (x = IntInf.fromInt 5) ^ "\n");
       say "IntInf.toString x = ";
       say (IntInf.toString x ^ "\n"))
