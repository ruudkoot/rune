(* requires: Word16Vector Word16Array Word16 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Word16Vector, Word16Array, Word16VectorSlice, Word16ArraySlice and
   Word16Array2 match their signatures, with the constraints of the
   specification:
     structure Word16Vector :> MONO_VECTOR where type elem = Word16.word
     structure Word16Array :> MONO_ARRAY where type vector = Word16Vector.vector
       where type elem = Word16.word
     structure Word16VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Word16Vector.vector where type elem = Word16.word
     structure Word16ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Word16Vector.vector
       where type vector_slice = Word16VectorSlice.slice
       where type array = Word16Array.array where type elem = Word16.word
     structure Word16Array2 :> MONO_ARRAY2 where type vector = Word16Vector.vector
       where type elem = Word16.word
   and each can be implemented opaquely. *)
structure TestMonoWord16Sig =
struct
  fun x n = Word16.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Word16Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Word16.word = Word16Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Word16.word = Word16Vector
  val () = T.check ("Word16Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Word16Vector:MONO_VECTOR/elem-is-Word16.word", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Word16.word, x 7))
  val () = T.check ("Word16Vector:MONO_VECTOR/vector-is-Word16Vector.vector",
                    fn () => Word16Vector.length (V.fromList [] : Word16Vector.vector) = 0 andalso V.length (Word16Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Word16Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Word16Array
  structure AE : SPEC_MONO_ARRAY where type vector = Word16Vector.vector where type elem = Word16.word = Word16Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Word16Vector.vector where type elem = Word16.word = Word16Array
  val () = T.check ("Word16Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Word16Array:MONO_ARRAY/elem-is-Word16.word", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Word16.word, x 7))
  val () = T.check ("Word16Array:MONO_ARRAY/vector-is-Word16Vector.vector", fn () => Word16Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Word16Array:MONO_ARRAY/array-is-Word16Array.array",
                    fn () => Word16Array.length (A.fromList [] : Word16Array.array) = 0 andalso A.length (Word16Array.fromList [] : A.array) = 0)
  val () = T.check ("Word16Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Word16Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Word16VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word = Word16VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word = Word16VectorSlice
  val () = T.check ("Word16VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Word16VectorSlice:MONO_VECTOR_SLICE/vector-is-Word16Vector.vector",
                    fn () => Word16Vector.length (VSE.vector (VSE.full (Word16Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Word16VectorSlice:MONO_VECTOR_SLICE/elem-is-Word16.word",
                    fn () => eq (VSE.sub (VSE.full (Word16Vector.tabulate (3, x)), 2) : Word16.word, x 2))
  val () = T.check ("Word16VectorSlice:MONO_VECTOR_SLICE/slice-is-Word16VectorSlice.slice",
                    fn () => Word16VectorSlice.length (VS.full (Word16Vector.fromList []) : Word16VectorSlice.slice) = 0
                             andalso VS.length (Word16VectorSlice.full (Word16Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Word16VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Word16Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Word16ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word = Word16ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word = Word16ArraySlice
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/array-is-Word16Array.array",
                    fn () => Word16Array.length (#1 (ASE.base (ASE.full (Word16Array.array (3, x 0))))) = 3)
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/vector-is-Word16Vector.vector",
                    fn () => Word16Vector.length (ASE.vector (ASE.full (Word16Array.array (3, x 0)))) = 3)
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Word16VectorSlice.slice",
                    fn () => let val a = Word16Array.array (3, x 0)
                             in ASE.copyVec {src = Word16VectorSlice.full (Word16Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Word16Array.sub (a, 2), x 9) end)
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/elem-is-Word16.word", fn () => eq (ASE.sub (ASE.full (Word16Array.array (1, x 7)), 0) : Word16.word, x 7))
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/slice-is-Word16ArraySlice.slice",
                    fn () => Word16ArraySlice.length (AS.full (Word16Array.fromList []) : Word16ArraySlice.slice) = 0
                             andalso AS.length (Word16ArraySlice.full (Word16Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Word16ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Word16Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Word16Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word = Word16Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word = Word16Array2
  val () = T.check ("Word16Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Word16Array2:MONO_ARRAY2/elem-is-Word16.word", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Word16.word, x 7))
  val () = T.check ("Word16Array2:MONO_ARRAY2/vector-is-Word16Vector.vector", fn () => Word16Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Word16Array2:MONO_ARRAY2/array-is-Word16Array2.array",
                    fn () => Word16Array2.nRows (A2.array (2, 3, x 0) : Word16Array2.array) = 2
                             andalso A2.nCols (Word16Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Word16Array2:MONO_ARRAY2/region-is-Word16Array2.region",
                    fn () => let val a = Word16Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Word16Array2.region) = 3 end)
  val () = T.check ("Word16Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Word16Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Word16Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Word16Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
