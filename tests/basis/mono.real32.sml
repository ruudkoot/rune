(* requires: Real32Vector Real32Array Real32 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Real32Vector, Real32Array, Real32VectorSlice, Real32ArraySlice and
   Real32Array2 (optional in the specification: MONO_VECTOR, MONO_ARRAY,
   MONO_VECTOR_SLICE, MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem =
   Real32.real"): the checks that hold for every structure of those
   signatures, from fn/mono_*_fn.sml, on 16 sample reals that include 0.0,
   ~0.0, the infinities, a NaN, maxFinite and minPos, compared as the same
   IEEE value (a NaN is the same as a NaN), and those of the element type.
   The slices and the two-dimensional arrays are in sections, for a host that
   has the vectors and arrays alone. *)
structure TestMonoReal32 =
struct
  fun r x = Real32.fromLarge IEEEReal.TO_NEAREST (Real.toLarge x)
  val nan = Real32.- (Real32.posInf, Real32.posInf)
  val elems = Vector.fromList ([r 0.0, r ~0.0, r 1.5, r ~2.25, Real32.posInf, Real32.negInf, Real32.maxFinite, nan]
                               @ [Real32.minPos, r 1.0, r ~1.0, r 0.1, r 1E30, r ~1E~30, Real32.minNormalPos, Real32.~ Real32.maxFinite])
  val show = Real32.toString
  (* the same IEEE value: a NaN is a NaN, 0.0 is not ~0.0 *)
  fun same (a, b) =
    if Real32.isNan a orelse Real32.isNan b then Real32.isNan a andalso Real32.isNan b
    else Real32.== (a, b) andalso Real32.signBit a = Real32.signBit b
  structure Vector_ = TestMonoVectorFn (structure V = Real32Vector val name = "Real32Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Real32Array structure V = Real32Vector val name = "Real32Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Real32Vector.length v, fn k => Real32Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Real32.real ---- *)
  val () = eqE ("Real32Vector.fromList/specials", [Real32.posInf, Real32.negInf, nan, r ~0.0],
                fn () => vectorToList (Real32Vector.fromList [Real32.posInf, Real32.negInf, nan, r ~0.0]))
  (* twice maxFinite rounds to posInf *)
  val () = eqE ("Real32Vector.map/Real32-arithmetic", [r 3.0, Real32.negInf, r ~0.0, Real32.posInf],
                fn () => vectorToList (Real32Vector.map (fn x => Real32.* (x, r 2.0)) (Real32Vector.fromList [r 1.5, Real32.negInf, r ~0.0, Real32.maxFinite])))
  val () = eqE ("Real32Vector.find/nan", [nan],
                fn () => case Real32Vector.find Real32.isNan (Real32Vector.fromList [r 1.0, nan, r 2.0]) of SOME x => [x] | NONE => [])
  val () = eqE ("Real32Vector.foldl/Real32-arithmetic", [r 45.0], fn () => [Real32Vector.foldl Real32.+ (r 0.0) (Real32Vector.tabulate (10, Real32.fromInt))])
  val () = T.eq T.order ("Real32Vector.collate/Real32.compare", LESS,
                         fn () => Real32Vector.collate Real32.compare (Real32Vector.fromList [Real32.negInf], Real32Vector.fromList [Real32.~ Real32.maxFinite]))
  val () = eqE ("Real32Array.modify/Real32-arithmetic", [r ~0.0, Real32.negInf, r ~1.5],
                fn () => let val a = Real32Array.fromList [r 0.0, Real32.posInf, r 1.5] in Real32Array.modify Real32.~ a; Real32Array.foldr op :: [] a end)
  val () = eqE ("Real32Array.vector/specials", [nan, Real32.minPos], fn () => vectorToList (Real32Array.vector (Real32Array.fromList [nan, Real32.minPos])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Real32VectorSlice structure V = Real32Vector val name = "Real32VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Real32ArraySlice structure A = Real32Array structure V = Real32Vector structure VS = Real32VectorSlice val name = "Real32ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Real32ArraySlice.foldl/Real32-arithmetic", [r 55.0],
                fn () => [Real32ArraySlice.foldl Real32.+ (r 0.0) (Real32ArraySlice.slice (Real32Array.tabulate (12, Real32.fromInt), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Real32Array2 structure V = Real32Vector val name = "Real32Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Real32Array2 structure V = Real32Vector val name = "Real32Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Real32Array2.row/specials", [Real32.negInf, nan, r ~0.0],
                fn () => vectorToList (Real32Array2.row (Real32Array2.fromList [[r 1.0, r 2.0, r 3.0], [Real32.negInf, nan, r ~0.0]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Real32Array2 val name = "Real32Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Real32Array2 structure V = Real32Vector val name = "Real32Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Real32Vector val name = "Real32Vector" val elem = r 0.0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Real32Array val name = "Real32Array" val elem = r 0.0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Real32VectorSlice structure V = Real32Vector val name = "Real32VectorSlice" val elem = r 0.0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Real32VectorSlice structure V = Real32Vector val name = "Real32VectorSlice" val elem = r 0.0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Real32ArraySlice structure A = Real32Array val name = "Real32ArraySlice" val elem = r 0.0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Real32Array2 val name = "Real32Array2" val elem = r 0.0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Real32Array2 val name = "Real32Array2" val elem = r 0.0)
  (*>> array2-size *)
end
