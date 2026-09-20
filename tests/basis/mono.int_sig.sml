(* requires: IntVector IntArray Int *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* IntVector, IntArray, IntVectorSlice, IntArraySlice and
   IntArray2 match their signatures, with the constraints of the
   specification:
     structure IntVector :> MONO_VECTOR where type elem = int
     structure IntArray :> MONO_ARRAY where type vector = IntVector.vector
       where type elem = int
     structure IntVectorSlice :> MONO_VECTOR_SLICE
       where type vector = IntVector.vector where type elem = int
     structure IntArraySlice :> MONO_ARRAY_SLICE
       where type vector = IntVector.vector
       where type vector_slice = IntVectorSlice.slice
       where type array = IntArray.array where type elem = int
     structure IntArray2 :> MONO_ARRAY2 where type vector = IntVector.vector
       where type elem = int
   and each can be implemented opaquely. *)
structure TestMonoIntSig =
struct
  fun x n = Int.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = IntVector
  structure VE : SPEC_MONO_VECTOR where type elem = int = IntVector
  structure VO :> SPEC_MONO_VECTOR where type elem = int = IntVector
  val () = T.check ("IntVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("IntVector:MONO_VECTOR/elem-is-int", fn () => eq (VE.sub (VE.fromList [x 7], 0) : int, x 7))
  val () = T.check ("IntVector:MONO_VECTOR/vector-is-IntVector.vector",
                    fn () => IntVector.length (V.fromList [] : IntVector.vector) = 0 andalso V.length (IntVector.fromList [] : V.vector) = 0)
  val () = T.check ("IntVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = IntArray
  structure AE : SPEC_MONO_ARRAY where type vector = IntVector.vector where type elem = int = IntArray
  structure AO :> SPEC_MONO_ARRAY where type vector = IntVector.vector where type elem = int = IntArray
  val () = T.check ("IntArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("IntArray:MONO_ARRAY/elem-is-int", fn () => eq (AE.sub (AE.array (1, x 7), 0) : int, x 7))
  val () = T.check ("IntArray:MONO_ARRAY/vector-is-IntVector.vector", fn () => IntVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("IntArray:MONO_ARRAY/array-is-IntArray.array",
                    fn () => IntArray.length (A.fromList [] : IntArray.array) = 0 andalso A.length (IntArray.fromList [] : A.array) = 0)
  val () = T.check ("IntArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("IntArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = IntVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int = IntVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int = IntVectorSlice
  val () = T.check ("IntVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("IntVectorSlice:MONO_VECTOR_SLICE/vector-is-IntVector.vector",
                    fn () => IntVector.length (VSE.vector (VSE.full (IntVector.tabulate (3, x)))) = 3)
  val () = T.check ("IntVectorSlice:MONO_VECTOR_SLICE/elem-is-int",
                    fn () => eq (VSE.sub (VSE.full (IntVector.tabulate (3, x)), 2) : int, x 2))
  val () = T.check ("IntVectorSlice:MONO_VECTOR_SLICE/slice-is-IntVectorSlice.slice",
                    fn () => IntVectorSlice.length (VS.full (IntVector.fromList []) : IntVectorSlice.slice) = 0
                             andalso VS.length (IntVectorSlice.full (IntVector.fromList []) : VS.slice) = 0)
  val () = T.check ("IntVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (IntVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = IntArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int = IntArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int = IntArraySlice
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/array-is-IntArray.array",
                    fn () => IntArray.length (#1 (ASE.base (ASE.full (IntArray.array (3, x 0))))) = 3)
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/vector-is-IntVector.vector",
                    fn () => IntVector.length (ASE.vector (ASE.full (IntArray.array (3, x 0)))) = 3)
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/vector_slice-is-IntVectorSlice.slice",
                    fn () => let val a = IntArray.array (3, x 0)
                             in ASE.copyVec {src = IntVectorSlice.full (IntVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (IntArray.sub (a, 2), x 9) end)
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/elem-is-int", fn () => eq (ASE.sub (ASE.full (IntArray.array (1, x 7)), 0) : int, x 7))
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/slice-is-IntArraySlice.slice",
                    fn () => IntArraySlice.length (AS.full (IntArray.fromList []) : IntArraySlice.slice) = 0
                             andalso AS.length (IntArraySlice.full (IntArray.fromList []) : AS.slice) = 0)
  val () = T.check ("IntArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (IntArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = IntArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = IntVector.vector where type elem = int = IntArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = IntVector.vector where type elem = int = IntArray2
  val () = T.check ("IntArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("IntArray2:MONO_ARRAY2/elem-is-int", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : int, x 7))
  val () = T.check ("IntArray2:MONO_ARRAY2/vector-is-IntVector.vector", fn () => IntVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("IntArray2:MONO_ARRAY2/array-is-IntArray2.array",
                    fn () => IntArray2.nRows (A2.array (2, 3, x 0) : IntArray2.array) = 2
                             andalso A2.nCols (IntArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("IntArray2:MONO_ARRAY2/region-is-IntArray2.region",
                    fn () => let val a = IntArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : IntArray2.region) = 3 end)
  val () = T.check ("IntArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso IntArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("IntArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("IntArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
