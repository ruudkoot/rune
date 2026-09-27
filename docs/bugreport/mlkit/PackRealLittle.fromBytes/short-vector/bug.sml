(* "The function fromBytes raises the Subscript exception if the argument
   vector does not have length at least bytesPerElem" (8). *)
fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
fun try (what, f) =
    print (what ^ " = " ^ (Real.toString (f ()) handle Subscript => "Subscript")
           ^ "   (expected Subscript)\n")
val () = try ("PackRealLittle.fromBytes (7 bytes)", fn () => PackRealLittle.fromBytes (vecOf [0, 0, 0, 0, 0, 0xF0, 0x3F]))
val () = try ("PackRealLittle.fromBytes (0 bytes)", fn () => PackRealLittle.fromBytes (vecOf []))
val () = try ("PackRealBig.fromBytes (7 bytes)   ", fn () => PackRealBig.fromBytes (vecOf [0x3F, 0xF0, 0, 0, 0, 0, 0]))
