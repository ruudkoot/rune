(* requires: Int16Vector Int16Array Int16 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Int16Vector, Int16Array, Int16VectorSlice, Int16ArraySlice and Int16Array2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = Int16.int"): the checks
   that hold for every structure of those signatures, from fn/mono_*_fn.sml,
   on 16 sample integers that include 0, ~1, Int16.minInt and Int16.maxInt,
   and those of the element type. The slices and the two-dimensional arrays
   are in sections, for a host that has the vectors and arrays alone. *)
structure TestMonoInt16 =
struct
  fun i n = Int16.fromInt n
  val least = valOf Int16.minInt
  val most = valOf Int16.maxInt
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, Int16.+ (least, i 1), Int16.- (most, i 1)]
                               @ List.map i [7, 42, ~42, 100, ~100, 12345, ~12345, 1000])
  val show = Int16.toString
  val same : Int16.int * Int16.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Int16Vector val name = "Int16Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Int16Array structure V = Int16Vector val name = "Int16Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Int16Vector.length v, fn k => Int16Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Int16.int ---- *)
  val () = eqE ("Int16Vector.fromList/extremes", [least, most, i 0], fn () => vectorToList (Int16Vector.fromList [least, most, i 0]))
  val () = eqE ("Int16Vector.foldl/Int16-arithmetic", [i 45], fn () => [Int16Vector.foldl Int16.+ (i 0) (Int16Vector.tabulate (10, i))])
  val () = T.eq T.order ("Int16Vector.collate/Int16.compare", LESS,
                         fn () => Int16Vector.collate Int16.compare (Int16Vector.fromList [least, most], Int16Vector.fromList [Int16.+ (least, i 1)]))
  val () = eqE ("Int16Array.modify/Int16-arithmetic", [Int16.- (most, i 1), i ~1, least],
                fn () => let val a = Int16Array.fromList [most, i 0, Int16.+ (least, i 1)]
                         in Int16Array.modify (fn x => Int16.- (x, i 1)) a; Int16Array.foldr op :: [] a end)
  val () = eqE ("Int16Array.vector/extremes", [most, least], fn () => vectorToList (Int16Array.vector (Int16Array.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Int16VectorSlice structure V = Int16Vector val name = "Int16VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Int16ArraySlice structure A = Int16Array structure V = Int16Vector structure VS = Int16VectorSlice val name = "Int16ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Int16ArraySlice.foldl/Int16-arithmetic", [i 55],
                fn () => [Int16ArraySlice.foldl Int16.+ (i 0) (Int16ArraySlice.slice (Int16Array.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Int16Array2 structure V = Int16Vector val name = "Int16Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Int16Array2 structure V = Int16Vector val name = "Int16Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Int16Array2.row/extremes", [least, i 0, most],
                fn () => vectorToList (Int16Array2.row (Int16Array2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Int16Array2 val name = "Int16Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Int16Array2 structure V = Int16Vector val name = "Int16Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Int16Vector val name = "Int16Vector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Int16Array val name = "Int16Array" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Int16VectorSlice structure V = Int16Vector val name = "Int16VectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Int16VectorSlice structure V = Int16Vector val name = "Int16VectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Int16ArraySlice structure A = Int16Array val name = "Int16ArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Int16Array2 val name = "Int16Array2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Int16Array2 val name = "Int16Array2" val elem = i 0)
  (*>> array2-size *)
end
