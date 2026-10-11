(* IntInf.~>> (i, n) "shifts i to the right by n bit positions.  When i and n
   are interpreted as integers, the latter non-negative, this returns
   floor(i / 2^n)".  The numbers here are not negative, so the floor is the
   quotient (see the report IntInf/shift-right-rounds-towards-zero for
   negative ones). *)
fun show (i : IntInf.int, n : word, expected : string) =
    print ("IntInf.~>> (" ^ IntInf.toString i ^ ", 0w" ^ Word.fmt StringCvt.DEC n ^ ") = "
           ^ IntInf.toString (IntInf.~>> (i, n)) ^ "   (expected " ^ expected ^ ")\n")
val two40 = IntInf.pow (2, 40)
val () = show (two40, 0w29, "2048")
val () = show (two40, 0w30, "1024")
val () = show (two40, 0w31, "512")
val () = show (two40, 0w40, "1")
val () = show (IntInf.pow (2, 100), 0w60, "1099511627776")
val () = show (IntInf.pow (2, 62), 0w32, "1073741824")
(* the amount is not taken modulo 2^31: 2^31 + 5 bits leave nothing of 1024 *)
val () = show (1024, 0wx80000005, "0")
