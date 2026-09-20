(* requires: RealVector RealArray Real *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* RealVector, RealArray, RealVectorSlice, RealArraySlice and
   RealArray2 match their signatures, with the constraints of the
   specification:
     structure RealVector :> MONO_VECTOR where type elem = real
     structure RealArray :> MONO_ARRAY where type vector = RealVector.vector
       where type elem = real
     structure RealVectorSlice :> MONO_VECTOR_SLICE
       where type vector = RealVector.vector where type elem = real
     structure RealArraySlice :> MONO_ARRAY_SLICE
       where type vector = RealVector.vector
       where type vector_slice = RealVectorSlice.slice
       where type array = RealArray.array where type elem = real
     structure RealArray2 :> MONO_ARRAY2 where type vector = RealVector.vector
       where type elem = real
   and each can be implemented opaquely. *)
structure TestMonoRealSig =
struct
  fun x n = Real.fromInt n
  val eq = Real.==

  structure V : SPEC_MONO_VECTOR = RealVector
  structure VE : SPEC_MONO_VECTOR where type elem = real = RealVector
  structure VO :> SPEC_MONO_VECTOR where type elem = real = RealVector
  val () = T.check ("RealVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("RealVector:MONO_VECTOR/elem-is-real", fn () => eq (VE.sub (VE.fromList [x 7], 0) : real, x 7))
  val () = T.check ("RealVector:MONO_VECTOR/vector-is-RealVector.vector",
                    fn () => RealVector.length (V.fromList [] : RealVector.vector) = 0 andalso V.length (RealVector.fromList [] : V.vector) = 0)
  val () = T.check ("RealVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = RealArray
  structure AE : SPEC_MONO_ARRAY where type vector = RealVector.vector where type elem = real = RealArray
  structure AO :> SPEC_MONO_ARRAY where type vector = RealVector.vector where type elem = real = RealArray
  val () = T.check ("RealArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("RealArray:MONO_ARRAY/elem-is-real", fn () => eq (AE.sub (AE.array (1, x 7), 0) : real, x 7))
  val () = T.check ("RealArray:MONO_ARRAY/vector-is-RealVector.vector", fn () => RealVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("RealArray:MONO_ARRAY/array-is-RealArray.array",
                    fn () => RealArray.length (A.fromList [] : RealArray.array) = 0 andalso A.length (RealArray.fromList [] : A.array) = 0)
  val () = T.check ("RealArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("RealArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = RealVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real = RealVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real = RealVectorSlice
  val () = T.check ("RealVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("RealVectorSlice:MONO_VECTOR_SLICE/vector-is-RealVector.vector",
                    fn () => RealVector.length (VSE.vector (VSE.full (RealVector.tabulate (3, x)))) = 3)
  val () = T.check ("RealVectorSlice:MONO_VECTOR_SLICE/elem-is-real",
                    fn () => eq (VSE.sub (VSE.full (RealVector.tabulate (3, x)), 2) : real, x 2))
  val () = T.check ("RealVectorSlice:MONO_VECTOR_SLICE/slice-is-RealVectorSlice.slice",
                    fn () => RealVectorSlice.length (VS.full (RealVector.fromList []) : RealVectorSlice.slice) = 0
                             andalso VS.length (RealVectorSlice.full (RealVector.fromList []) : VS.slice) = 0)
  val () = T.check ("RealVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (RealVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = RealArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real = RealArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real = RealArraySlice
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/array-is-RealArray.array",
                    fn () => RealArray.length (#1 (ASE.base (ASE.full (RealArray.array (3, x 0))))) = 3)
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/vector-is-RealVector.vector",
                    fn () => RealVector.length (ASE.vector (ASE.full (RealArray.array (3, x 0)))) = 3)
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/vector_slice-is-RealVectorSlice.slice",
                    fn () => let val a = RealArray.array (3, x 0)
                             in ASE.copyVec {src = RealVectorSlice.full (RealVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (RealArray.sub (a, 2), x 9) end)
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/elem-is-real", fn () => eq (ASE.sub (ASE.full (RealArray.array (1, x 7)), 0) : real, x 7))
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/slice-is-RealArraySlice.slice",
                    fn () => RealArraySlice.length (AS.full (RealArray.fromList []) : RealArraySlice.slice) = 0
                             andalso AS.length (RealArraySlice.full (RealArray.fromList []) : AS.slice) = 0)
  val () = T.check ("RealArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (RealArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = RealArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = RealVector.vector where type elem = real = RealArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = RealVector.vector where type elem = real = RealArray2
  val () = T.check ("RealArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("RealArray2:MONO_ARRAY2/elem-is-real", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : real, x 7))
  val () = T.check ("RealArray2:MONO_ARRAY2/vector-is-RealVector.vector", fn () => RealVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("RealArray2:MONO_ARRAY2/array-is-RealArray2.array",
                    fn () => RealArray2.nRows (A2.array (2, 3, x 0) : RealArray2.array) = 2
                             andalso A2.nCols (RealArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("RealArray2:MONO_ARRAY2/region-is-RealArray2.region",
                    fn () => let val a = RealArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : RealArray2.region) = 3 end)
  val () = T.check ("RealArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso RealArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("RealArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("RealArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
