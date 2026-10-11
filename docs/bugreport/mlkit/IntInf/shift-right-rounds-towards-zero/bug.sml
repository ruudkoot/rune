(* IntInf.~>> (i, n) "shifts i to the right by n bit positions.  When i and n
   are interpreted as integers, the latter non-negative, this returns
   floor(i / 2^n)": ~>> (~1, 0w1) is ~1 and ~>> (~5, 0w1) is ~3.
   IntInf.div, which floors, gives the expected value. *)
fun show (i : IntInf.int, n : word) =
    print ("IntInf.~>> (" ^ IntInf.toString i ^ ", 0w" ^ Word.fmt StringCvt.DEC n ^ ") = "
           ^ IntInf.toString (IntInf.~>> (i, n))
           ^ "   (floor: " ^ IntInf.toString (IntInf.div (i, IntInf.pow (2, Word.toInt n))) ^ ")\n")
val () = show (~1, 0w1)
val () = show (~5, 0w1)
val () = show (~4, 0w1)
val () = show (5, 0w1)
val () = show (~1, 0w20)
val () = show (~1000000, 0w10)
(* -2^62 - 1, beyond a 63-bit int *)
val () = show (IntInf.- (IntInf.~ (IntInf.pow (2, 62)), 1), 0w1)
