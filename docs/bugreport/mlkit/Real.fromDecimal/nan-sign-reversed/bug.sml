fun nanOf sign = valOf (Real.fromDecimal {class = IEEEReal.NAN, sign = sign, digits = [], exp = 0})
fun show sign =
    let val r = nanOf sign
    in print ("Real.fromDecimal {class = NAN, sign = " ^ Bool.toString sign ^ ", ...}: isNan "
              ^ Bool.toString (Real.isNan r) ^ ", signBit " ^ Bool.toString (Real.signBit r)
              ^ "   (expected signBit " ^ Bool.toString sign ^ ")\n")
    end
val () = show true
val () = show false
val () = print ("Real.signBit (Real.posInf - Real.posInf) = "
                ^ Bool.toString (Real.signBit (Real.posInf - Real.posInf)) ^ "\n")
