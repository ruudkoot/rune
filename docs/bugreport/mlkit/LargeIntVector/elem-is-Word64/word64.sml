(* the same structures take Word64.word *)
val v = LargeIntVector.fromList [0w1, 0wxFFFFFFFFFFFFFFFF : Word64.word]
val () = print (Word64.fmt StringCvt.HEX (LargeIntVector.sub (v, 1)) ^ "\n")
val () = print (Word64.toString (LargeIntArray2.sub (LargeIntArray2.array (1, 1, 0w42 : Word64.word), 0, 0)) ^ "\n")
