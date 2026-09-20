(* requires: Word64Vector Word64Array Word64 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Word64Vector, Word64Array, Word64VectorSlice, Word64ArraySlice and
   Word64Array2 match their signatures, with the constraints of the
   specification:
     structure Word64Vector :> MONO_VECTOR where type elem = Word64.word
     structure Word64Array :> MONO_ARRAY where type vector = Word64Vector.vector
       where type elem = Word64.word
     structure Word64VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Word64Vector.vector where type elem = Word64.word
     structure Word64ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Word64Vector.vector
       where type vector_slice = Word64VectorSlice.slice
       where type array = Word64Array.array where type elem = Word64.word
     structure Word64Array2 :> MONO_ARRAY2 where type vector = Word64Vector.vector
       where type elem = Word64.word
   and each can be implemented opaquely.
   Word64 is Word in Rune, and Word64Vector is WordVector; on a host they are
   structures of their own, so they are tested as such. *)
structure TestMonoWord64Sig =
struct
  fun x n = Word64.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Word64Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Word64.word = Word64Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Word64.word = Word64Vector
  val () = T.check ("Word64Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Word64Vector:MONO_VECTOR/elem-is-Word64.word", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Word64.word, x 7))
  val () = T.check ("Word64Vector:MONO_VECTOR/vector-is-Word64Vector.vector",
                    fn () => Word64Vector.length (V.fromList [] : Word64Vector.vector) = 0 andalso V.length (Word64Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Word64Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Word64Array
  structure AE : SPEC_MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array
  val () = T.check ("Word64Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Word64Array:MONO_ARRAY/elem-is-Word64.word", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Word64.word, x 7))
  val () = T.check ("Word64Array:MONO_ARRAY/vector-is-Word64Vector.vector", fn () => Word64Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Word64Array:MONO_ARRAY/array-is-Word64Array.array",
                    fn () => Word64Array.length (A.fromList [] : Word64Array.array) = 0 andalso A.length (Word64Array.fromList [] : A.array) = 0)
  val () = T.check ("Word64Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Word64Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Word64VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word = Word64VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word = Word64VectorSlice
  val () = T.check ("Word64VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Word64VectorSlice:MONO_VECTOR_SLICE/vector-is-Word64Vector.vector",
                    fn () => Word64Vector.length (VSE.vector (VSE.full (Word64Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Word64VectorSlice:MONO_VECTOR_SLICE/elem-is-Word64.word",
                    fn () => eq (VSE.sub (VSE.full (Word64Vector.tabulate (3, x)), 2) : Word64.word, x 2))
  val () = T.check ("Word64VectorSlice:MONO_VECTOR_SLICE/slice-is-Word64VectorSlice.slice",
                    fn () => Word64VectorSlice.length (VS.full (Word64Vector.fromList []) : Word64VectorSlice.slice) = 0
                             andalso VS.length (Word64VectorSlice.full (Word64Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Word64VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Word64Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Word64ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word = Word64ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word = Word64ArraySlice
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/array-is-Word64Array.array",
                    fn () => Word64Array.length (#1 (ASE.base (ASE.full (Word64Array.array (3, x 0))))) = 3)
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/vector-is-Word64Vector.vector",
                    fn () => Word64Vector.length (ASE.vector (ASE.full (Word64Array.array (3, x 0)))) = 3)
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Word64VectorSlice.slice",
                    fn () => let val a = Word64Array.array (3, x 0)
                             in ASE.copyVec {src = Word64VectorSlice.full (Word64Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Word64Array.sub (a, 2), x 9) end)
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/elem-is-Word64.word", fn () => eq (ASE.sub (ASE.full (Word64Array.array (1, x 7)), 0) : Word64.word, x 7))
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/slice-is-Word64ArraySlice.slice",
                    fn () => Word64ArraySlice.length (AS.full (Word64Array.fromList []) : Word64ArraySlice.slice) = 0
                             andalso AS.length (Word64ArraySlice.full (Word64Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Word64ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Word64Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Word64Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word = Word64Array2
  val () = T.check ("Word64Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Word64Array2:MONO_ARRAY2/elem-is-Word64.word", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Word64.word, x 7))
  val () = T.check ("Word64Array2:MONO_ARRAY2/vector-is-Word64Vector.vector", fn () => Word64Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Word64Array2:MONO_ARRAY2/array-is-Word64Array2.array",
                    fn () => Word64Array2.nRows (A2.array (2, 3, x 0) : Word64Array2.array) = 2
                             andalso A2.nCols (Word64Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Word64Array2:MONO_ARRAY2/region-is-Word64Array2.region",
                    fn () => let val a = Word64Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Word64Array2.region) = 3 end)
  val () = T.check ("Word64Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Word64Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Word64Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Word64Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
