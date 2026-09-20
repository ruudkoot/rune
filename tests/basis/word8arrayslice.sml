(* requires: Word8ArraySlice Word8Array Word8VectorSlice Word8Vector Word8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml fn/mono_array_slice_fn.sml *)
(* Word8ArraySlice (signature MONO_ARRAY_SLICE, "where type vector =
   Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where
   type array = Word8Array.array where type elem = Word8.word"): the checks
   that hold for every MONO_ARRAY_SLICE structure, from
   fn/mono_array_slice_fn.sml, on sample bytes that include 0 and 255, and
   those of the element, array, vector and vector slice types. Bytes are built
   with Word8.fromInt: there are no word constants at Word8.word here. *)
structure TestWord8ArraySlice =
struct
  val bytes = Vector.fromList (List.map Word8.fromInt [0, 1, 2, 127, 128, 200, 254, 255])
  structure Generic = TestMonoArraySliceFn (structure S = Word8ArraySlice structure A = Word8Array structure V = Word8Vector structure VS = Word8VectorSlice val name = "Word8ArraySlice" val elems = bytes val show = Word8.toString val same = op =)

  structure S = Word8ArraySlice
  val eqI = T.eq T.int
  val eqL = T.eq (T.list T.int)
  fun arrayToInts a = List.tabulate (Word8Array.length a, fn i => Word8.toInt (Word8Array.sub (a, i)))
  fun vectorToInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))
  fun all256 () = Word8Array.tabulate (256, Word8.fromInt)
  fun zeros n = Word8Array.array (n, Word8.fromInt 0)

  (* ---- elem is Word8.word; array, vector and vector_slice are those of
     Word8Array, Word8Vector and Word8VectorSlice ---- *)
  val () = eqL ("Word8ArraySlice.vector/every-byte", List.tabulate (256, fn i => i),
                fn () => vectorToInts (S.vector (S.full (all256 ())) : Word8Vector.vector))
  val () = eqL ("Word8ArraySlice.slice/high-bytes", [253, 254, 255], fn () => vectorToInts (S.vector (S.slice (all256 (), 253, NONE))))
  val () = eqI ("Word8ArraySlice.sub/elem-is-Word8.word", 200,
                fn () => Word8.toInt (S.sub (S.slice (all256 (), 100, SOME 101), 100) : Word8.word))
  val () = eqL ("Word8ArraySlice.update/byte", [0, 0, 44, 0],   (* 300 mod 256 *)
                fn () => let val a = zeros 4 in S.update (S.slice (a, 1, NONE), 1, Word8.fromInt 300); arrayToInts a end)
  val () = eqL ("Word8ArraySlice.modify/Word8-arithmetic", [0, 255, 0, 3],   (* + 1 modulo 256 *)
                fn () => let val a = Word8Array.fromList (List.map Word8.fromInt [0, 254, 255, 3])
                         in S.modify (fn w => Word8.+ (w, Word8.fromInt 1)) (S.slice (a, 1, SOME 2)); arrayToInts a end)
  val () = eqL ("Word8ArraySlice.copy/to-Word8Array", [0, 254, 255, 0],
                fn () => let val d = zeros 4 in S.copy {src = S.slice (all256 (), 254, NONE), dst = d, di = 1}; arrayToInts d end)
  val () = eqL ("Word8ArraySlice.copyVec/from-Word8VectorSlice", [0, 254, 255, 0],
                fn () => let val d = zeros 4
                         in S.copyVec {src = Word8VectorSlice.slice (Word8Vector.tabulate (256, Word8.fromInt), 254, NONE),
                                       dst = d, di = 1};
                            arrayToInts d end)
  val () = eqI ("Word8ArraySlice.foldl/sum-of-bytes", 955,   (* 189 + ... + 193 = 5 * 191 *)
                fn () => S.foldl (fn (w, s) => Word8.toInt w + s) 0 (S.slice (all256 (), 189, SOME 5)))
  val () = T.eq T.order ("Word8ArraySlice.collate/unsigned-bytes", LESS,   (* 127 < 128 as words *)
                         fn () => S.collate Word8.compare (S.slice (all256 (), 127, SOME 1), S.slice (all256 (), 128, SOME 1)))
  val () = T.check ("Word8ArraySlice.base/is-the-Word8Array",
                    fn () => let val a = all256 () in #1 (S.base (S.slice (a, 3, SOME 4))) = (a : Word8Array.array) end)

  (*<< overflow *)
  structure Overflow = TestMonoArraySliceOverflowFn (structure S = Word8ArraySlice structure A = Word8Array val name = "Word8ArraySlice" val elem = Word8.fromInt 0)
  (*>> overflow *)
end
