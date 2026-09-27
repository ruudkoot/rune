(* Int.minInt = ~2^62 is a real; Int.maxInt + 1 = 2^62 is the first real
   above Int.maxInt. *)
fun show (what, f) =
    print (what ^ " = " ^ (Int.toString (f ()) handle Overflow => "Overflow") ^ "\n")
val minInt = valOf Int.minInt
val m = Real.fromInt minInt                      (* ~2^62, exact *)
val above = Real.fromInt (valOf Int.maxInt) + 1.0 (* 2^62, exact *)

val () = print ("Int.minInt = " ^ Int.toString minInt ^ ", Int.precision = "
                ^ Int.toString (valOf Int.precision) ^ "\n\n")
val () = print "expected ~4611686018427387904:\n"
val () = show ("  Real.floor (real minInt)        ", fn () => Real.floor m)
val () = show ("  Real.round (real minInt)        ", fn () => Real.round m)
val () = show ("  Real.ceil (real minInt)         ", fn () => Real.ceil m)
val () = show ("  Real.trunc (real minInt)        ", fn () => Real.trunc m)
val () = show ("  Real.ceil (real minInt - 0.5)   ", fn () => Real.ceil (m - 0.5))
val () = show ("  Real.trunc (real minInt - 0.5)  ", fn () => Real.trunc (m - 0.5))
val () = show ("  Real.toInt TO_POSINF (real minInt)", fn () => Real.toInt IEEEReal.TO_POSINF m)
val () = show ("  Real.toInt TO_ZERO (real minInt)  ", fn () => Real.toInt IEEEReal.TO_ZERO m)
val () = print "expected Overflow:\n"
val () = show ("  Real.floor 2^62                 ", fn () => Real.floor above)
val () = show ("  Real.trunc 2^62                 ", fn () => Real.trunc above)
val () = show ("  Real.ceil 2^62                  ", fn () => Real.ceil above)
val () = show ("  Real.toInt TO_POSINF 2^62       ", fn () => Real.toInt IEEEReal.TO_POSINF above)
