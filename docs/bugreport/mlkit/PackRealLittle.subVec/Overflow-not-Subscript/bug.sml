(* "They raise the Subscript exception if i < 0 or if Word8Array.length seq
   < bytesPerElem * (i + 1)." *)
val v = Word8Vector.tabulate (16, fn _ => 0w0)
val a = Word8Array.array (16, 0w0)
val i = valOf Int.maxInt
fun try (what, f) =
    print (what ^ ": " ^ ((f (); "no exception") handle Subscript => "Subscript"
                                                       | e => General.exnName e)
           ^ "   (expected Subscript)\n")
val () = try ("PackRealLittle.subVec (v, maxInt)     ", fn () => PackRealLittle.subVec (v, i))
val () = try ("PackRealLittle.subArr (a, maxInt)     ", fn () => PackRealLittle.subArr (a, i))
val () = try ("PackRealLittle.update (a, maxInt, 1.0)", fn () => PackRealLittle.update (a, i, 1.0))
val () = try ("PackRealBig.subVec (v, maxInt)        ", fn () => PackRealBig.subVec (v, i))
val () = try ("PackRealBig.subArr (a, maxInt)        ", fn () => PackRealBig.subArr (a, i))
val () = try ("PackRealBig.update (a, maxInt, 1.0)   ", fn () => PackRealBig.update (a, i, 1.0))
val () = try ("PackRealLittle.subVec (v, 2)          ", fn () => PackRealLittle.subVec (v, 2))
