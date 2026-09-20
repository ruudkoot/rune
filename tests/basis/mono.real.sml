(* requires: RealVector RealArray Real List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* RealVector, RealArray, RealVectorSlice, RealArraySlice and RealArray2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = real"): the checks that
   hold for every structure of those signatures, from fn/mono_*_fn.sml, on 16
   sample reals that include 0.0, ~0.0, the infinities, a NaN, maxFinite and
   minPos, compared as the same IEEE value (a NaN is the same as a NaN), and
   those of the element type. The slices and the two-dimensional arrays are in
   sections, for a host that has the vectors and arrays alone. *)
structure TestMonoReal =
struct
  fun r x = Real.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x)
  val nan = Real.- (Real.posInf, Real.posInf)
  val elems = Vector.fromList ([r 0.0, r ~0.0, r 1.5, r ~2.25, Real.posInf, Real.negInf, Real.maxFinite, nan]
                               @ [Real.minPos, r 1.0, r ~1.0, r 0.1, r 1E100, r ~1E~100, Real.minNormalPos, Real.~ Real.maxFinite])
  val show = Real.toString
  (* the same IEEE value: a NaN is a NaN, 0.0 is not ~0.0 *)
  fun same (a, b) =
    if Real.isNan a orelse Real.isNan b then Real.isNan a andalso Real.isNan b
    else Real.== (a, b) andalso Real.signBit a = Real.signBit b
  structure Vector_ = TestMonoVectorFn (structure V = RealVector val name = "RealVector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = RealArray structure V = RealVector val name = "RealArray" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (RealVector.length v, fn k => RealVector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is real ---- *)
  val () = eqE ("RealVector.fromList/specials", [Real.posInf, Real.negInf, nan, r ~0.0],
                fn () => vectorToList (RealVector.fromList [Real.posInf, Real.negInf, nan, r ~0.0]))
  (* twice maxFinite rounds to posInf *)
  val () = eqE ("RealVector.map/Real-arithmetic", [r 3.0, Real.negInf, r ~0.0, Real.posInf],
                fn () => vectorToList (RealVector.map (fn x => Real.* (x, r 2.0)) (RealVector.fromList [r 1.5, Real.negInf, r ~0.0, Real.maxFinite])))
  val () = eqE ("RealVector.find/nan", [nan],
                fn () => case RealVector.find Real.isNan (RealVector.fromList [r 1.0, nan, r 2.0]) of SOME x => [x] | NONE => [])
  val () = eqE ("RealVector.foldl/Real-arithmetic", [r 45.0], fn () => [RealVector.foldl Real.+ (r 0.0) (RealVector.tabulate (10, Real.fromInt))])
  val () = T.eq T.order ("RealVector.collate/Real.compare", LESS,
                         fn () => RealVector.collate Real.compare (RealVector.fromList [Real.negInf], RealVector.fromList [Real.~ Real.maxFinite]))
  val () = eqE ("RealArray.modify/Real-arithmetic", [r ~0.0, Real.negInf, r ~1.5],
                fn () => let val a = RealArray.fromList [r 0.0, Real.posInf, r 1.5] in RealArray.modify Real.~ a; RealArray.foldr op :: [] a end)
  val () = eqE ("RealArray.vector/specials", [nan, Real.minPos], fn () => vectorToList (RealArray.vector (RealArray.fromList [nan, Real.minPos])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = RealVectorSlice structure V = RealVector val name = "RealVectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = RealArraySlice structure A = RealArray structure V = RealVector structure VS = RealVectorSlice val name = "RealArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("RealArraySlice.foldl/Real-arithmetic", [r 55.0],
                fn () => [RealArraySlice.foldl Real.+ (r 0.0) (RealArraySlice.slice (RealArray.tabulate (12, Real.fromInt), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = RealArray2 structure V = RealVector val name = "RealArray2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = RealArray2 structure V = RealVector val name = "RealArray2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("RealArray2.row/specials", [Real.negInf, nan, r ~0.0],
                fn () => vectorToList (RealArray2.row (RealArray2.fromList [[r 1.0, r 2.0, r 3.0], [Real.negInf, nan, r ~0.0]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = RealArray2 val name = "RealArray2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = RealArray2 structure V = RealVector val name = "RealArray2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = RealVector val name = "RealVector" val elem = r 0.0)
  structure ArraySize = TestMonoArraySizeFn (structure A = RealArray val name = "RealArray" val elem = r 0.0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = RealVectorSlice structure V = RealVector val name = "RealVectorSlice" val elem = r 0.0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = RealVectorSlice structure V = RealVector val name = "RealVectorSlice" val elem = r 0.0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = RealArraySlice structure A = RealArray val name = "RealArraySlice" val elem = r 0.0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = RealArray2 val name = "RealArray2" val elem = r 0.0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = RealArray2 val name = "RealArray2" val elem = r 0.0)
  (*>> array2-size *)
end
