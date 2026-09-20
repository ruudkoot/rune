(* requires: Int16Vector Int16Array Int16 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Int16Vector, Int16Array, Int16VectorSlice, Int16ArraySlice and
   Int16Array2 match their signatures, with the constraints of the
   specification:
     structure Int16Vector :> MONO_VECTOR where type elem = Int16.int
     structure Int16Array :> MONO_ARRAY where type vector = Int16Vector.vector
       where type elem = Int16.int
     structure Int16VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Int16Vector.vector where type elem = Int16.int
     structure Int16ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Int16Vector.vector
       where type vector_slice = Int16VectorSlice.slice
       where type array = Int16Array.array where type elem = Int16.int
     structure Int16Array2 :> MONO_ARRAY2 where type vector = Int16Vector.vector
       where type elem = Int16.int
   and each can be implemented opaquely. *)
structure TestMonoInt16Sig =
struct
  fun x n = Int16.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Int16Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Int16.int = Int16Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Int16.int = Int16Vector
  val () = T.check ("Int16Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Int16Vector:MONO_VECTOR/elem-is-Int16.int", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Int16.int, x 7))
  val () = T.check ("Int16Vector:MONO_VECTOR/vector-is-Int16Vector.vector",
                    fn () => Int16Vector.length (V.fromList [] : Int16Vector.vector) = 0 andalso V.length (Int16Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Int16Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Int16Array
  structure AE : SPEC_MONO_ARRAY where type vector = Int16Vector.vector where type elem = Int16.int = Int16Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Int16Vector.vector where type elem = Int16.int = Int16Array
  val () = T.check ("Int16Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Int16Array:MONO_ARRAY/elem-is-Int16.int", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Int16.int, x 7))
  val () = T.check ("Int16Array:MONO_ARRAY/vector-is-Int16Vector.vector", fn () => Int16Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Int16Array:MONO_ARRAY/array-is-Int16Array.array",
                    fn () => Int16Array.length (A.fromList [] : Int16Array.array) = 0 andalso A.length (Int16Array.fromList [] : A.array) = 0)
  val () = T.check ("Int16Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Int16Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Int16VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int = Int16VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int = Int16VectorSlice
  val () = T.check ("Int16VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Int16VectorSlice:MONO_VECTOR_SLICE/vector-is-Int16Vector.vector",
                    fn () => Int16Vector.length (VSE.vector (VSE.full (Int16Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Int16VectorSlice:MONO_VECTOR_SLICE/elem-is-Int16.int",
                    fn () => eq (VSE.sub (VSE.full (Int16Vector.tabulate (3, x)), 2) : Int16.int, x 2))
  val () = T.check ("Int16VectorSlice:MONO_VECTOR_SLICE/slice-is-Int16VectorSlice.slice",
                    fn () => Int16VectorSlice.length (VS.full (Int16Vector.fromList []) : Int16VectorSlice.slice) = 0
                             andalso VS.length (Int16VectorSlice.full (Int16Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Int16VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Int16Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Int16ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Int16Vector.vector where type vector_slice = Int16VectorSlice.slice where type array = Int16Array.array where type elem = Int16.int = Int16ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Int16Vector.vector where type vector_slice = Int16VectorSlice.slice where type array = Int16Array.array where type elem = Int16.int = Int16ArraySlice
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/array-is-Int16Array.array",
                    fn () => Int16Array.length (#1 (ASE.base (ASE.full (Int16Array.array (3, x 0))))) = 3)
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/vector-is-Int16Vector.vector",
                    fn () => Int16Vector.length (ASE.vector (ASE.full (Int16Array.array (3, x 0)))) = 3)
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Int16VectorSlice.slice",
                    fn () => let val a = Int16Array.array (3, x 0)
                             in ASE.copyVec {src = Int16VectorSlice.full (Int16Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Int16Array.sub (a, 2), x 9) end)
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/elem-is-Int16.int", fn () => eq (ASE.sub (ASE.full (Int16Array.array (1, x 7)), 0) : Int16.int, x 7))
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/slice-is-Int16ArraySlice.slice",
                    fn () => Int16ArraySlice.length (AS.full (Int16Array.fromList []) : Int16ArraySlice.slice) = 0
                             andalso AS.length (Int16ArraySlice.full (Int16Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Int16ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Int16Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Int16Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int = Int16Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int = Int16Array2
  val () = T.check ("Int16Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Int16Array2:MONO_ARRAY2/elem-is-Int16.int", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Int16.int, x 7))
  val () = T.check ("Int16Array2:MONO_ARRAY2/vector-is-Int16Vector.vector", fn () => Int16Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Int16Array2:MONO_ARRAY2/array-is-Int16Array2.array",
                    fn () => Int16Array2.nRows (A2.array (2, 3, x 0) : Int16Array2.array) = 2
                             andalso A2.nCols (Int16Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Int16Array2:MONO_ARRAY2/region-is-Int16Array2.region",
                    fn () => let val a = Int16Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Int16Array2.region) = 3 end)
  val () = T.check ("Int16Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Int16Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Int16Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Int16Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
