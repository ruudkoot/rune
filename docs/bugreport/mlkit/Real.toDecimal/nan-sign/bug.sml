val nan = Real.posInf - Real.posInf
val negNan = Real.copySign (nan, ~1.0)
val posNan = Real.copySign (nan, 1.0)
fun sign r = Bool.toString (#sign (Real.toDecimal r))
val () = print ("Real.signBit negNan = " ^ Bool.toString (Real.signBit negNan)
                ^ ", #sign (Real.toDecimal negNan) = " ^ sign negNan ^ "   (expected true)\n")
val () = print ("Real.signBit posNan = " ^ Bool.toString (Real.signBit posNan)
                ^ ", #sign (Real.toDecimal posNan) = " ^ sign posNan ^ "\n")
val () = print ("for comparison, #sign (Real.toDecimal Real.negInf) = " ^ sign Real.negInf ^ "\n")
