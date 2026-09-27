(* "Decimal approximations are to be converted using the IEEEReal.TO_NEAREST
   rounding mode." *)
fun inMode mode f =
    let val saved = IEEEReal.getRoundingMode ()
    in IEEEReal.setRoundingMode mode; f () before IEEEReal.setRoundingMode saved end
fun dec (sign, digits, exp) =
    valOf (Real.fromDecimal {class = IEEEReal.NORMAL, sign = sign, digits = digits, exp = exp})
fun exact r = Real.fmt StringCvt.EXACT r
fun digits r = String.concat (map Int.toString (#digits (Real.toDecimal r)))
val () = print ("TO_NEAREST: fromDecimal ~0.1 = " ^ exact (dec (true, [1], 0)) ^ "\n")
val () = print ("TO_NEGINF:  fromDecimal ~0.1 = "
                ^ exact (inMode IEEEReal.TO_NEGINF (fn () => dec (true, [1], 0))) ^ "   (expected ~0.1)\n")
val () = print ("TO_NEGINF:  fromDecimal 0.1  = "
                ^ exact (inMode IEEEReal.TO_NEGINF (fn () => dec (false, [1], 0))) ^ "   (expected 0.1)\n")
val () = print ("TO_POSINF:  digits of toDecimal 0.1 = "
                ^ inMode IEEEReal.TO_POSINF (fn () => digits 0.1) ^ "   (expected 1)\n")
