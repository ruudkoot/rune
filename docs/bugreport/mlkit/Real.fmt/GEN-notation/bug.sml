(* "either the scientific or fixed-point notation, whichever is shorter,
   breaking ties in favor of fixed-point ... There should not be a decimal
   point unless a fractional part is included." *)
fun show (what, got, expected) =
    print (what ^ " = " ^ got ^ (if got = expected then "" else "   (expected " ^ expected ^ ")") ^ "\n")
open StringCvt
val () = show ("Real.fmt (GEN NONE) 1.0         ", Real.fmt (GEN NONE) 1.0, "1")
val () = show ("Real.fmt (GEN NONE) ~42.0       ", Real.fmt (GEN NONE) ~42.0, "~42")
val () = show ("Real.fmt (GEN NONE) 0.0         ", Real.fmt (GEN NONE) 0.0, "0")
val () = show ("Real.fmt (GEN NONE) 1000.0      ", Real.fmt (GEN NONE) 1000.0, "1E3")
val () = show ("Real.fmt (GEN NONE) 1E10        ", Real.fmt (GEN NONE) 1E10, "1E10")
val () = show ("Real.fmt (GEN NONE) 1.2345E7    ", Real.fmt (GEN NONE) 1.2345E7, "12345000")
val () = show ("Real.fmt (GEN NONE) 0.001       ", Real.fmt (GEN NONE) 0.001, "1E~3")
val () = show ("Real.fmt (GEN NONE) 0.000125    ", Real.fmt (GEN NONE) 0.000125, "1.25E~4")
val () = show ("Real.fmt (GEN NONE) 0.01        ", Real.fmt (GEN NONE) 0.01, "0.01")
val () = show ("Real.fmt (GEN (SOME 1)) 9.6     ", Real.fmt (GEN (SOME 1)) 9.6, "10")
val () = show ("Real.fmt (GEN (SOME 4)) 123456.789", Real.fmt (GEN (SOME 4)) 123456.789, "123500")
val () = show ("Real.toString 1.0               ", Real.toString 1.0, "1")
val () = show ("Real.toString 1E10              ", Real.toString 1E10, "1E10")
val () = show ("Real.toString 0.000125          ", Real.toString 0.000125, "1.25E~4")
