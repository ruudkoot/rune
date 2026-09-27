(* 2^100 + 2^47 lies half-way between the reals 2^100 and 2^100 + 2^48;
   one more is above the half-way point, so to nearest it is 2^100 + 2^48. *)
fun pow2 n = Real.fromManExp {man = 1.0, exp = n}
val i = IntInf.+ (IntInf.+ (IntInf.pow (2, 100), IntInf.pow (2, 47)), 1)
val r = Real.fromLargeInt i
fun exact r = Real.fmt StringCvt.EXACT r
val () = print ("i                                 = " ^ IntInf.toString i ^ "\n")
val () = print ("Real.fromLargeInt i               = " ^ exact r ^ "\n")
val () = print ("2^100 + 2^48 (expected)           = " ^ exact (pow2 100 + pow2 48) ^ "\n")
val () = print ("2^100                             = " ^ exact (pow2 100) ^ "\n")
val () = print ("Real.fromString (IntInf.toString i) = " ^ exact (valOf (Real.fromString (IntInf.toString i))) ^ "\n")
val () = print ("fromLargeInt i = 2^100 + 2^48: " ^ Bool.toString (Real.== (r, pow2 100 + pow2 48)) ^ "\n")
