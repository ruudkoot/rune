(* requires: Int32Vector Int32Array Int32 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml fn/mono_vector_fn.sml fn/mono_array_fn.sml fn/mono_vector_slice_fn.sml fn/mono_array_slice_fn.sml fn/mono_array2_fn.sml *)
(* Int32Vector, Int32Array, Int32VectorSlice, Int32ArraySlice and Int32Array2
   (optional in the specification: MONO_VECTOR, MONO_ARRAY, MONO_VECTOR_SLICE,
   MONO_ARRAY_SLICE and MONO_ARRAY2 "where type elem = Int32.int"): the checks
   that hold for every structure of those signatures, from fn/mono_*_fn.sml,
   on 16 sample integers that include 0, ~1, Int32.minInt and Int32.maxInt,
   and those of the element type. The slices and the two-dimensional arrays
   are in sections, for a host that has the vectors and arrays alone. *)
structure TestMonoInt32 =
struct
  fun i n = Int32.fromInt n
  val least = valOf Int32.minInt
  val most = valOf Int32.maxInt
  val elems = Vector.fromList ([i 0, least, most, i ~1, i 1, i 2, Int32.+ (least, i 1), Int32.- (most, i 1)]
                               @ List.map i [7, 42, ~42, 100, ~100, 12345, ~12345, 1000])
  val show = Int32.toString
  val same : Int32.int * Int32.int -> bool = op =
  structure Vector_ = TestMonoVectorFn (structure V = Int32Vector val name = "Int32Vector" val elems = elems val show = show val same = same)
  structure Array_ = TestMonoArrayFn (structure A = Int32Array structure V = Int32Vector val name = "Int32Array" val elems = elems val show = show val same = same)

  fun vectorToList v = List.tabulate (Int32Vector.length v, fn k => Int32Vector.sub (v, k))
  fun sameList ([], []) = true
    | sameList (x :: xs, y :: ys) = same (x, y) andalso sameList (xs, ys)
    | sameList _ = false
  (* eqE (label, expected, f): the elements f () are expected *)
  fun eqE (label, expected, f) =
    case (SOME (f ()) handle _ => NONE) of
      SOME got => if sameList (got, expected) then T.pass label
                  else T.fail (label, "got " ^ T.list show got ^ ", expected " ^ T.list show expected)
    | NONE => T.fail (label, "raised an exception")

  (* ---- elem is Int32.int ---- *)
  val () = eqE ("Int32Vector.fromList/extremes", [least, most, i 0], fn () => vectorToList (Int32Vector.fromList [least, most, i 0]))
  val () = eqE ("Int32Vector.foldl/Int32-arithmetic", [i 45], fn () => [Int32Vector.foldl Int32.+ (i 0) (Int32Vector.tabulate (10, i))])
  val () = T.eq T.order ("Int32Vector.collate/Int32.compare", LESS,
                         fn () => Int32Vector.collate Int32.compare (Int32Vector.fromList [least, most], Int32Vector.fromList [Int32.+ (least, i 1)]))
  val () = eqE ("Int32Array.modify/Int32-arithmetic", [Int32.- (most, i 1), i ~1, least],
                fn () => let val a = Int32Array.fromList [most, i 0, Int32.+ (least, i 1)]
                         in Int32Array.modify (fn x => Int32.- (x, i 1)) a; Int32Array.foldr op :: [] a end)
  val () = eqE ("Int32Array.vector/extremes", [most, least], fn () => vectorToList (Int32Array.vector (Int32Array.fromList [most, least])))

  (*<< slices *)
  structure VectorSlice_ = TestMonoVectorSliceFn (structure S = Int32VectorSlice structure V = Int32Vector val name = "Int32VectorSlice" val elems = elems val show = show val same = same)
  structure ArraySlice_ = TestMonoArraySliceFn (structure S = Int32ArraySlice structure A = Int32Array structure V = Int32Vector structure VS = Int32VectorSlice val name = "Int32ArraySlice" val elems = elems val show = show val same = same)
  (* 1 + ... + 10 *)
  val () = eqE ("Int32ArraySlice.foldl/Int32-arithmetic", [i 55],
                fn () => [Int32ArraySlice.foldl Int32.+ (i 0) (Int32ArraySlice.slice (Int32Array.tabulate (12, i), 1, SOME 10))])
  (*>> slices *)

  (*<< array2 *)
  structure Array2_ = TestMonoArray2Fn (structure A = Int32Array2 structure V = Int32Vector val name = "Int32Array2" val elems = elems val show = show val same = same)
  structure Laws2 = TestMonoArray2LawsFn (structure A = Int32Array2 structure V = Int32Vector val name = "Int32Array2" val elems = elems val show = show val same = same val empty = false)
  val () = eqE ("Int32Array2.row/extremes", [least, i 0, most],
                fn () => vectorToList (Int32Array2.row (Int32Array2.fromList [[i 1, i 2, i 3], [least, i 0, most]], 1)))
  (*>> array2 *)

  (*<< array2-no-elements *)
  structure Empty2 = TestMonoArray2EmptyFn (structure A = Int32Array2 val name = "Int32Array2" val elems = elems val show = show val same = same)
  structure LawsEmpty2 = TestMonoArray2LawsFn (structure A = Int32Array2 structure V = Int32Vector val name = "Int32Array2" val elems = elems val show = show val same = same val empty = true)
  (*>> array2-no-elements *)

  (*<< size *)
  structure VectorSize = TestMonoVectorSizeFn (structure V = Int32Vector val name = "Int32Vector" val elem = i 0)
  structure ArraySize = TestMonoArraySizeFn (structure A = Int32Array val name = "Int32Array" val elem = i 0)
  (*>> size *)

  (*<< slices-size *)
  structure VectorSliceSize = TestMonoVectorSliceSizeFn (structure S = Int32VectorSlice structure V = Int32Vector val name = "Int32VectorSlice" val elem = i 0)
  structure VectorSliceOverflow = TestMonoVectorSliceOverflowFn (structure S = Int32VectorSlice structure V = Int32Vector val name = "Int32VectorSlice" val elem = i 0)
  structure ArraySliceOverflow = TestMonoArraySliceOverflowFn (structure S = Int32ArraySlice structure A = Int32Array val name = "Int32ArraySlice" val elem = i 0)
  (*>> slices-size *)

  (*<< array2-size *)
  structure Array2Overflow = TestMonoArray2OverflowFn (structure A = Int32Array2 val name = "Int32Array2" val elem = i 0)
  structure Array2Size = TestMonoArray2SizeFn (structure A = Int32Array2 val name = "Int32Array2" val elem = i 0)
  (*>> array2-size *)
end
