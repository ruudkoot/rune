(* requires: Int64Vector Int64Array Int64 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Int64Vector, Int64Array, Int64VectorSlice, Int64ArraySlice and
   Int64Array2 match their signatures, with the constraints of the
   specification:
     structure Int64Vector :> MONO_VECTOR where type elem = Int64.int
     structure Int64Array :> MONO_ARRAY where type vector = Int64Vector.vector
       where type elem = Int64.int
     structure Int64VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Int64Vector.vector where type elem = Int64.int
     structure Int64ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Int64Vector.vector
       where type vector_slice = Int64VectorSlice.slice
       where type array = Int64Array.array where type elem = Int64.int
     structure Int64Array2 :> MONO_ARRAY2 where type vector = Int64Vector.vector
       where type elem = Int64.int
   and each can be implemented opaquely.
   Int64 is Int in Rune, and Int64Vector is IntVector; on a host they are
   structures of their own, so they are tested as such. *)
structure TestMonoInt64Sig =
struct
  fun x n = Int64.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Int64Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Int64.int = Int64Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Int64.int = Int64Vector
  val () = T.check ("Int64Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Int64Vector:MONO_VECTOR/elem-is-Int64.int", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Int64.int, x 7))
  val () = T.check ("Int64Vector:MONO_VECTOR/vector-is-Int64Vector.vector",
                    fn () => Int64Vector.length (V.fromList [] : Int64Vector.vector) = 0 andalso V.length (Int64Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Int64Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Int64Array
  structure AE : SPEC_MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array
  val () = T.check ("Int64Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Int64Array:MONO_ARRAY/elem-is-Int64.int", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Int64.int, x 7))
  val () = T.check ("Int64Array:MONO_ARRAY/vector-is-Int64Vector.vector", fn () => Int64Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Int64Array:MONO_ARRAY/array-is-Int64Array.array",
                    fn () => Int64Array.length (A.fromList [] : Int64Array.array) = 0 andalso A.length (Int64Array.fromList [] : A.array) = 0)
  val () = T.check ("Int64Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Int64Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Int64VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int = Int64VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int = Int64VectorSlice
  val () = T.check ("Int64VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Int64VectorSlice:MONO_VECTOR_SLICE/vector-is-Int64Vector.vector",
                    fn () => Int64Vector.length (VSE.vector (VSE.full (Int64Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Int64VectorSlice:MONO_VECTOR_SLICE/elem-is-Int64.int",
                    fn () => eq (VSE.sub (VSE.full (Int64Vector.tabulate (3, x)), 2) : Int64.int, x 2))
  val () = T.check ("Int64VectorSlice:MONO_VECTOR_SLICE/slice-is-Int64VectorSlice.slice",
                    fn () => Int64VectorSlice.length (VS.full (Int64Vector.fromList []) : Int64VectorSlice.slice) = 0
                             andalso VS.length (Int64VectorSlice.full (Int64Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Int64VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Int64Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Int64ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int = Int64ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int = Int64ArraySlice
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/array-is-Int64Array.array",
                    fn () => Int64Array.length (#1 (ASE.base (ASE.full (Int64Array.array (3, x 0))))) = 3)
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/vector-is-Int64Vector.vector",
                    fn () => Int64Vector.length (ASE.vector (ASE.full (Int64Array.array (3, x 0)))) = 3)
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Int64VectorSlice.slice",
                    fn () => let val a = Int64Array.array (3, x 0)
                             in ASE.copyVec {src = Int64VectorSlice.full (Int64Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Int64Array.sub (a, 2), x 9) end)
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/elem-is-Int64.int", fn () => eq (ASE.sub (ASE.full (Int64Array.array (1, x 7)), 0) : Int64.int, x 7))
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/slice-is-Int64ArraySlice.slice",
                    fn () => Int64ArraySlice.length (AS.full (Int64Array.fromList []) : Int64ArraySlice.slice) = 0
                             andalso AS.length (Int64ArraySlice.full (Int64Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Int64ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Int64Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Int64Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int = Int64Array2
  val () = T.check ("Int64Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Int64Array2:MONO_ARRAY2/elem-is-Int64.int", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Int64.int, x 7))
  val () = T.check ("Int64Array2:MONO_ARRAY2/vector-is-Int64Vector.vector", fn () => Int64Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Int64Array2:MONO_ARRAY2/array-is-Int64Array2.array",
                    fn () => Int64Array2.nRows (A2.array (2, 3, x 0) : Int64Array2.array) = 2
                             andalso A2.nCols (Int64Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Int64Array2:MONO_ARRAY2/region-is-Int64Array2.region",
                    fn () => let val a = Int64Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Int64Array2.region) = 3 end)
  val () = T.check ("Int64Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Int64Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Int64Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Int64Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
