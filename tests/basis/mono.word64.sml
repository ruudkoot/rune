(* requires: Word64Vector Word64Array Word64 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Word64Vector, Word64Array, Word64VectorSlice, Word64ArraySlice and
   Word64Array2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   Word64.word"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample words that include 0, the
   largest word and the one of the top bit alone, and those of the element
   type. Word64 is Word in Rune, and Word64Vector is WordVector. The slices
   and the two-dimensional arrays are in sections, for a host that has the
   vectors and arrays alone. *)
structure TestMonoWord64 =
struct
  fun w n = Word64.fromInt n
  val most = Word64.notb (w 0)
  (* the top bit alone *)
  val high = Word64.<< (w 1, Word.fromInt (Word64.wordSize - 1))
  val elems = Vector.fromList ([w 0, most, w 1, w 2, high, Word64.- (high, w 1), Word64.- (most, w 1), w 7]
                               @ [w 42, w 255, w 256, w 100, w 1000, w 12345, Word64.+ (high, w 1), Word64.>> (high, 0w1)])
  val show = Word64.toString
  val same : Word64.word * Word64.word -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Word64Vector val name = "Word64Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Word64Array structure V = Word64Vector val name = "Word64Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Word64Vector.length v, fn k => Word64Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Word64.word ---- *)
  val () = eqE ("Word64Vector.fromList/extremes", [most, w 0, high], fn () => vectorToList (Word64Vector.fromList [most, w 0, high]))
  val () = eqE ("Word64Vector.foldl/Word64-arithmetic", [w 45], fn () => [Word64Vector.foldl Word64.+ (w 0) (Word64Vector.tabulate (10, w))])
  val () = T.eq T.order ("Word64Vector.collate/Word64.compare-unsigned", LESS,
                         fn () => Word64Vector.collate Word64.compare (Word64Vector.fromList [w 0, most], Word64Vector.fromList [high]))
  (* modulo 2 ^ wordSize: the largest word and one is 0 *)
  val () = eqE ("Word64Array.modify/Word64-arithmetic", [w 0, w 1, Word64.+ (high, w 1)],
                fn () => let val a = Word64Array.fromList [most, w 0, high]
                         in Word64Array.modify (fn x => Word64.+ (x, w 1)) a; Word64Array.foldr op :: [] a end)
  val () = eqE ("Word64Array.vector/extremes", [most, high], fn () => vectorToList (Word64Array.vector (Word64Array.fromList [most, high])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Word64VectorSlice structure V = Word64Vector val name = "Word64VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Word64ArraySlice structure A = Word64Array structure V = Word64Vector structure VS = Word64VectorSlice val name = "Word64ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Word64ArraySlice.foldl/Word64-arithmetic", [w 55],
                fn () => [Word64ArraySlice.foldl Word64.+ (w 0) (Word64ArraySlice.slice (Word64Array.tabulate (12, w), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Word64Array2 structure V = Word64Vector val name = "Word64Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Word64Array2 structure V = Word64Vector val name = "Word64Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Word64Array2.row/extremes", [high, w 0, most],
                fn () => vectorToList (Word64Array2.row (Word64Array2.fromList [[w 1, w 2, w 3], [high, w 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Word64Array2 val name = "Word64Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Word64Array2 structure V = Word64Vector val name = "Word64Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Word64Vector val name = "Word64Vector" val elem = w 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Word64Array val name = "Word64Array" val elem = w 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Word64VectorSlice structure V = Word64Vector val name = "Word64VectorSlice" val elem = w 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Word64VectorSlice structure V = Word64Vector val name = "Word64VectorSlice" val elem = w 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Word64ArraySlice structure A = Word64Array val name = "Word64ArraySlice" val elem = w 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Word64Array2 val name = "Word64Array2" val elem = w 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Word64Array2 val name = "Word64Array2" val elem = w 0)
  (*>> array2-size *)
end
