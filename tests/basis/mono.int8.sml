(* requires: Int8Vector Int8Array Int8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Int8Vector, Int8Array, Int8VectorSlice, Int8ArraySlice and Int8Array2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = Int8.int"): the checks
   that hold for every structure of those signatures, from fn/mono_*_fn.sml,
   on 16 sample integers that include 0, ~1, Int8.minInt and Int8.maxInt, and
   those of the element type. The slices and the two-dimensional arrays are in
   sections, for a host that has the vectors and arrays alone. *)
structure TestMonoInt8 =
struct
  fun i n = Int8.fromInt n
  val least = valOf Int8.minInt
  val most = valOf Int8.maxInt
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, Int8.+ (least, i 1), Int8.- (most, i 1)]
                               @ List.map i [7, 42, ~42, 100, ~100, 64, ~64, 10])
  val show = Int8.toString
  val same : Int8.int * Int8.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Int8Vector val name = "Int8Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Int8Array structure V = Int8Vector val name = "Int8Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Int8Vector.length v, fn k => Int8Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Int8.int ---- *)
  val () = eqE ("Int8Vector.fromList/extremes", [least, most, i 0], fn () => vectorToList (Int8Vector.fromList [least, most, i 0]))
  val () = eqE ("Int8Vector.foldl/Int8-arithmetic", [i 45], fn () => [Int8Vector.foldl Int8.+ (i 0) (Int8Vector.tabulate (10, i))])
  val () = T.eq T.order ("Int8Vector.collate/Int8.compare", LESS,
                         fn () => Int8Vector.collate Int8.compare (Int8Vector.fromList [least, most], Int8Vector.fromList [Int8.+ (least, i 1)]))
  val () = eqE ("Int8Array.modify/Int8-arithmetic", [Int8.- (most, i 1), i ~1, least],
                fn () => let val a = Int8Array.fromList [most, i 0, Int8.+ (least, i 1)]
                         in Int8Array.modify (fn x => Int8.- (x, i 1)) a; Int8Array.foldr op :: [] a end)
  val () = eqE ("Int8Array.vector/extremes", [most, least], fn () => vectorToList (Int8Array.vector (Int8Array.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Int8VectorSlice structure V = Int8Vector val name = "Int8VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Int8ArraySlice structure A = Int8Array structure V = Int8Vector structure VS = Int8VectorSlice val name = "Int8ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Int8ArraySlice.foldl/Int8-arithmetic", [i 55],
                fn () => [Int8ArraySlice.foldl Int8.+ (i 0) (Int8ArraySlice.slice (Int8Array.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Int8Array2 structure V = Int8Vector val name = "Int8Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Int8Array2 structure V = Int8Vector val name = "Int8Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Int8Array2.row/extremes", [least, i 0, most],
                fn () => vectorToList (Int8Array2.row (Int8Array2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Int8Array2 val name = "Int8Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Int8Array2 structure V = Int8Vector val name = "Int8Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Int8Vector val name = "Int8Vector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Int8Array val name = "Int8Array" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Int8VectorSlice structure V = Int8Vector val name = "Int8VectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Int8VectorSlice structure V = Int8Vector val name = "Int8VectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Int8ArraySlice structure A = Int8Array val name = "Int8ArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Int8Array2 val name = "Int8Array2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Int8Array2 val name = "Int8Array2" val elem = i 0)
  (*>> array2-size *)
end
