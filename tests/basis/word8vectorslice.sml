(* requires: Word8VectorSlice Word8Vector Word8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_VECTOR_SLICE.sml fn/mono_vector_slice_fn.sml *)
(* Word8VectorSlice (signature MONO_VECTOR_SLICE, "where type vector =
   Word8Vector.vector where type elem = Word8.word"): the checks that hold for
   every MONO_VECTOR_SLICE structure, from fn/mono_vector_slice_fn.sml, on
   sample bytes that include 0 and 255, and those of the element and vector
   types. Bytes are built with Word8.fromInt: there are no word constants at
   Word8.word here. *)
structure TestWord8VectorSlice =
struct
  val bytes = Vector.fromList (List.map Word8.fromInt [0, 1, 2, 127, 128, 200, 254, 255])
  structure Generic = TestMonoVectorSliceFn (structure S = Word8VectorSlice structure V = Word8Vector val name = "Word8VectorSlice" val elems = bytes val show = Word8.toString val same = op =)

  val eqI = T.eq T.int
  val eqL = T.eq (T.list T.int)
  fun vectorToInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))
  fun all256 () = Word8Vector.tabulate (256, Word8.fromInt)

  (* ---- elem is Word8.word, vector is Word8Vector.vector ---- *)
  val () = eqL ("Word8VectorSlice.vector/every-byte", List.tabulate (256, fn i => i),
                fn () => vectorToInts (Word8VectorSlice.vector (Word8VectorSlice.full (all256 ())) : Word8Vector.vector))
  val () = eqL ("Word8VectorSlice.slice/high-bytes", [253, 254, 255],
                fn () => vectorToInts (Word8VectorSlice.vector (Word8VectorSlice.slice (all256 (), 253, NONE))))
  val () = eqI ("Word8VectorSlice.sub/elem-is-Word8.word", 200,
                fn () => Word8.toInt (Word8VectorSlice.sub (Word8VectorSlice.slice (all256 (), 100, SOME 101), 100) : Word8.word))
  val () = eqL ("Word8VectorSlice.map/Word8-arithmetic", [255, 0, 1],   (* + 1 modulo 256 *)
                fn () => vectorToInts (Word8VectorSlice.map (fn w => Word8.+ (w, Word8.fromInt 1))
                                                            (Word8VectorSlice.slice (all256 (), 254, NONE)))
                         @ vectorToInts (Word8VectorSlice.map (fn w => Word8.+ (w, Word8.fromInt 1))
                                                              (Word8VectorSlice.slice (all256 (), 0, SOME 1))))
  val () = eqI ("Word8VectorSlice.foldl/sum-of-bytes", 955,   (* 189 + ... + 193 = 5 * 191 *)
                fn () => Word8VectorSlice.foldl (fn (w, s) => Word8.toInt w + s) 0 (Word8VectorSlice.slice (all256 (), 189, SOME 5)))
  val () = T.eq T.order ("Word8VectorSlice.collate/unsigned-bytes", LESS,   (* 127 < 128 as words *)
                         fn () => Word8VectorSlice.collate Word8.compare
                                    (Word8VectorSlice.slice (all256 (), 127, SOME 1), Word8VectorSlice.slice (all256 (), 128, SOME 1)))

  (*<< overflow *)
  structure Overflow = TestMonoVectorSliceOverflowFn (structure S = Word8VectorSlice structure V = Word8Vector val name = "Word8VectorSlice" val elem = Word8.fromInt 0)
  (*>> overflow *)

  (*<< size *)
  structure Size = TestMonoVectorSliceSizeFn (structure S = Word8VectorSlice structure V = Word8Vector val name = "Word8VectorSlice" val elem = Word8.fromInt 0)
  (*>> size *)
end
