(* Carry/borrow across the packed and machine boundaries, and immutable
   operands when scratch buffers are reused. Expected values are derived
   from powers of two and (2^64-1)*257 = 2^72+2^64-257. *)
structure IntInfPaths =
struct
  structure I = IntInf
  val zero = I.fromInt 0
  val one = I.fromInt 1
  val minimum = I.fromInt(valOf Int.minInt)
  val boundary = I.~ minimum
  val maximum = I.fromInt(valOf Int.maxInt)
  fun show b = print(Bool.toString b ^ "\n")
  val () = show(I.+(boundary,minimum) = zero andalso
    I.+(minimum,boundary) = zero andalso I.-(boundary,one) = maximum andalso
    I.+(I.-(minimum,one),maximum) = I.fromInt (~2))
  val twiceMax = I.-(I.+(boundary,boundary),I.fromInt 2)
  val () = show(I.*(maximum,I.fromInt 2) = twiceMax andalso
    I.*(I.fromInt 2,maximum) = twiceMax andalso
    I.*(maximum,I.fromInt (~2)) = I.~ twiceMax andalso
    I.*(minimum,I.fromInt (~1)) = boundary andalso
    I.*(I.fromInt (~1),minimum) = boundary)
  val p = I.pow(I.fromInt 2,240)
  val below = I.-(p,one)
  val () = show(I.+(below,one) = p andalso I.-(p,below) = one andalso
    I.+(I.~ below,I.fromInt (~1)) = I.~ p andalso
    I.+(I.~ p,one) = I.~ below)
  val sum = I.+(p,p)
  val difference = I.-(sum,p)
  val () = show(p = I.pow(I.fromInt 2,240) andalso difference = p andalso
    sum = I.pow(I.fromInt 2,241) andalso below = I.-(p,one))
  fun bits k =
    let val v = I.pow(I.fromInt 2,k)
        val low = I.-(v,one)
    in I.orb(I.~ v,zero) = I.~ v andalso
       I.xorb(I.~ v,I.fromInt (~1)) = low andalso
       I.andb(I.~ v,low) = zero andalso I.andb(I.~ v,v) = v end
  val () = show(List.all bits [15,30,60,63,64,120,240])
  val lowMask = I.fromInt 257
  val () = show(I.orb(p,lowMask) = I.+(p,lowMask) andalso
    I.xorb(I.+(p,I.fromInt 511),lowMask) = I.+(p,I.fromInt 254) andalso
    I.xorb(lowMask,I.+(p,I.fromInt 511)) = I.+(p,I.fromInt 254) andalso
    I.andb(I.+(p,I.fromInt 511),lowMask) = lowMask andalso
    I.xorb(p,zero) = p andalso p = I.pow(I.fromInt 2,240))
  fun shifted k =
    I.~>>(I.~ p,Word.fromInt k) = I.~(I.pow(I.fromInt 2,240-k)) andalso
    I.~>>(I.~(I.+(p,one)),Word.fromInt k) =
      I.-(I.~(I.pow(I.fromInt 2,240-k)),one)
  val () = show(List.all shifted [1,14,15,16,29,30,31,60,239,240])
  val a = valOf(I.fromString "18446744073709551615")
  val product = valOf(I.fromString "4740813226943354765055")
  val () = show(I.*(a,I.fromInt 257) = product andalso
    I.*(I.fromInt (~257),a) = I.~ product andalso
    a = valOf(I.fromString "18446744073709551615"))
end
