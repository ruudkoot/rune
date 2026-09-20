(* requires: Real64Vector Real64Array Real64 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Real64Vector, Real64Array, Real64VectorSlice, Real64ArraySlice and
   Real64Array2 match their signatures, with the constraints of the
   specification:
     structure Real64Vector :> MONO_VECTOR where type elem = Real64.real
     structure Real64Array :> MONO_ARRAY where type vector = Real64Vector.vector
       where type elem = Real64.real
     structure Real64VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Real64Vector.vector where type elem = Real64.real
     structure Real64ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Real64Vector.vector
       where type vector_slice = Real64VectorSlice.slice
       where type array = Real64Array.array where type elem = Real64.real
     structure Real64Array2 :> MONO_ARRAY2 where type vector = Real64Vector.vector
       where type elem = Real64.real
   and each can be implemented opaquely.
   Real64 is Real in Rune, and Real64Vector is RealVector; on a host they are
   structures of their own, so they are tested as such. *)
structure TestMonoReal64Sig =
struct
  fun x n = Real64.fromInt n
  val eq = Real64.==

  structure V : SPEC_MONO_VECTOR = Real64Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Real64.real = Real64Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Real64.real = Real64Vector
  val () = T.check ("Real64Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Real64Vector:MONO_VECTOR/elem-is-Real64.real", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Real64.real, x 7))
  val () = T.check ("Real64Vector:MONO_VECTOR/vector-is-Real64Vector.vector",
                    fn () => Real64Vector.length (V.fromList [] : Real64Vector.vector) = 0 andalso V.length (Real64Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Real64Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Real64Array
  structure AE : SPEC_MONO_ARRAY where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array
  val () = T.check ("Real64Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Real64Array:MONO_ARRAY/elem-is-Real64.real", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Real64.real, x 7))
  val () = T.check ("Real64Array:MONO_ARRAY/vector-is-Real64Vector.vector", fn () => Real64Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Real64Array:MONO_ARRAY/array-is-Real64Array.array",
                    fn () => Real64Array.length (A.fromList [] : Real64Array.array) = 0 andalso A.length (Real64Array.fromList [] : A.array) = 0)
  val () = T.check ("Real64Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Real64Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Real64VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real = Real64VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real = Real64VectorSlice
  val () = T.check ("Real64VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Real64VectorSlice:MONO_VECTOR_SLICE/vector-is-Real64Vector.vector",
                    fn () => Real64Vector.length (VSE.vector (VSE.full (Real64Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Real64VectorSlice:MONO_VECTOR_SLICE/elem-is-Real64.real",
                    fn () => eq (VSE.sub (VSE.full (Real64Vector.tabulate (3, x)), 2) : Real64.real, x 2))
  val () = T.check ("Real64VectorSlice:MONO_VECTOR_SLICE/slice-is-Real64VectorSlice.slice",
                    fn () => Real64VectorSlice.length (VS.full (Real64Vector.fromList []) : Real64VectorSlice.slice) = 0
                             andalso VS.length (Real64VectorSlice.full (Real64Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Real64VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Real64Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Real64ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Real64Vector.vector where type vector_slice = Real64VectorSlice.slice where type array = Real64Array.array where type elem = Real64.real = Real64ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Real64Vector.vector where type vector_slice = Real64VectorSlice.slice where type array = Real64Array.array where type elem = Real64.real = Real64ArraySlice
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/array-is-Real64Array.array",
                    fn () => Real64Array.length (#1 (ASE.base (ASE.full (Real64Array.array (3, x 0))))) = 3)
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/vector-is-Real64Vector.vector",
                    fn () => Real64Vector.length (ASE.vector (ASE.full (Real64Array.array (3, x 0)))) = 3)
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Real64VectorSlice.slice",
                    fn () => let val a = Real64Array.array (3, x 0)
                             in ASE.copyVec {src = Real64VectorSlice.full (Real64Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Real64Array.sub (a, 2), x 9) end)
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/elem-is-Real64.real", fn () => eq (ASE.sub (ASE.full (Real64Array.array (1, x 7)), 0) : Real64.real, x 7))
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/slice-is-Real64ArraySlice.slice",
                    fn () => Real64ArraySlice.length (AS.full (Real64Array.fromList []) : Real64ArraySlice.slice) = 0
                             andalso AS.length (Real64ArraySlice.full (Real64Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Real64ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Real64Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Real64Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Real64Vector.vector where type elem = Real64.real = Real64Array2
  val () = T.check ("Real64Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Real64Array2:MONO_ARRAY2/elem-is-Real64.real", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Real64.real, x 7))
  val () = T.check ("Real64Array2:MONO_ARRAY2/vector-is-Real64Vector.vector", fn () => Real64Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Real64Array2:MONO_ARRAY2/array-is-Real64Array2.array",
                    fn () => Real64Array2.nRows (A2.array (2, 3, x 0) : Real64Array2.array) = 2
                             andalso A2.nCols (Real64Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Real64Array2:MONO_ARRAY2/region-is-Real64Array2.region",
                    fn () => let val a = Real64Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Real64Array2.region) = 3 end)
  val () = T.check ("Real64Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Real64Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Real64Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Real64Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
