(* MLKit: the element type of LargeIntVector, LargeIntVectorSlice,
   LargeIntArray, LargeIntArraySlice and LargeIntArray2, which the
   specification gives as LargeInt.int *)
(* 10^27, a LargeInt.int that no machine word holds *)
val billion = LargeInt.fromInt 1000000000
val big : LargeInt.int = LargeInt.* (billion, LargeInt.* (billion, billion))
val v = LargeIntVector.fromList [LargeInt.fromInt 1, big]
val () = print (LargeInt.toString (LargeIntVector.sub (v, 1)) ^ "\n")
val a = LargeIntArray.array (2, big)
val () = print (LargeInt.toString (LargeIntArray.sub (a, 0)) ^ "\n")
val m = LargeIntArray2.array (1, 1, big)
val () = print (LargeInt.toString (LargeIntArray2.sub (m, 0, 0)) ^ "\n")
