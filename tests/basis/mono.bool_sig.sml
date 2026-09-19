(* requires: BoolVector BoolArray *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* BoolVector, BoolArray, BoolVectorSlice, BoolArraySlice and BoolArray2 match
   their signatures, with the constraints of the specification:
     structure BoolVector :> MONO_VECTOR where type elem = bool
     structure BoolArray :> MONO_ARRAY where type vector = BoolVector.vector
       where type elem = bool
     structure BoolVectorSlice :> MONO_VECTOR_SLICE
       where type vector = BoolVector.vector where type elem = bool
     structure BoolArraySlice :> MONO_ARRAY_SLICE
       where type vector = BoolVector.vector
       where type vector_slice = BoolVectorSlice.slice
       where type array = BoolArray.array where type elem = bool
     structure BoolArray2 :> MONO_ARRAY2 where type vector = BoolVector.vector
       where type elem = bool
   and each can be implemented opaquely. *)
structure TestMonoBoolSig =
struct
  structure V : SPEC_MONO_VECTOR = BoolVector
  structure VE : SPEC_MONO_VECTOR where type elem = bool = BoolVector
  structure VO :> SPEC_MONO_VECTOR where type elem = bool = BoolVector
  val () = T.check ("BoolVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("BoolVector:MONO_VECTOR/elem-is-bool", fn () => (VE.sub (VE.fromList [false, true], 1) : bool))
  val () = T.check ("BoolVector:MONO_VECTOR/vector-is-BoolVector.vector",
                    fn () => BoolVector.length (V.fromList [] : BoolVector.vector) = 0 andalso V.length (BoolVector.fromList [] : V.vector) = 0)
  val () = T.check ("BoolVector:MONO_VECTOR/opaque-vector", fn () => VO.sub (VO.tabulate (3, fn i => i = 2), 2))

  structure A : SPEC_MONO_ARRAY = BoolArray
  structure AE : SPEC_MONO_ARRAY where type vector = BoolVector.vector where type elem = bool = BoolArray
  structure AO :> SPEC_MONO_ARRAY where type vector = BoolVector.vector where type elem = bool = BoolArray
  val () = T.check ("BoolArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("BoolArray:MONO_ARRAY/elem-is-bool", fn () => (AE.sub (AE.array (1, true), 0) : bool))
  val () = T.check ("BoolArray:MONO_ARRAY/vector-is-BoolVector.vector", fn () => BoolVector.length (AE.vector (AE.array (3, true))) = 3)
  val () = T.check ("BoolArray:MONO_ARRAY/array-is-BoolArray.array",
                    fn () => BoolArray.length (A.fromList [] : BoolArray.array) = 0 andalso A.length (BoolArray.fromList [] : A.array) = 0)
  val () = T.check ("BoolArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("BoolArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, fn i => i = 2) in AO.sub (a, 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = BoolVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool = BoolVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool = BoolVectorSlice
  val () = T.check ("BoolVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("BoolVectorSlice:MONO_VECTOR_SLICE/vector-is-BoolVector.vector",
                    fn () => BoolVector.length (VSE.vector (VSE.full (BoolVector.tabulate (3, fn _ => true)))) = 3)
  val () = T.check ("BoolVectorSlice:MONO_VECTOR_SLICE/elem-is-bool",
                    fn () => (VSE.sub (VSE.full (BoolVector.tabulate (3, fn i => i = 2)), 2) : bool))
  val () = T.check ("BoolVectorSlice:MONO_VECTOR_SLICE/slice-is-BoolVectorSlice.slice",
                    fn () => BoolVectorSlice.length (VS.full (BoolVector.fromList []) : BoolVectorSlice.slice) = 0
                             andalso VS.length (BoolVectorSlice.full (BoolVector.fromList []) : VS.slice) = 0)
  val () = T.check ("BoolVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => VSO.sub (VSO.slice (BoolVector.tabulate (5, fn i => i = 3), 2, NONE), 1))

  structure AS : SPEC_MONO_ARRAY_SLICE = BoolArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool = BoolArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool = BoolArraySlice
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/array-is-BoolArray.array",
                    fn () => BoolArray.length (#1 (ASE.base (ASE.full (BoolArray.array (3, true))))) = 3)
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/vector-is-BoolVector.vector",
                    fn () => BoolVector.length (ASE.vector (ASE.full (BoolArray.array (3, true)))) = 3)
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/vector_slice-is-BoolVectorSlice.slice",
                    fn () => let val a = BoolArray.array (3, false)
                             in ASE.copyVec {src = BoolVectorSlice.full (BoolVector.tabulate (2, fn _ => true)), dst = a, di = 1};
                                BoolArray.sub (a, 2) end)
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/elem-is-bool", fn () => (ASE.sub (ASE.full (BoolArray.array (1, true)), 0) : bool))
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/slice-is-BoolArraySlice.slice",
                    fn () => BoolArraySlice.length (AS.full (BoolArray.fromList []) : BoolArraySlice.slice) = 0
                             andalso AS.length (BoolArraySlice.full (BoolArray.fromList []) : AS.slice) = 0)
  val () = T.check ("BoolArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => ASO.sub (ASO.slice (BoolArray.tabulate (5, fn i => i = 3), 2, NONE), 1))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = BoolArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool = BoolArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool = BoolArray2
  val () = T.check ("BoolArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("BoolArray2:MONO_ARRAY2/elem-is-bool", fn () => (A2E.sub (A2E.array (1, 1, true), 0, 0) : bool))
  val () = T.check ("BoolArray2:MONO_ARRAY2/vector-is-BoolVector.vector", fn () => BoolVector.length (A2E.row (A2E.array (2, 3, true), 1)) = 3)
  val () = T.check ("BoolArray2:MONO_ARRAY2/array-is-BoolArray2.array",
                    fn () => BoolArray2.nRows (A2.array (2, 3, true) : BoolArray2.array) = 2
                             andalso A2.nCols (BoolArray2.array (2, 3, true) : A2.array) = 3)
  val () = T.check ("BoolArray2:MONO_ARRAY2/region-is-BoolArray2.region",
                    fn () => let val a = BoolArray2.array (2, 3, true)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : BoolArray2.region) = 3 end)
  val () = T.check ("BoolArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso BoolArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("BoolArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, true) in a = a end)
  val () = T.check ("BoolArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => i = 1 andalso j = 0) in A2O.sub (a, 1, 0) andalso a = a end)
  (*>> array2 *)
end
