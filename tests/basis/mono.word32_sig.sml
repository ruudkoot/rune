(* requires: Word32Vector Word32Array Word32 *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* Word32Vector, Word32Array, Word32VectorSlice, Word32ArraySlice and
   Word32Array2 match their signatures, with the constraints of the
   specification:
     structure Word32Vector :> MONO_VECTOR where type elem = Word32.word
     structure Word32Array :> MONO_ARRAY where type vector = Word32Vector.vector
       where type elem = Word32.word
     structure Word32VectorSlice :> MONO_VECTOR_SLICE
       where type vector = Word32Vector.vector where type elem = Word32.word
     structure Word32ArraySlice :> MONO_ARRAY_SLICE
       where type vector = Word32Vector.vector
       where type vector_slice = Word32VectorSlice.slice
       where type array = Word32Array.array where type elem = Word32.word
     structure Word32Array2 :> MONO_ARRAY2 where type vector = Word32Vector.vector
       where type elem = Word32.word
   and each can be implemented opaquely. *)
structure TestMonoWord32Sig =
struct
  fun x n = Word32.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = Word32Vector
  structure VE : SPEC_MONO_VECTOR where type elem = Word32.word = Word32Vector
  structure VO :> SPEC_MONO_VECTOR where type elem = Word32.word = Word32Vector
  val () = T.check ("Word32Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Word32Vector:MONO_VECTOR/elem-is-Word32.word", fn () => eq (VE.sub (VE.fromList [x 7], 0) : Word32.word, x 7))
  val () = T.check ("Word32Vector:MONO_VECTOR/vector-is-Word32Vector.vector",
                    fn () => Word32Vector.length (V.fromList [] : Word32Vector.vector) = 0 andalso V.length (Word32Vector.fromList [] : V.vector) = 0)
  val () = T.check ("Word32Vector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = Word32Array
  structure AE : SPEC_MONO_ARRAY where type vector = Word32Vector.vector where type elem = Word32.word = Word32Array
  structure AO :> SPEC_MONO_ARRAY where type vector = Word32Vector.vector where type elem = Word32.word = Word32Array
  val () = T.check ("Word32Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Word32Array:MONO_ARRAY/elem-is-Word32.word", fn () => eq (AE.sub (AE.array (1, x 7), 0) : Word32.word, x 7))
  val () = T.check ("Word32Array:MONO_ARRAY/vector-is-Word32Vector.vector", fn () => Word32Vector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("Word32Array:MONO_ARRAY/array-is-Word32Array.array",
                    fn () => Word32Array.length (A.fromList [] : Word32Array.array) = 0 andalso A.length (Word32Array.fromList [] : A.array) = 0)
  val () = T.check ("Word32Array:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("Word32Array:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = Word32VectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word = Word32VectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word = Word32VectorSlice
  val () = T.check ("Word32VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Word32VectorSlice:MONO_VECTOR_SLICE/vector-is-Word32Vector.vector",
                    fn () => Word32Vector.length (VSE.vector (VSE.full (Word32Vector.tabulate (3, x)))) = 3)
  val () = T.check ("Word32VectorSlice:MONO_VECTOR_SLICE/elem-is-Word32.word",
                    fn () => eq (VSE.sub (VSE.full (Word32Vector.tabulate (3, x)), 2) : Word32.word, x 2))
  val () = T.check ("Word32VectorSlice:MONO_VECTOR_SLICE/slice-is-Word32VectorSlice.slice",
                    fn () => Word32VectorSlice.length (VS.full (Word32Vector.fromList []) : Word32VectorSlice.slice) = 0
                             andalso VS.length (Word32VectorSlice.full (Word32Vector.fromList []) : VS.slice) = 0)
  val () = T.check ("Word32VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (Word32Vector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = Word32ArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = Word32Vector.vector where type vector_slice = Word32VectorSlice.slice where type array = Word32Array.array where type elem = Word32.word = Word32ArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = Word32Vector.vector where type vector_slice = Word32VectorSlice.slice where type array = Word32Array.array where type elem = Word32.word = Word32ArraySlice
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/array-is-Word32Array.array",
                    fn () => Word32Array.length (#1 (ASE.base (ASE.full (Word32Array.array (3, x 0))))) = 3)
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/vector-is-Word32Vector.vector",
                    fn () => Word32Vector.length (ASE.vector (ASE.full (Word32Array.array (3, x 0)))) = 3)
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Word32VectorSlice.slice",
                    fn () => let val a = Word32Array.array (3, x 0)
                             in ASE.copyVec {src = Word32VectorSlice.full (Word32Vector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (Word32Array.sub (a, 2), x 9) end)
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/elem-is-Word32.word", fn () => eq (ASE.sub (ASE.full (Word32Array.array (1, x 7)), 0) : Word32.word, x 7))
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/slice-is-Word32ArraySlice.slice",
                    fn () => Word32ArraySlice.length (AS.full (Word32Array.fromList []) : Word32ArraySlice.slice) = 0
                             andalso AS.length (Word32ArraySlice.full (Word32Array.fromList []) : AS.slice) = 0)
  val () = T.check ("Word32ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (Word32Array.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = Word32Array2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word = Word32Array2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word = Word32Array2
  val () = T.check ("Word32Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Word32Array2:MONO_ARRAY2/elem-is-Word32.word", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : Word32.word, x 7))
  val () = T.check ("Word32Array2:MONO_ARRAY2/vector-is-Word32Vector.vector", fn () => Word32Vector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("Word32Array2:MONO_ARRAY2/array-is-Word32Array2.array",
                    fn () => Word32Array2.nRows (A2.array (2, 3, x 0) : Word32Array2.array) = 2
                             andalso A2.nCols (Word32Array2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("Word32Array2:MONO_ARRAY2/region-is-Word32Array2.region",
                    fn () => let val a = Word32Array2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Word32Array2.region) = 3 end)
  val () = T.check ("Word32Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso Word32Array2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("Word32Array2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("Word32Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
