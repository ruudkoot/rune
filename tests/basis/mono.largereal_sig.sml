(* requires: LargeRealVector LargeRealArray LargeReal *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* LargeRealVector, LargeRealArray, LargeRealVectorSlice, LargeRealArraySlice and
   LargeRealArray2 match their signatures, with the constraints of the
   specification:
     structure LargeRealVector :> MONO_VECTOR where type elem = LargeReal.real
     structure LargeRealArray :> MONO_ARRAY where type vector = LargeRealVector.vector
       where type elem = LargeReal.real
     structure LargeRealVectorSlice :> MONO_VECTOR_SLICE
       where type vector = LargeRealVector.vector where type elem = LargeReal.real
     structure LargeRealArraySlice :> MONO_ARRAY_SLICE
       where type vector = LargeRealVector.vector
       where type vector_slice = LargeRealVectorSlice.slice
       where type array = LargeRealArray.array where type elem = LargeReal.real
     structure LargeRealArray2 :> MONO_ARRAY2 where type vector = LargeRealVector.vector
       where type elem = LargeReal.real
   and each can be implemented opaquely.
   LargeReal is Real in Rune, and LargeRealVector is RealVector; on a host they are
   structures of their own, so they are tested as such. *)
structure TestMonoLargeRealSig =
struct
  fun x n = LargeReal.fromInt n
  val eq = LargeReal.==

  structure V : SPEC_MONO_VECTOR = LargeRealVector
  structure VE : SPEC_MONO_VECTOR where type elem = LargeReal.real = LargeRealVector
  structure VO :> SPEC_MONO_VECTOR where type elem = LargeReal.real = LargeRealVector
  val () = T.check ("LargeRealVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("LargeRealVector:MONO_VECTOR/elem-is-LargeReal.real", fn () => eq (VE.sub (VE.fromList [x 7], 0) : LargeReal.real, x 7))
  val () = T.check ("LargeRealVector:MONO_VECTOR/vector-is-LargeRealVector.vector",
                    fn () => LargeRealVector.length (V.fromList [] : LargeRealVector.vector) = 0 andalso V.length (LargeRealVector.fromList [] : V.vector) = 0)
  val () = T.check ("LargeRealVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = LargeRealArray
  structure AE : SPEC_MONO_ARRAY where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray
  structure AO :> SPEC_MONO_ARRAY where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray
  val () = T.check ("LargeRealArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("LargeRealArray:MONO_ARRAY/elem-is-LargeReal.real", fn () => eq (AE.sub (AE.array (1, x 7), 0) : LargeReal.real, x 7))
  val () = T.check ("LargeRealArray:MONO_ARRAY/vector-is-LargeRealVector.vector", fn () => LargeRealVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("LargeRealArray:MONO_ARRAY/array-is-LargeRealArray.array",
                    fn () => LargeRealArray.length (A.fromList [] : LargeRealArray.array) = 0 andalso A.length (LargeRealArray.fromList [] : A.array) = 0)
  val () = T.check ("LargeRealArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("LargeRealArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = LargeRealVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealVectorSlice
  val () = T.check ("LargeRealVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("LargeRealVectorSlice:MONO_VECTOR_SLICE/vector-is-LargeRealVector.vector",
                    fn () => LargeRealVector.length (VSE.vector (VSE.full (LargeRealVector.tabulate (3, x)))) = 3)
  val () = T.check ("LargeRealVectorSlice:MONO_VECTOR_SLICE/elem-is-LargeReal.real",
                    fn () => eq (VSE.sub (VSE.full (LargeRealVector.tabulate (3, x)), 2) : LargeReal.real, x 2))
  val () = T.check ("LargeRealVectorSlice:MONO_VECTOR_SLICE/slice-is-LargeRealVectorSlice.slice",
                    fn () => LargeRealVectorSlice.length (VS.full (LargeRealVector.fromList []) : LargeRealVectorSlice.slice) = 0
                             andalso VS.length (LargeRealVectorSlice.full (LargeRealVector.fromList []) : VS.slice) = 0)
  val () = T.check ("LargeRealVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (LargeRealVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = LargeRealArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = LargeRealVector.vector where type vector_slice = LargeRealVectorSlice.slice where type array = LargeRealArray.array where type elem = LargeReal.real = LargeRealArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = LargeRealVector.vector where type vector_slice = LargeRealVectorSlice.slice where type array = LargeRealArray.array where type elem = LargeReal.real = LargeRealArraySlice
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/array-is-LargeRealArray.array",
                    fn () => LargeRealArray.length (#1 (ASE.base (ASE.full (LargeRealArray.array (3, x 0))))) = 3)
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/vector-is-LargeRealVector.vector",
                    fn () => LargeRealVector.length (ASE.vector (ASE.full (LargeRealArray.array (3, x 0)))) = 3)
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/vector_slice-is-LargeRealVectorSlice.slice",
                    fn () => let val a = LargeRealArray.array (3, x 0)
                             in ASE.copyVec {src = LargeRealVectorSlice.full (LargeRealVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (LargeRealArray.sub (a, 2), x 9) end)
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/elem-is-LargeReal.real", fn () => eq (ASE.sub (ASE.full (LargeRealArray.array (1, x 7)), 0) : LargeReal.real, x 7))
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/slice-is-LargeRealArraySlice.slice",
                    fn () => LargeRealArraySlice.length (AS.full (LargeRealArray.fromList []) : LargeRealArraySlice.slice) = 0
                             andalso AS.length (LargeRealArraySlice.full (LargeRealArray.fromList []) : AS.slice) = 0)
  val () = T.check ("LargeRealArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (LargeRealArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = LargeRealArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray2
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/elem-is-LargeReal.real", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : LargeReal.real, x 7))
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/vector-is-LargeRealVector.vector", fn () => LargeRealVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/array-is-LargeRealArray2.array",
                    fn () => LargeRealArray2.nRows (A2.array (2, 3, x 0) : LargeRealArray2.array) = 2
                             andalso A2.nCols (LargeRealArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/region-is-LargeRealArray2.region",
                    fn () => let val a = LargeRealArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : LargeRealArray2.region) = 3 end)
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso LargeRealArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("LargeRealArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
