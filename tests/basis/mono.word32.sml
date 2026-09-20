(* requires: Word32Vector Word32Array Word32 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Word32Vector, Word32Array, Word32VectorSlice, Word32ArraySlice and
   Word32Array2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   Word32.word"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample words that include 0, the
   largest word and the one of the top bit alone, and those of the element
   type. The slices and the two-dimensional arrays are in sections, for a host
   that has the vectors and arrays alone. *)
structure TestMonoWord32 =
struct
  fun w n = Word32.fromInt n
  val most = Word32.notb (w 0)
  (* the top bit alone *)
  val high = Word32.<< (w 1, Word.fromInt (Word32.wordSize - 1))
  val elems = Vector.fromList ([w 0, most, w 1, w 2, high, Word32.- (high, w 1), Word32.- (most, w 1), w 7]
                               @ [w 42, w 255, w 256, w 100, w 1000, w 12345, Word32.+ (high, w 1), Word32.>> (high, 0w1)])
  val show = Word32.toString
  val same : Word32.word * Word32.word -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Word32Vector val name = "Word32Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Word32Array structure V = Word32Vector val name = "Word32Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Word32Vector.length v, fn k => Word32Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Word32.word ---- *)
  val () = eqE ("Word32Vector.fromList/extremes", [most, w 0, high], fn () => vectorToList (Word32Vector.fromList [most, w 0, high]))
  val () = eqE ("Word32Vector.foldl/Word32-arithmetic", [w 45], fn () => [Word32Vector.foldl Word32.+ (w 0) (Word32Vector.tabulate (10, w))])
  val () = T.eq T.order ("Word32Vector.collate/Word32.compare-unsigned", LESS,
                         fn () => Word32Vector.collate Word32.compare (Word32Vector.fromList [w 0, most], Word32Vector.fromList [high]))
  (* modulo 2 ^ wordSize: the largest word and one is 0 *)
  val () = eqE ("Word32Array.modify/Word32-arithmetic", [w 0, w 1, Word32.+ (high, w 1)],
                fn () => let val a = Word32Array.fromList [most, w 0, high]
                         in Word32Array.modify (fn x => Word32.+ (x, w 1)) a; Word32Array.foldr op :: [] a end)
  val () = eqE ("Word32Array.vector/extremes", [most, high], fn () => vectorToList (Word32Array.vector (Word32Array.fromList [most, high])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Word32VectorSlice structure V = Word32Vector val name = "Word32VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Word32ArraySlice structure A = Word32Array structure V = Word32Vector structure VS = Word32VectorSlice val name = "Word32ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Word32ArraySlice.foldl/Word32-arithmetic", [w 55],
                fn () => [Word32ArraySlice.foldl Word32.+ (w 0) (Word32ArraySlice.slice (Word32Array.tabulate (12, w), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Word32Array2 structure V = Word32Vector val name = "Word32Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Word32Array2 structure V = Word32Vector val name = "Word32Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Word32Array2.row/extremes", [high, w 0, most],
                fn () => vectorToList (Word32Array2.row (Word32Array2.fromList [[w 1, w 2, w 3], [high, w 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Word32Array2 val name = "Word32Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Word32Array2 structure V = Word32Vector val name = "Word32Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Word32Vector val name = "Word32Vector" val elem = w 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Word32Array val name = "Word32Array" val elem = w 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Word32VectorSlice structure V = Word32Vector val name = "Word32VectorSlice" val elem = w 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Word32VectorSlice structure V = Word32Vector val name = "Word32VectorSlice" val elem = w 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Word32ArraySlice structure A = Word32Array val name = "Word32ArraySlice" val elem = w 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Word32Array2 val name = "Word32Array2" val elem = w 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Word32Array2 val name = "Word32Array2" val elem = w 0)
  (*>> array2-size *)
end
