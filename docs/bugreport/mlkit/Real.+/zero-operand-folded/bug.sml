(* In IEEE arithmetic (rounding to nearest), 0.0 + ~0.0 and ~0.0 + 0.0 are
   0.0, and ~0.0 - ~0.0 is 0.0: only ~0.0 + ~0.0 is ~0.0. *)
fun sign r = if Real.signBit r then "~0.0" else "0.0"
fun show (what, r) = print (what ^ " = " ^ sign r ^ "   (expected 0.0)\n")

val negZero = ref ~0.0    (* a ~0.0 that the optimiser cannot see *)
val posZero = ref 0.0
fun addLeft x = 0.0 + x
fun addRight x = x + 0.0
fun subNegZero x = x - ~0.0

val () = show ("0.0 + ~0.0             ", 0.0 + ~0.0)
val () = show ("0.0 + !negZero         ", 0.0 + !negZero)
val () = show ("!negZero + 0.0         ", !negZero + 0.0)
val () = show ("addLeft (!negZero)     ", addLeft (!negZero))
val () = show ("addRight (!negZero)    ", addRight (!negZero))
val () = show ("subNegZero (!negZero)  ", subNegZero (!negZero))
val () = show ("!posZero + !negZero    ", !posZero + !negZero)
