(* requires: Int32Vector Int32Array Int32 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Int32Vector, Int32Array, Int32VectorSlice, Int32ArraySlice and
   Int32Array2 match their signatures, with the constraints of the
   specification:
     structure Int32Vector :> MONO_VECTOR where type elem = Int32.int
     structure Int32Array :> MONO_ARRAY where type vector = Int32Vector.vector
       where type elem = Int32.int
     structure Int32VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Int32Vector.vector where type elem = Int32.int
     structure Int32ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Int32Vector.vector
       where type vector_slice = Int32VectorSlice.slice
       where type array = Int32Array.array where type elem = Int32.int
     structure Int32Array2 :> MONO_ARRAY2 where type vector = Int32Vector.vector
       where type elem = Int32.int
   and each can be implemented opaquely. *)
structure TestMonoInt32Sig =
struct
  fun x n = Int32.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Int32Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Int32.int = Int32Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Int32.int = Int32Vector
  val () = T.check ("Int32Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Int32Vector:MONO_VECTOR/elem-is-Int32.int", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Int32.int, x 7))
  val () = T.check ("Int32Vector:MONO_VECTOR/vector-is-Int32Vector.vector",
                    fn () => Int32Vector.length (V.fromList [] : Int32Vector.vector) = 0 andalso V.length (Int32Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Int32Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Int32Array
  structure AE : SPEC_MONO_ARRAY where type vector = Int32Vector.vector where type elem = Int32.int = Int32Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Int32Vector.vector where type elem = Int32.int = Int32Array
  val () = T.check ("Int32Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Int32Array:MONO_ARRAY/elem-is-Int32.int", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Int32.int, x 7))
  val () = T.check ("Int32Array:MONO_ARRAY/vector-is-Int32Vector.vector", fn () => Int32Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Int32Array:MONO_ARRAY/array-is-Int32Array.array",
                    fn () => Int32Array.length (A.fromList [] : Int32Array.array) = 0 andalso A.length (Int32Array.fromList [] : A.array) = 0)
  val () = T.check ("Int32Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Int32Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Int32VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int = Int32VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int = Int32VectorSlice
  val () = T.check ("Int32VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Int32VectorSlice:MONO_VECTOR_SLICE/vector-is-Int32Vector.vector",
                    fn () => Int32Vector.length (VSE.vector (VSE.full (Int32Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Int32VectorSlice:MONO_VECTOR_SLICE/elem-is-Int32.int",
                    fn () => eq (VSE.sub (VSE.full (Int32Vector.tabulate (3, x)), 2) : Int32.int, x 2))
  val () = T.check ("Int32VectorSlice:MONO_VECTOR_SLICE/slice-is-Int32VectorSlice.slice",
                    fn () => Int32VectorSlice.length (VS.full (Int32Vector.fromList []) : Int32VectorSlice.slice) = 0
                             andalso VS.length (Int32VectorSlice.full (Int32Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Int32VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Int32Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Int32ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Int32Vector.vector where type vector_slice = Int32VectorSlice.slice where type array = Int32Array.array where type elem = Int32.int = Int32ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Int32Vector.vector where type vector_slice = Int32VectorSlice.slice where type array = Int32Array.array where type elem = Int32.int = Int32ArraySlice
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/array-is-Int32Array.array",
                    fn () => Int32Array.length (#1 (ASE.base (ASE.full (Int32Array.array (3, x 0))))) = 3)
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/vector-is-Int32Vector.vector",
                    fn () => Int32Vector.length (ASE.vector (ASE.full (Int32Array.array (3, x 0)))) = 3)
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Int32VectorSlice.slice",
                    fn () => let val a = Int32Array.array (3, x 0)
                             in ASE.copyVec {src = Int32VectorSlice.full (Int32Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Int32Array.sub (a, 2), x 9) end)
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/elem-is-Int32.int", fn () => eq (ASE.sub (ASE.full (Int32Array.array (1, x 7)), 0) : Int32.int, x 7))
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/slice-is-Int32ArraySlice.slice",
                    fn () => Int32ArraySlice.length (AS.full (Int32Array.fromList []) : Int32ArraySlice.slice) = 0
                             andalso AS.length (Int32ArraySlice.full (Int32Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Int32ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Int32Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Int32Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Int32Vector.vector where type elem = Int32.int = Int32Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Int32Vector.vector where type elem = Int32.int = Int32Array2
  val () = T.check ("Int32Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Int32Array2:MONO_ARRAY2/elem-is-Int32.int", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Int32.int, x 7))
  val () = T.check ("Int32Array2:MONO_ARRAY2/vector-is-Int32Vector.vector", fn () => Int32Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Int32Array2:MONO_ARRAY2/array-is-Int32Array2.array",
                    fn () => Int32Array2.nRows (A2.array (2, 3, x 0) : Int32Array2.array) = 2
                             andalso A2.nCols (Int32Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Int32Array2:MONO_ARRAY2/region-is-Int32Array2.region",
                    fn () => let val a = Int32Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Int32Array2.region) = 3 end)
  val () = T.check ("Int32Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Int32Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Int32Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Int32Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
