(* requires: Int64Vector Int64Array Int64 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Int64Vector, Int64Array, Int64VectorSlice, Int64ArraySlice and Int64Array2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = Int64.int"): the checks
   that hold for every structure of those signatures, from fn/mono_*_fn.sml,
   on 16 sample integers that include 0, ~1, Int64.minInt and Int64.maxInt,
   and those of the element type. Int64 is Int in Rune, and Int64Vector is
   IntVector. The slices and the two-dimensional arrays are in sections, for a
   host that has the vectors and arrays alone. *)
structure TestMonoInt64 =
struct
  fun i n = Int64.fromInt n
  val least = valOf Int64.minInt
  val most = valOf Int64.maxInt
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, Int64.+ (least, i 1), Int64.- (most, i 1)]
                               @ List.map i [7, 42, ~42, 100, ~100, 12345, ~12345, 1000])
  val show = Int64.toString
  val same : Int64.int * Int64.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Int64Vector val name = "Int64Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Int64Array structure V = Int64Vector val name = "Int64Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Int64Vector.length v, fn k => Int64Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Int64.int ---- *)
  val () = eqE ("Int64Vector.fromList/extremes", [least, most, i 0], fn () => vectorToList (Int64Vector.fromList [least, most, i 0]))
  val () = eqE ("Int64Vector.foldl/Int64-arithmetic", [i 45], fn () => [Int64Vector.foldl Int64.+ (i 0) (Int64Vector.tabulate (10, i))])
  val () = T.eq T.order ("Int64Vector.collate/Int64.compare", LESS,
                         fn () => Int64Vector.collate Int64.compare (Int64Vector.fromList [least, most], Int64Vector.fromList [Int64.+ (least, i 1)]))
  val () = eqE ("Int64Array.modify/Int64-arithmetic", [Int64.- (most, i 1), i ~1, least],
                fn () => let val a = Int64Array.fromList [most, i 0, Int64.+ (least, i 1)]
                         in Int64Array.modify (fn x => Int64.- (x, i 1)) a; Int64Array.foldr op :: [] a end)
  val () = eqE ("Int64Array.vector/extremes", [most, least], fn () => vectorToList (Int64Array.vector (Int64Array.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Int64VectorSlice structure V = Int64Vector val name = "Int64VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Int64ArraySlice structure A = Int64Array structure V = Int64Vector structure VS = Int64VectorSlice val name = "Int64ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Int64ArraySlice.foldl/Int64-arithmetic", [i 55],
                fn () => [Int64ArraySlice.foldl Int64.+ (i 0) (Int64ArraySlice.slice (Int64Array.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Int64Array2 structure V = Int64Vector val name = "Int64Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Int64Array2 structure V = Int64Vector val name = "Int64Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Int64Array2.row/extremes", [least, i 0, most],
                fn () => vectorToList (Int64Array2.row (Int64Array2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Int64Array2 val name = "Int64Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Int64Array2 structure V = Int64Vector val name = "Int64Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Int64Vector val name = "Int64Vector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Int64Array val name = "Int64Array" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Int64VectorSlice structure V = Int64Vector val name = "Int64VectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Int64VectorSlice structure V = Int64Vector val name = "Int64VectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Int64ArraySlice structure A = Int64Array val name = "Int64ArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Int64Array2 val name = "Int64Array2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Int64Array2 val name = "Int64Array2" val elem = i 0)
  (*>> array2-size *)
end
