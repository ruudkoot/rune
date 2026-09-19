(* requires: IntVector IntArray Int List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* IntVector, IntArray, IntVectorSlice, IntArraySlice and IntArray2 (optional
   in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = int"): the checks that
   hold for every structure of those signatures, from fn/mono_*_fn.sml, on 16
   sample integers that include 0, ~1, Int.minInt and Int.maxInt, and those of
   the element type. The slices and the two-dimensional arrays are in
   sections, for a host that has the vectors and arrays alone. *)
structure TestMonoInt =
struct
  fun i n = Int.fromInt n
  val least = valOf Int.minInt
  val most = valOf Int.maxInt
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, Int.+ (least, i 1), Int.- (most, i 1)]
                               @ List.map i [7, 42, ~42, 100, ~100, 12345, ~12345, 1000])
  val show = Int.toString
  val same : Int.int * Int.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = IntVector val name = "IntVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = IntArray structure V = IntVector val name = "IntArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (IntVector.length v, fn k => IntVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is int ---- *)
  val () = eqE ("IntVector.fromList/extremes", [least, most, i 0], fn () => vectorToList (IntVector.fromList [least, most, i 0]))
  val () = eqE ("IntVector.foldl/Int-arithmetic", [i 45], fn () => [IntVector.foldl Int.+ (i 0) (IntVector.tabulate (10, i))])
  val () = T.eq T.order ("IntVector.collate/Int.compare", LESS,
                         fn () => IntVector.collate Int.compare (IntVector.fromList [least, most], IntVector.fromList [Int.+ (least, i 1)]))
  val () = eqE ("IntArray.modify/Int-arithmetic", [Int.- (most, i 1), i ~1, least],
                fn () => let val a = IntArray.fromList [most, i 0, Int.+ (least, i 1)]
                         in IntArray.modify (fn x => Int.- (x, i 1)) a; IntArray.foldr op :: [] a end)
  val () = eqE ("IntArray.vector/extremes", [most, least], fn () => vectorToList (IntArray.vector (IntArray.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = IntVectorSlice structure V = IntVector val name = "IntVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = IntArraySlice structure A = IntArray structure V = IntVector structure VS = IntVectorSlice val name = "IntArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("IntArraySlice.foldl/Int-arithmetic", [i 55],
                fn () => [IntArraySlice.foldl Int.+ (i 0) (IntArraySlice.slice (IntArray.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = IntArray2 structure V = IntVector val name = "IntArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = IntArray2 structure V = IntVector val name = "IntArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("IntArray2.row/extremes", [least, i 0, most],
                fn () => vectorToList (IntArray2.row (IntArray2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = IntArray2 val name = "IntArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = IntArray2 structure V = IntVector val name = "IntArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = IntVector val name = "IntVector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = IntArray val name = "IntArray" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = IntVectorSlice structure V = IntVector val name = "IntVectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = IntVectorSlice structure V = IntVector val name = "IntVectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = IntArraySlice structure A = IntArray val name = "IntArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = IntArray2 val name = "IntArray2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = IntArray2 val name = "IntArray2" val elem = i 0)
  (*>> array2-size *)
end
