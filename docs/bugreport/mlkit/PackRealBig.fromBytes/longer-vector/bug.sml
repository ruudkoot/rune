(* 1.0 is 3F F0 00 00 00 00 00 00, most significant byte first. "The function
   fromBytes raises the Subscript exception if the argument vector does not
   have length at least bytesPerElem; otherwise the first bytesPerElem bytes
   are used." *)
fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
val eight = [0x3F, 0xF0, 0, 0, 0, 0, 0, 0]
val () = print ("PackRealBig.fromBytes [3F F0 00 00 00 00 00 00]       = "
                ^ Real.toString (PackRealBig.fromBytes (vecOf eight)) ^ "\n")
val () = print ("PackRealBig.fromBytes [3F F0 00 00 00 00 00 00 40 00] = "
                ^ Real.toString (PackRealBig.fromBytes (vecOf (eight @ [0x40, 0]))) ^ "   (expected 1.0)\n")
val () = print ("PackRealLittle.fromBytes [00 00 00 00 00 00 F0 3F 40 00] = "
                ^ Real.toString (PackRealLittle.fromBytes (vecOf (rev eight @ [0x40, 0]))) ^ "\n")
