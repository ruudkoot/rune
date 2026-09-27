(* MLKit: copy and copyVec with a destination index di so large that
   di + |src| is beyond Int.maxInt. |dst| < di + |src|, so each call must
   raise Subscript. *)
fun try (what : string) (f : unit -> unit) =
  print (what ^ ": " ^ ((f (); "no exception") handle e => "raised " ^ exnName e) ^ "\n")
val di = valOf Int.maxInt

val () = try "ArraySlice.copy" (fn () =>
  ArraySlice.copy {src = ArraySlice.slice (Array.array (8, 0), 2, SOME 4), dst = Array.array (6, 0), di = di})
val () = try "ArraySlice.copyVec" (fn () =>
  ArraySlice.copyVec {src = VectorSlice.slice (Vector.tabulate (8, fn i => i), 2, SOME 4), dst = Array.array (6, 0), di = di})
val () = try "CharArraySlice.copy" (fn () =>
  CharArraySlice.copy {src = CharArraySlice.slice (CharArray.array (8, #"a"), 2, SOME 4), dst = CharArray.array (8, #"b"), di = di})
val () = try "CharArraySlice.copyVec" (fn () =>
  CharArraySlice.copyVec {src = CharVectorSlice.full "abcd", dst = CharArray.array (8, #"b"), di = di})
val () = try "Word8ArraySlice.copy" (fn () =>
  Word8ArraySlice.copy {src = Word8ArraySlice.slice (Word8Array.array (8, 0w1), 2, SOME 4), dst = Word8Array.array (8, 0w2), di = di})
val () = try "IntArraySlice.copy" (fn () =>
  IntArraySlice.copy {src = IntArraySlice.slice (IntArray.array (8, 1), 2, SOME 4), dst = IntArray.array (8, 2), di = di})
val () = try "IntArraySlice.copyVec" (fn () =>
  IntArraySlice.copyVec {src = IntVectorSlice.full (IntVector.fromList [1, 2, 3, 4]), dst = IntArray.array (8, 2), di = di})
val () = try "RealArraySlice.copy" (fn () =>
  RealArraySlice.copy {src = RealArraySlice.slice (RealArray.array (8, 1.0), 2, SOME 4), dst = RealArray.array (8, 2.0), di = di})
(* the same condition in the array structures *)
val () = try "Array.copy" (fn () =>
  Array.copy {src = Array.array (4, 0), dst = Array.array (6, 0), di = di})
val () = try "Array.copyVec" (fn () =>
  Array.copyVec {src = Vector.tabulate (4, fn i => i), dst = Array.array (6, 0), di = di})
val () = try "IntArray.copy" (fn () =>
  IntArray.copy {src = IntArray.array (4, 0), dst = IntArray.array (6, 0), di = di})
val () = try "RealArray.copyVec" (fn () =>
  RealArray.copyVec {src = RealVector.fromList [1.0, 2.0], dst = RealArray.array (6, 0.0), di = di})
(* for contrast: ByteTable.sml checks n > |dst| - di *)
val () = try "CharArray.copy (for contrast)" (fn () =>
  CharArray.copy {src = CharArray.array (4, #"a"), dst = CharArray.array (6, #"b"), di = di})
val () = try "Word8Array.copyVec (for contrast)" (fn () =>
  Word8Array.copyVec {src = Word8Vector.fromList [0w1, 0w2], dst = Word8Array.array (6, 0w0), di = di})
