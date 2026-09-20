(* requires: LargeIntVector LargeIntArray LargeInt *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* LargeIntVector, LargeIntArray, LargeIntVectorSlice, LargeIntArraySlice and
   LargeIntArray2 match their signatures, with the constraints of the
   specification:
     structure LargeIntVector :> MONO_VECTOR where type elem = LargeInt.int
     structure LargeIntArray :> MONO_ARRAY where type vector = LargeIntVector.vector
       where type elem = LargeInt.int
     structure LargeIntVectorSlice :> MONO_VECTOR_SLICE
       where type vector = LargeIntVector.vector where type elem = LargeInt.int
     structure LargeIntArraySlice :> MONO_ARRAY_SLICE
       where type vector = LargeIntVector.vector
       where type vector_slice = LargeIntVectorSlice.slice
       where type array = LargeIntArray.array where type elem = LargeInt.int
     structure LargeIntArray2 :> MONO_ARRAY2 where type vector = LargeIntVector.vector
       where type elem = LargeInt.int
   and each can be implemented opaquely. *)
structure TestMonoLargeIntSig =
struct
  fun x n = LargeInt.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = LargeIntVector
  structure VE : SPEC_MONO_VECTOR where type elem = LargeInt.int = LargeIntVector
  structure VO :> SPEC_MONO_VECTOR where type elem = LargeInt.int = LargeIntVector
  val () = T.check ("LargeIntVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("LargeIntVector:MONO_VECTOR/elem-is-LargeInt.int", fn () => eq (VE.sub (VE.fromList [x 7], 0) : LargeInt.int, x 7))
  val () = T.check ("LargeIntVector:MONO_VECTOR/vector-is-LargeIntVector.vector",
                    fn () => LargeIntVector.length (V.fromList [] : LargeIntVector.vector) = 0 andalso V.length (LargeIntVector.fromList [] : V.vector) = 0)
  val () = T.check ("LargeIntVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = LargeIntArray
  structure AE : SPEC_MONO_ARRAY where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntArray
  structure AO :> SPEC_MONO_ARRAY where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntArray
  val () = T.check ("LargeIntArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("LargeIntArray:MONO_ARRAY/elem-is-LargeInt.int", fn () => eq (AE.sub (AE.array (1, x 7), 0) : LargeInt.int, x 7))
  val () = T.check ("LargeIntArray:MONO_ARRAY/vector-is-LargeIntVector.vector", fn () => LargeIntVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("LargeIntArray:MONO_ARRAY/array-is-LargeIntArray.array",
                    fn () => LargeIntArray.length (A.fromList [] : LargeIntArray.array) = 0 andalso A.length (LargeIntArray.fromList [] : A.array) = 0)
  val () = T.check ("LargeIntArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("LargeIntArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = LargeIntVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntVectorSlice
  val () = T.check ("LargeIntVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("LargeIntVectorSlice:MONO_VECTOR_SLICE/vector-is-LargeIntVector.vector",
                    fn () => LargeIntVector.length (VSE.vector (VSE.full (LargeIntVector.tabulate (3, x)))) = 3)
  val () = T.check ("LargeIntVectorSlice:MONO_VECTOR_SLICE/elem-is-LargeInt.int",
                    fn () => eq (VSE.sub (VSE.full (LargeIntVector.tabulate (3, x)), 2) : LargeInt.int, x 2))
  val () = T.check ("LargeIntVectorSlice:MONO_VECTOR_SLICE/slice-is-LargeIntVectorSlice.slice",
                    fn () => LargeIntVectorSlice.length (VS.full (LargeIntVector.fromList []) : LargeIntVectorSlice.slice) = 0
                             andalso VS.length (LargeIntVectorSlice.full (LargeIntVector.fromList []) : VS.slice) = 0)
  val () = T.check ("LargeIntVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (LargeIntVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = LargeIntArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int = LargeIntArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int = LargeIntArraySlice
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/array-is-LargeIntArray.array",
                    fn () => LargeIntArray.length (#1 (ASE.base (ASE.full (LargeIntArray.array (3, x 0))))) = 3)
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/vector-is-LargeIntVector.vector",
                    fn () => LargeIntVector.length (ASE.vector (ASE.full (LargeIntArray.array (3, x 0)))) = 3)
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/vector_slice-is-LargeIntVectorSlice.slice",
                    fn () => let val a = LargeIntArray.array (3, x 0)
                             in ASE.copyVec {src = LargeIntVectorSlice.full (LargeIntVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (LargeIntArray.sub (a, 2), x 9) end)
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/elem-is-LargeInt.int", fn () => eq (ASE.sub (ASE.full (LargeIntArray.array (1, x 7)), 0) : LargeInt.int, x 7))
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/slice-is-LargeIntArraySlice.slice",
                    fn () => LargeIntArraySlice.length (AS.full (LargeIntArray.fromList []) : LargeIntArraySlice.slice) = 0
                             andalso AS.length (LargeIntArraySlice.full (LargeIntArray.fromList []) : AS.slice) = 0)
  val () = T.check ("LargeIntArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (LargeIntArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = LargeIntArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int = LargeIntArray2
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/elem-is-LargeInt.int", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : LargeInt.int, x 7))
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/vector-is-LargeIntVector.vector", fn () => LargeIntVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/array-is-LargeIntArray2.array",
                    fn () => LargeIntArray2.nRows (A2.array (2, 3, x 0) : LargeIntArray2.array) = 2
                             andalso A2.nCols (LargeIntArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/region-is-LargeIntArray2.region",
                    fn () => let val a = LargeIntArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : LargeIntArray2.region) = 3 end)
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso LargeIntArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("LargeIntArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
