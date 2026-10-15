(* Dividing 2^120 + 2^60 + 1 by 2^k discards a nonzero remainder for
   every k>0, so the negative floor is one below the negated positive one. *)
structure IntInfShiftDigits =
struct
  structure I = IntInf
  val two = I.fromInt 2
  val one = I.fromInt 1
  val x = I.+(I.+(I.pow(two,120),I.pow(two,60)),one)
  fun expected k = if k <= 60 then I.+(I.pow(two,120-k),I.pow(two,60-k))
                   else if k <= 120 then I.pow(two,120-k) else I.fromInt 0
  fun check k =
    I.~>>(x,Word.fromInt k)=expected k andalso
    I.~>>(I.~ x,Word.fromInt k)=I.-(I.~(expected k),one)
  val () = print(Bool.toString(List.all check [1,14,15,16,29,30,31,59,60,61,119,120,121]) ^ "\n")
  val huge = Word.+(Word.fromInt(valOf Int.maxInt),0w1)
  val () = print(Bool.toString(I.~>>(x,huge)=I.fromInt 0 andalso I.~>>(I.~ x,huge)=I.fromInt (~1)) ^ "\n")
end
