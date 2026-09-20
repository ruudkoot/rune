(* requires: Real64Vector Real64Array Real64 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Real64Vector, Real64Array, Real64VectorSlice, Real64ArraySlice and
   Real64Array2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   Real64.real"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample reals that include 0.0,
   ~0.0, the infinities, a NaN, maxFinite and minPos, compared as the same
   IEEE value (a NaN is the same as a NaN), and those of the element type.
   Real64 is Real in Rune, and Real64Vector is RealVector. The slices and the
   two-dimensional arrays are in sections, for a host that has the vectors and
   arrays alone. *)
structure TestMonoReal64 =
struct
  fun r x = Real64.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x)
  val nan = Real64.- (Real64.posInf, Real64.posInf)
  val elems = Vector.fromList ([r 0.0, r ~0.0, r 1.5, r ~2.25, Real64.posInf, Real64.negInf, Real64.maxFinite, nan]
                               @ [Real64.minPos, r 1.0, r ~1.0, r 0.1, r 1E100, r ~1E~100, Real64.minNormalPos, Real64.~ Real64.maxFinite])
  val show = Real64.toString
  (* the same IEEE value: a NaN is a NaN, 0.0 is not ~0.0 *)
  fun same (a, b) =
    if Real64.isNan a orelse Real64.isNan b then Real64.isNan a andalso Real64.isNan b
    else Real64.== (a, b) andalso Real64.signBit a = Real64.signBit b
  structure Vector_ = TestMonoVectorFn (structure V = Real64Vector val name = "Real64Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Real64Array structure V = Real64Vector val name = "Real64Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Real64Vector.length v, fn k => Real64Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Real64.real ---- *)
  val () = eqE ("Real64Vector.fromList/specials", [Real64.posInf, Real64.negInf, nan, r ~0.0],
                fn () => vectorToList (Real64Vector.fromList [Real64.posInf, Real64.negInf, nan, r ~0.0]))
  (* twice maxFinite rounds to posInf *)
  val () = eqE ("Real64Vector.map/Real64-arithmetic", [r 3.0, Real64.negInf, r ~0.0, Real64.posInf],
                fn () => vectorToList (Real64Vector.map (fn x => Real64.* (x, r 2.0)) (Real64Vector.fromList [r 1.5, Real64.negInf, r ~0.0, Real64.maxFinite])))
  val () = eqE ("Real64Vector.find/nan", [nan],
                fn () => case Real64Vector.find Real64.isNan (Real64Vector.fromList [r 1.0, nan, r 2.0]) of SOME x => [x] | NONE => [])
  val () = eqE ("Real64Vector.foldl/Real64-arithmetic", [r 45.0], fn () => [Real64Vector.foldl Real64.+ (r 0.0) (Real64Vector.tabulate (10, Real64.fromInt))])
  val () = T.eq T.order ("Real64Vector.collate/Real64.compare", LESS,
                         fn () => Real64Vector.collate Real64.compare (Real64Vector.fromList [Real64.negInf], Real64Vector.fromList [Real64.~ Real64.maxFinite]))
  val () = eqE ("Real64Array.modify/Real64-arithmetic", [r ~0.0, Real64.negInf, r ~1.5],
                fn () => let val a = Real64Array.fromList [r 0.0, Real64.posInf, r 1.5] in Real64Array.modify Real64.~ a; Real64Array.foldr op :: [] a end)
  val () = eqE ("Real64Array.vector/specials", [nan, Real64.minPos], fn () => vectorToList (Real64Array.vector (Real64Array.fromList [nan, Real64.minPos])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Real64VectorSlice structure V = Real64Vector val name = "Real64VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Real64ArraySlice structure A = Real64Array structure V = Real64Vector structure VS = Real64VectorSlice val name = "Real64ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Real64ArraySlice.foldl/Real64-arithmetic", [r 55.0],
                fn () => [Real64ArraySlice.foldl Real64.+ (r 0.0) (Real64ArraySlice.slice (Real64Array.tabulate (12, Real64.fromInt), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Real64Array2 structure V = Real64Vector val name = "Real64Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Real64Array2 structure V = Real64Vector val name = "Real64Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Real64Array2.row/specials", [Real64.negInf, nan, r ~0.0],
                fn () => vectorToList (Real64Array2.row (Real64Array2.fromList [[r 1.0, r 2.0, r 3.0], [Real64.negInf, nan, r ~0.0]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Real64Array2 val name = "Real64Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Real64Array2 structure V = Real64Vector val name = "Real64Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Real64Vector val name = "Real64Vector" val elem = r 0.0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Real64Array val name = "Real64Array" val elem = r 0.0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Real64VectorSlice structure V = Real64Vector val name = "Real64VectorSlice" val elem = r 0.0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Real64VectorSlice structure V = Real64Vector val name = "Real64VectorSlice" val elem = r 0.0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Real64ArraySlice structure A = Real64Array val name = "Real64ArraySlice" val elem = r 0.0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Real64Array2 val name = "Real64Array2" val elem = r 0.0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Real64Array2 val name = "Real64Array2" val elem = r 0.0)
  (*>> array2-size *)
end
