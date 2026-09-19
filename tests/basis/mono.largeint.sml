(* requires: LargeIntVector LargeIntArray LargeInt List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* LargeIntVector, LargeIntArray, LargeIntVectorSlice, LargeIntArraySlice and
   LargeIntArray2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   LargeInt.int"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample integers that include 0,
   ~1, 10^27, ~10^27, 2^30 and 2^60, and those of the element type. The slices
   and the two-dimensional arrays are in sections, for a host that has the
   vectors and arrays alone. *)
structure TestMonoLargeInt =
struct
  fun i n = LargeInt.fromInt n
  (* 10^27, beyond any machine word, and 2^30 and 2^60, numbers of two and
     three digits of base 2^30 *)
  val most = LargeInt.* (i 1000000000, LargeInt.* (i 1000000000, i 1000000000))
  val least = LargeInt.~ most
  val p30 = LargeInt.* (i 32768, i 32768)
  val p60 = LargeInt.* (p30, p30)
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, LargeInt.+ (least, i 1), LargeInt.- (most, i 1)]
                               @ [i 7, i 42, i ~42, p30, LargeInt.- (p30, i 1), p60, LargeInt.~ p60, i 1000])
  val show = LargeInt.toString
  val same : LargeInt.int * LargeInt.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = LargeIntVector val name = "LargeIntVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = LargeIntArray structure V = LargeIntVector val name = "LargeIntArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (LargeIntVector.length v, fn k => LargeIntVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is LargeInt.int ---- *)
  val () = eqE ("LargeIntVector.fromList/extremes", [least, most, i 0], fn () => vectorToList (LargeIntVector.fromList [least, most, i 0]))
  val () = eqE ("LargeIntVector.foldl/LargeInt-arithmetic", [i 45], fn () => [LargeIntVector.foldl LargeInt.+ (i 0) (LargeIntVector.tabulate (10, i))])
  val () = T.eq T.order ("LargeIntVector.collate/LargeInt.compare", LESS,
                         fn () => LargeIntVector.collate LargeInt.compare (LargeIntVector.fromList [least, most], LargeIntVector.fromList [LargeInt.+ (least, i 1)]))
  val () = eqE ("LargeIntArray.modify/LargeInt-arithmetic", [LargeInt.- (most, i 1), i ~1, least],
                fn () => let val a = LargeIntArray.fromList [most, i 0, LargeInt.+ (least, i 1)]
                         in LargeIntArray.modify (fn x => LargeInt.- (x, i 1)) a; LargeIntArray.foldr op :: [] a end)
  val () = eqE ("LargeIntArray.vector/extremes", [most, least], fn () => vectorToList (LargeIntArray.vector (LargeIntArray.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = LargeIntVectorSlice structure V = LargeIntVector val name = "LargeIntVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = LargeIntArraySlice structure A = LargeIntArray structure V = LargeIntVector structure VS = LargeIntVectorSlice val name = "LargeIntArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("LargeIntArraySlice.foldl/LargeInt-arithmetic", [i 55],
                fn () => [LargeIntArraySlice.foldl LargeInt.+ (i 0) (LargeIntArraySlice.slice (LargeIntArray.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = LargeIntArray2 structure V = LargeIntVector val name = "LargeIntArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = LargeIntArray2 structure V = LargeIntVector val name = "LargeIntArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("LargeIntArray2.row/extremes", [least, i 0, most],
                fn () => vectorToList (LargeIntArray2.row (LargeIntArray2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = LargeIntArray2 val name = "LargeIntArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = LargeIntArray2 structure V = LargeIntVector val name = "LargeIntArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = LargeIntVector val name = "LargeIntVector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = LargeIntArray val name = "LargeIntArray" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = LargeIntVectorSlice structure V = LargeIntVector val name = "LargeIntVectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = LargeIntVectorSlice structure V = LargeIntVector val name = "LargeIntVectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = LargeIntArraySlice structure A = LargeIntArray val name = "LargeIntArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = LargeIntArray2 val name = "LargeIntArray2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = LargeIntArray2 val name = "LargeIntArray2" val elem = i 0)
  (*>> array2-size *)
end
