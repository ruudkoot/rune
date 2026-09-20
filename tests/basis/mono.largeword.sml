(* requires: LargeWordVector LargeWordArray LargeWord List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* LargeWordVector, LargeWordArray, LargeWordVectorSlice, LargeWordArraySlice
   and LargeWordArray2 (optional in the specification: MONO_VECTOR,
   MONO_ARRAY, MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type
   elem = LargeWord.word"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample words that include 0, the
   largest word and the one of the top bit alone, and those of the element
   type. LargeWord is Word in Rune, and LargeWordVector is WordVector. The
   slices and the two-dimensional arrays are in sections, for a host that has
   the vectors and arrays alone. *)
structure TestMonoLargeWord =
struct
  fun w n = LargeWord.fromInt n
  val most = LargeWord.notb (w 0)
  (* the top bit alone *)
  val high = LargeWord.<< (w 1, Word.fromInt (LargeWord.wordSize - 1))
  val elems = Vector.fromList ([w 0, most, w 1, w 2, high, LargeWord.- (high, w 1), LargeWord.- (most, w 1), w 7]
                               @ [w 42, w 255, w 256, w 100, w 1000, w 12345, LargeWord.+ (high, w 1), LargeWord.>> (high, 0w1)])
  val show = LargeWord.toString
  val same : LargeWord.word * LargeWord.word -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = LargeWordVector val name = "LargeWordVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = LargeWordArray structure V = LargeWordVector val name = "LargeWordArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (LargeWordVector.length v, fn k => LargeWordVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is LargeWord.word ---- *)
  val () = eqE ("LargeWordVector.fromList/extremes", [most, w 0, high], fn () => vectorToList (LargeWordVector.fromList [most, w 0, high]))
  val () = eqE ("LargeWordVector.foldl/LargeWord-arithmetic", [w 45], fn () => [LargeWordVector.foldl LargeWord.+ (w 0) (LargeWordVector.tabulate (10, w))])
  val () = T.eq T.order ("LargeWordVector.collate/LargeWord.compare-unsigned", LESS,
                         fn () => LargeWordVector.collate LargeWord.compare (LargeWordVector.fromList [w 0, most], LargeWordVector.fromList [high]))
  (* modulo 2 ^ wordSize: the largest word and one is 0 *)
  val () = eqE ("LargeWordArray.modify/LargeWord-arithmetic", [w 0, w 1, LargeWord.+ (high, w 1)],
                fn () => let val a = LargeWordArray.fromList [most, w 0, high]
                         in LargeWordArray.modify (fn x => LargeWord.+ (x, w 1)) a; LargeWordArray.foldr op :: [] a end)
  val () = eqE ("LargeWordArray.vector/extremes", [most, high], fn () => vectorToList (LargeWordArray.vector (LargeWordArray.fromList [most, high])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = LargeWordVectorSlice structure V = LargeWordVector val name = "LargeWordVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = LargeWordArraySlice structure A = LargeWordArray structure V = LargeWordVector structure VS = LargeWordVectorSlice val name = "LargeWordArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("LargeWordArraySlice.foldl/LargeWord-arithmetic", [w 55],
                fn () => [LargeWordArraySlice.foldl LargeWord.+ (w 0) (LargeWordArraySlice.slice (LargeWordArray.tabulate (12, w), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = LargeWordArray2 structure V = LargeWordVector val name = "LargeWordArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = LargeWordArray2 structure V = LargeWordVector val name = "LargeWordArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("LargeWordArray2.row/extremes", [high, w 0, most],
                fn () => vectorToList (LargeWordArray2.row (LargeWordArray2.fromList [[w 1, w 2, w 3], [high, w 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = LargeWordArray2 val name = "LargeWordArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = LargeWordArray2 structure V = LargeWordVector val name = "LargeWordArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = LargeWordVector val name = "LargeWordVector" val elem = w 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = LargeWordArray val name = "LargeWordArray" val elem = w 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = LargeWordVectorSlice structure V = LargeWordVector val name = "LargeWordVectorSlice" val elem = w 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = LargeWordVectorSlice structure V = LargeWordVector val name = "LargeWordVectorSlice" val elem = w 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = LargeWordArraySlice structure A = LargeWordArray val name = "LargeWordArraySlice" val elem = w 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = LargeWordArray2 val name = "LargeWordArray2" val elem = w 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = LargeWordArray2 val name = "LargeWordArray2" val elem = w 0)
  (*>> array2-size *)
end
