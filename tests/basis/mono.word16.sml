(* requires: Word16Vector Word16Array Word16 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Word16Vector, Word16Array, Word16VectorSlice, Word16ArraySlice and
   Word16Array2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   Word16.word"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample words that include 0, the
   largest word and the one of the top bit alone, and those of the element
   type. The slices and the two-dimensional arrays are in sections, for a host
   that has the vectors and arrays alone. *)
structure TestMonoWord16 =
struct
  fun w n = Word16.fromInt n
  val most = Word16.notb (w 0)
  (* the top bit alone *)
  val high = Word16.<< (w 1, Word.fromInt (Word16.wordSize - 1))
  val elems = Vector.fromList ([w 0, most, w 1, w 2, high, Word16.- (high, w 1), Word16.- (most, w 1), w 7]
                               @ [w 42, w 255, w 256, w 100, w 1000, w 12345, Word16.+ (high, w 1), Word16.>> (high, 0w1)])
  val show = Word16.toString
  val same : Word16.word * Word16.word -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Word16Vector val name = "Word16Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Word16Array structure V = Word16Vector val name = "Word16Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Word16Vector.length v, fn k => Word16Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Word16.word ---- *)
  val () = eqE ("Word16Vector.fromList/extremes", [most, w 0, high], fn () => vectorToList (Word16Vector.fromList [most, w 0, high]))
  val () = eqE ("Word16Vector.foldl/Word16-arithmetic", [w 45], fn () => [Word16Vector.foldl Word16.+ (w 0) (Word16Vector.tabulate (10, w))])
  val () = T.eq T.order ("Word16Vector.collate/Word16.compare-unsigned", LESS,
                         fn () => Word16Vector.collate Word16.compare (Word16Vector.fromList [w 0, most], Word16Vector.fromList [high]))
  (* modulo 2 ^ wordSize: the largest word and one is 0 *)
  val () = eqE ("Word16Array.modify/Word16-arithmetic", [w 0, w 1, Word16.+ (high, w 1)],
                fn () => let val a = Word16Array.fromList [most, w 0, high]
                         in Word16Array.modify (fn x => Word16.+ (x, w 1)) a; Word16Array.foldr op :: [] a end)
  val () = eqE ("Word16Array.vector/extremes", [most, high], fn () => vectorToList (Word16Array.vector (Word16Array.fromList [most, high])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Word16VectorSlice structure V = Word16Vector val name = "Word16VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Word16ArraySlice structure A = Word16Array structure V = Word16Vector structure VS = Word16VectorSlice val name = "Word16ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Word16ArraySlice.foldl/Word16-arithmetic", [w 55],
                fn () => [Word16ArraySlice.foldl Word16.+ (w 0) (Word16ArraySlice.slice (Word16Array.tabulate (12, w), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Word16Array2 structure V = Word16Vector val name = "Word16Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Word16Array2 structure V = Word16Vector val name = "Word16Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Word16Array2.row/extremes", [high, w 0, most],
                fn () => vectorToList (Word16Array2.row (Word16Array2.fromList [[w 1, w 2, w 3], [high, w 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Word16Array2 val name = "Word16Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Word16Array2 structure V = Word16Vector val name = "Word16Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Word16Vector val name = "Word16Vector" val elem = w 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Word16Array val name = "Word16Array" val elem = w 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Word16VectorSlice structure V = Word16Vector val name = "Word16VectorSlice" val elem = w 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Word16VectorSlice structure V = Word16Vector val name = "Word16VectorSlice" val elem = w 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Word16ArraySlice structure A = Word16Array val name = "Word16ArraySlice" val elem = w 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Word16Array2 val name = "Word16Array2" val elem = w 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Word16Array2 val name = "Word16Array2" val elem = w 0)
  (*>> array2-size *)
end
