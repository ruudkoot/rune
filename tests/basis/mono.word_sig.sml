(* requires: WordVector WordArray Word *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* WordVector, WordArray, WordVectorSlice, WordArraySlice and
   WordArray2 match their signatures, with the constraints of the
   specification:
     structure WordVector :> MONO_VECTOR where type elem = word
     structure WordArray :> MONO_ARRAY where type vector = WordVector.vector
       where type elem = word
     structure WordVectorSlice :> MONO_VECTOR_SLICE
       where type vector = WordVector.vector where type elem = word
     structure WordArraySlice :> MONO_ARRAY_SLICE
       where type vector = WordVector.vector
       where type vector_slice = WordVectorSlice.slice
       where type array = WordArray.array where type elem = word
     structure WordArray2 :> MONO_ARRAY2 where type vector = WordVector.vector
       where type elem = word
   and each can be implemented opaquely. *)
structure TestMonoWordSig =
struct
  fun x n = Word.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = WordVector
  structure VE : SPEC_MONO_VECTOR where type elem = word = WordVector
  structure VO :> SPEC_MONO_VECTOR where type elem = word = WordVector
  val () = T.check ("WordVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("WordVector:MONO_VECTOR/elem-is-word", fn () => eq (VE.sub (VE.fromList [x 7], 0) : word, x 7))
  val () = T.check ("WordVector:MONO_VECTOR/vector-is-WordVector.vector",
                    fn () => WordVector.length (V.fromList [] : WordVector.vector) = 0 andalso V.length (WordVector.fromList [] : V.vector) = 0)
  val () = T.check ("WordVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = WordArray
  structure AE : SPEC_MONO_ARRAY where type vector = WordVector.vector where type elem = word = WordArray
  structure AO :> SPEC_MONO_ARRAY where type vector = WordVector.vector where type elem = word = WordArray
  val () = T.check ("WordArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("WordArray:MONO_ARRAY/elem-is-word", fn () => eq (AE.sub (AE.array (1, x 7), 0) : word, x 7))
  val () = T.check ("WordArray:MONO_ARRAY/vector-is-WordVector.vector", fn () => WordVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("WordArray:MONO_ARRAY/array-is-WordArray.array",
                    fn () => WordArray.length (A.fromList [] : WordArray.array) = 0 andalso A.length (WordArray.fromList [] : A.array) = 0)
  val () = T.check ("WordArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("WordArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = WordVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = WordVector.vector where type elem = word = WordVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = WordVector.vector where type elem = word = WordVectorSlice
  val () = T.check ("WordVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("WordVectorSlice:MONO_VECTOR_SLICE/vector-is-WordVector.vector",
                    fn () => WordVector.length (VSE.vector (VSE.full (WordVector.tabulate (3, x)))) = 3)
  val () = T.check ("WordVectorSlice:MONO_VECTOR_SLICE/elem-is-word",
                    fn () => eq (VSE.sub (VSE.full (WordVector.tabulate (3, x)), 2) : word, x 2))
  val () = T.check ("WordVectorSlice:MONO_VECTOR_SLICE/slice-is-WordVectorSlice.slice",
                    fn () => WordVectorSlice.length (VS.full (WordVector.fromList []) : WordVectorSlice.slice) = 0
                             andalso VS.length (WordVectorSlice.full (WordVector.fromList []) : VS.slice) = 0)
  val () = T.check ("WordVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (WordVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = WordArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = WordVector.vector where type vector_slice = WordVectorSlice.slice where type array = WordArray.array where type elem = word = WordArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = WordVector.vector where type vector_slice = WordVectorSlice.slice where type array = WordArray.array where type elem = word = WordArraySlice
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/array-is-WordArray.array",
                    fn () => WordArray.length (#1 (ASE.base (ASE.full (WordArray.array (3, x 0))))) = 3)
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/vector-is-WordVector.vector",
                    fn () => WordVector.length (ASE.vector (ASE.full (WordArray.array (3, x 0)))) = 3)
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/vector_slice-is-WordVectorSlice.slice",
                    fn () => let val a = WordArray.array (3, x 0)
                             in ASE.copyVec {src = WordVectorSlice.full (WordVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (WordArray.sub (a, 2), x 9) end)
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/elem-is-word", fn () => eq (ASE.sub (ASE.full (WordArray.array (1, x 7)), 0) : word, x 7))
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/slice-is-WordArraySlice.slice",
                    fn () => WordArraySlice.length (AS.full (WordArray.fromList []) : WordArraySlice.slice) = 0
                             andalso AS.length (WordArraySlice.full (WordArray.fromList []) : AS.slice) = 0)
  val () = T.check ("WordArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (WordArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = WordArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = WordVector.vector where type elem = word = WordArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = WordVector.vector where type elem = word = WordArray2
  val () = T.check ("WordArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("WordArray2:MONO_ARRAY2/elem-is-word", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : word, x 7))
  val () = T.check ("WordArray2:MONO_ARRAY2/vector-is-WordVector.vector", fn () => WordVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("WordArray2:MONO_ARRAY2/array-is-WordArray2.array",
                    fn () => WordArray2.nRows (A2.array (2, 3, x 0) : WordArray2.array) = 2
                             andalso A2.nCols (WordArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("WordArray2:MONO_ARRAY2/region-is-WordArray2.region",
                    fn () => let val a = WordArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : WordArray2.region) = 3 end)
  val () = T.check ("WordArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso WordArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("WordArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("WordArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
