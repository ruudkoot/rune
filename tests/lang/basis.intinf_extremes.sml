structure IntInfExtremes =
struct
  structure I = IntInf
  val huge = Word.notb 0w0
  val one = I.fromInt 1
  val zero = I.fromInt 0
  val minus = I.fromInt (~1)
  fun show b = print (Bool.toString b ^ "\n")
  val () = show (I.<<(zero,huge) = zero)
  val () = show (I.~>>(one,huge) = zero andalso I.~>>(minus,huge) = minus)
  val () = show (I.pow(one,valOf Int.maxInt) = one)
  val () = show (I.pow(minus,valOf Int.minInt) = one)
  val () = show (I.pow(I.fromInt 2,valOf Int.minInt) = zero)
  val () = show ((I.pow(zero,~1); false) handle Div => true)
end
