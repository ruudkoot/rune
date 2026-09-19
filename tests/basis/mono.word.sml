(* requires: WordVector WordArray Word List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* WordVector, WordArray, WordVectorSlice, WordArraySlice and WordArray2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = word"): the checks that
   hold for every structure of those signatures, from fn/mono_*_fn.sml, on 16
   sample words that include 0, the largest word and the one of the top bit
   alone, and those of the element type. The slices and the two-dimensional
   arrays are in sections, for a host that has the vectors and arrays alone. *)
structure TestMonoWord =
struct
  fun w n = Word.fromInt n
  val most = Word.notb (w 0)
  (* the top bit alone *)
  val high = Word.<< (w 1, Word.fromInt (Word.wordSize - 1))
  val elems = Vector.fromList ([w 0, most, w 1, w 2, high, Word.- (high, w 1), Word.- (most, w 1), w 7]
                               @ [w 42, w 255, w 256, w 100, w 1000, w 12345, Word.+ (high, w 1), Word.>> (high, 0w1)])
  val show = Word.toString
  val same : Word.word * Word.word -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = WordVector val name = "WordVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = WordArray structure V = WordVector val name = "WordArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (WordVector.length v, fn k => WordVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is word ---- *)
  val () = eqE ("WordVector.fromList/extremes", [most, w 0, high], fn () => vectorToList (WordVector.fromList [most, w 0, high]))
  val () = eqE ("WordVector.foldl/Word-arithmetic", [w 45], fn () => [WordVector.foldl Word.+ (w 0) (WordVector.tabulate (10, w))])
  val () = T.eq T.order ("WordVector.collate/Word.compare-unsigned", LESS,
                         fn () => WordVector.collate Word.compare (WordVector.fromList [w 0, most], WordVector.fromList [high]))
  (* modulo 2 ^ wordSize: the largest word and one is 0 *)
  val () = eqE ("WordArray.modify/Word-arithmetic", [w 0, w 1, Word.+ (high, w 1)],
                fn () => let val a = WordArray.fromList [most, w 0, high]
                         in WordArray.modify (fn x => Word.+ (x, w 1)) a; WordArray.foldr op :: [] a end)
  val () = eqE ("WordArray.vector/extremes", [most, high], fn () => vectorToList (WordArray.vector (WordArray.fromList [most, high])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = WordVectorSlice structure V = WordVector val name = "WordVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = WordArraySlice structure A = WordArray structure V = WordVector structure VS = WordVectorSlice val name = "WordArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("WordArraySlice.foldl/Word-arithmetic", [w 55],
                fn () => [WordArraySlice.foldl Word.+ (w 0) (WordArraySlice.slice (WordArray.tabulate (12, w), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = WordArray2 structure V = WordVector val name = "WordArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = WordArray2 structure V = WordVector val name = "WordArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("WordArray2.row/extremes", [high, w 0, most],
                fn () => vectorToList (WordArray2.row (WordArray2.fromList [[w 1, w 2, w 3], [high, w 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = WordArray2 val name = "WordArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = WordArray2 structure V = WordVector val name = "WordArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = WordVector val name = "WordVector" val elem = w 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = WordArray val name = "WordArray" val elem = w 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = WordVectorSlice structure V = WordVector val name = "WordVectorSlice" val elem = w 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = WordVectorSlice structure V = WordVector val name = "WordVectorSlice" val elem = w 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = WordArraySlice structure A = WordArray val name = "WordArraySlice" val elem = w 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = WordArray2 val name = "WordArray2" val elem = w 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = WordArray2 val name = "WordArray2" val elem = w 0)
  (*>> array2-size *)
end
