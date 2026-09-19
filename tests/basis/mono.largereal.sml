(* requires: LargeRealVector LargeRealArray LargeReal List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* LargeRealVector, LargeRealArray, LargeRealVectorSlice, LargeRealArraySlice
   and LargeRealArray2 (optional in the specification: MONO_VECTOR,
   MONO_ARRAY, MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type
   elem = LargeReal.real"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample reals that include 0.0,
   ~0.0, the infinities, a NaN, maxFinite and minPos, compared as the same
   IEEE value (a NaN is the same as a NaN), and those of the element type.
   LargeReal is Real in Rune, and LargeRealVector is RealVector. The slices
   and the two-dimensional arrays are in sections, for a host that has the
   vectors and arrays alone. *)
structure TestMonoLargeReal =
struct
  fun r x = LargeReal.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x)
  val nan = LargeReal.- (LargeReal.posInf, LargeReal.posInf)
  val elems = Vector.fromList ([r 0.0, r ~0.0, r 1.5, r ~2.25, LargeReal.posInf, LargeReal.negInf, LargeReal.maxFinite, nan]
                               @ [LargeReal.minPos, r 1.0, r ~1.0, r 0.1, r 1E100, r ~1E~100, LargeReal.minNormalPos, LargeReal.~ LargeReal.maxFinite])
  val show = LargeReal.toString
  (* the same IEEE value: a NaN is a NaN, 0.0 is not ~0.0 *)
  fun same (a, b) =
    if LargeReal.isNan a orelse LargeReal.isNan b then LargeReal.isNan a andalso LargeReal.isNan b
    else LargeReal.== (a, b) andalso LargeReal.signBit a = LargeReal.signBit b
  structure Vector_ = TestMonoVectorFn (structure V = LargeRealVector val name = "LargeRealVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = LargeRealArray structure V = LargeRealVector val name = "LargeRealArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (LargeRealVector.length v, fn k => LargeRealVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is LargeReal.real ---- *)
  val () = eqE ("LargeRealVector.fromList/specials", [LargeReal.posInf, LargeReal.negInf, nan, r ~0.0],
                fn () => vectorToList (LargeRealVector.fromList [LargeReal.posInf, LargeReal.negInf, nan, r ~0.0]))
  (* twice maxFinite rounds to posInf *)
  val () = eqE ("LargeRealVector.map/LargeReal-arithmetic", [r 3.0, LargeReal.negInf, r ~0.0, LargeReal.posInf],
                fn () => vectorToList (LargeRealVector.map (fn x => LargeReal.* (x, r 2.0)) (LargeRealVector.fromList [r 1.5, LargeReal.negInf, r ~0.0, LargeReal.maxFinite])))
  val () = eqE ("LargeRealVector.find/nan", [nan],
                fn () => case LargeRealVector.find LargeReal.isNan (LargeRealVector.fromList [r 1.0, nan, r 2.0]) of SOME x => [x] | NONE => [])
  val () = eqE ("LargeRealVector.foldl/LargeReal-arithmetic", [r 45.0], fn () => [LargeRealVector.foldl LargeReal.+ (r 0.0) (LargeRealVector.tabulate (10, LargeReal.fromInt))])
  val () = T.eq T.order ("LargeRealVector.collate/LargeReal.compare", LESS,
                         fn () => LargeRealVector.collate LargeReal.compare (LargeRealVector.fromList [LargeReal.negInf], LargeRealVector.fromList [LargeReal.~ LargeReal.maxFinite]))
  val () = eqE ("LargeRealArray.modify/LargeReal-arithmetic", [r ~0.0, LargeReal.negInf, r ~1.5],
                fn () => let val a = LargeRealArray.fromList [r 0.0, LargeReal.posInf, r 1.5] in LargeRealArray.modify LargeReal.~ a; LargeRealArray.foldr op :: [] a end)
  val () = eqE ("LargeRealArray.vector/specials", [nan, LargeReal.minPos], fn () => vectorToList (LargeRealArray.vector (LargeRealArray.fromList [nan, LargeReal.minPos])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = LargeRealVectorSlice structure V = LargeRealVector val name = "LargeRealVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = LargeRealArraySlice structure A = LargeRealArray structure V = LargeRealVector structure VS = LargeRealVectorSlice val name = "LargeRealArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("LargeRealArraySlice.foldl/LargeReal-arithmetic", [r 55.0],
                fn () => [LargeRealArraySlice.foldl LargeReal.+ (r 0.0) (LargeRealArraySlice.slice (LargeRealArray.tabulate (12, LargeReal.fromInt), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = LargeRealArray2 structure V = LargeRealVector val name = "LargeRealArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = LargeRealArray2 structure V = LargeRealVector val name = "LargeRealArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("LargeRealArray2.row/specials", [LargeReal.negInf, nan, r ~0.0],
                fn () => vectorToList (LargeRealArray2.row (LargeRealArray2.fromList [[r 1.0, r 2.0, r 3.0], [LargeReal.negInf, nan, r ~0.0]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = LargeRealArray2 val name = "LargeRealArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = LargeRealArray2 structure V = LargeRealVector val name = "LargeRealArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = LargeRealVector val name = "LargeRealVector" val elem = r 0.0)
  structure ArraySize = TestMonoArraySizeFn (structure A = LargeRealArray val name = "LargeRealArray" val elem = r 0.0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = LargeRealVectorSlice structure V = LargeRealVector val name = "LargeRealVectorSlice" val elem = r 0.0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = LargeRealVectorSlice structure V = LargeRealVector val name = "LargeRealVectorSlice" val elem = r 0.0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = LargeRealArraySlice structure A = LargeRealArray val name = "LargeRealArraySlice" val elem = r 0.0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = LargeRealArray2 val name = "LargeRealArray2" val elem = r 0.0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = LargeRealArray2 val name = "LargeRealArray2" val elem = r 0.0)
  (*>> array2-size *)
end
