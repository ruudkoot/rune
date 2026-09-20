(* requires: LargeWordVector LargeWordArray LargeWord *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/MONO_ARRAY2.sml *)
(* LargeWordVector, LargeWordArray, LargeWordVectorSlice, LargeWordArraySlice and
   LargeWordArray2 match their signatures, with the constraints of the
   specification:
     structure LargeWordVector :> MONO_VECTOR where type elem = LargeWord.word
     structure LargeWordArray :> MONO_ARRAY where type vector = LargeWordVector.vector
       where type elem = LargeWord.word
     structure LargeWordVectorSlice :> MONO_VECTOR_SLICE
       where type vector = LargeWordVector.vector where type elem = LargeWord.word
     structure LargeWordArraySlice :> MONO_ARRAY_SLICE
       where type vector = LargeWordVector.vector
       where type vector_slice = LargeWordVectorSlice.slice
       where type array = LargeWordArray.array where type elem = LargeWord.word
     structure LargeWordArray2 :> MONO_ARRAY2 where type vector = LargeWordVector.vector
       where type elem = LargeWord.word
   and each can be implemented opaquely.
   LargeWord is Word in Rune, and LargeWordVector is WordVector; on a host they are
   structures of their own, so they are tested as such. *)
structure TestMonoLargeWordSig =
struct
  fun x n = LargeWord.fromInt n
  val eq = op =

  structure V : SPEC_MONO_VECTOR = LargeWordVector
  structure VE : SPEC_MONO_VECTOR where type elem = LargeWord.word = LargeWordVector
  structure VO :> SPEC_MONO_VECTOR where type elem = LargeWord.word = LargeWordVector
  val () = T.check ("LargeWordVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("LargeWordVector:MONO_VECTOR/elem-is-LargeWord.word", fn () => eq (VE.sub (VE.fromList [x 7], 0) : LargeWord.word, x 7))
  val () = T.check ("LargeWordVector:MONO_VECTOR/vector-is-LargeWordVector.vector",
                    fn () => LargeWordVector.length (V.fromList [] : LargeWordVector.vector) = 0 andalso V.length (LargeWordVector.fromList [] : V.vector) = 0)
  val () = T.check ("LargeWordVector:MONO_VECTOR/opaque-vector", fn () => eq (VO.sub (VO.tabulate (3, x), 2), x 2))

  structure A : SPEC_MONO_ARRAY = LargeWordArray
  structure AE : SPEC_MONO_ARRAY where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray
  structure AO :> SPEC_MONO_ARRAY where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray
  val () = T.check ("LargeWordArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("LargeWordArray:MONO_ARRAY/elem-is-LargeWord.word", fn () => eq (AE.sub (AE.array (1, x 7), 0) : LargeWord.word, x 7))
  val () = T.check ("LargeWordArray:MONO_ARRAY/vector-is-LargeWordVector.vector", fn () => LargeWordVector.length (AE.vector (AE.array (3, x 0))) = 3)
  val () = T.check ("LargeWordArray:MONO_ARRAY/array-is-LargeWordArray.array",
                    fn () => LargeWordArray.length (A.fromList [] : LargeWordArray.array) = 0 andalso A.length (LargeWordArray.fromList [] : A.array) = 0)
  val () = T.check ("LargeWordArray:MONO_ARRAY/eqtype", fn () => let val a = A.fromList [] in a = a end)
  val () = T.check ("LargeWordArray:MONO_ARRAY/opaque-array", fn () => let val a = AO.tabulate (3, x) in eq (AO.sub (a, 2), x 2) andalso a = a end)

  (*<< slices *)
  structure VS : SPEC_MONO_VECTOR_SLICE = LargeWordVectorSlice
  structure VSE : SPEC_MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordVectorSlice
  structure VSO :> SPEC_MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordVectorSlice
  val () = T.check ("LargeWordVectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("LargeWordVectorSlice:MONO_VECTOR_SLICE/vector-is-LargeWordVector.vector",
                    fn () => LargeWordVector.length (VSE.vector (VSE.full (LargeWordVector.tabulate (3, x)))) = 3)
  val () = T.check ("LargeWordVectorSlice:MONO_VECTOR_SLICE/elem-is-LargeWord.word",
                    fn () => eq (VSE.sub (VSE.full (LargeWordVector.tabulate (3, x)), 2) : LargeWord.word, x 2))
  val () = T.check ("LargeWordVectorSlice:MONO_VECTOR_SLICE/slice-is-LargeWordVectorSlice.slice",
                    fn () => LargeWordVectorSlice.length (VS.full (LargeWordVector.fromList []) : LargeWordVectorSlice.slice) = 0
                             andalso VS.length (LargeWordVectorSlice.full (LargeWordVector.fromList []) : VS.slice) = 0)
  val () = T.check ("LargeWordVectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => eq (VSO.sub (VSO.slice (LargeWordVector.tabulate (5, x), 2, NONE), 1), x 3))

  structure AS : SPEC_MONO_ARRAY_SLICE = LargeWordArraySlice
  structure ASE : SPEC_MONO_ARRAY_SLICE where type vector = LargeWordVector.vector where type vector_slice = LargeWordVectorSlice.slice where type array = LargeWordArray.array where type elem = LargeWord.word = LargeWordArraySlice
  structure ASO :> SPEC_MONO_ARRAY_SLICE where type vector = LargeWordVector.vector where type vector_slice = LargeWordVectorSlice.slice where type array = LargeWordArray.array where type elem = LargeWord.word = LargeWordArraySlice
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/array-is-LargeWordArray.array",
                    fn () => LargeWordArray.length (#1 (ASE.base (ASE.full (LargeWordArray.array (3, x 0))))) = 3)
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/vector-is-LargeWordVector.vector",
                    fn () => LargeWordVector.length (ASE.vector (ASE.full (LargeWordArray.array (3, x 0)))) = 3)
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/vector_slice-is-LargeWordVectorSlice.slice",
                    fn () => let val a = LargeWordArray.array (3, x 0)
                             in ASE.copyVec {src = LargeWordVectorSlice.full (LargeWordVector.tabulate (2, fn _ => x 9)), dst = a, di = 1};
                                eq (LargeWordArray.sub (a, 2), x 9) end)
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/elem-is-LargeWord.word", fn () => eq (ASE.sub (ASE.full (LargeWordArray.array (1, x 7)), 0) : LargeWord.word, x 7))
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/slice-is-LargeWordArraySlice.slice",
                    fn () => LargeWordArraySlice.length (AS.full (LargeWordArray.fromList []) : LargeWordArraySlice.slice) = 0
                             andalso AS.length (LargeWordArraySlice.full (LargeWordArray.fromList []) : AS.slice) = 0)
  val () = T.check ("LargeWordArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => eq (ASO.sub (ASO.slice (LargeWordArray.tabulate (5, x), 2, NONE), 1), x 3))
  (*>> slices *)

  (*<< array2 *)
  structure A2 : SPEC_MONO_ARRAY2 = LargeWordArray2
  structure A2E : SPEC_MONO_ARRAY2 where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray2
  structure A2O :> SPEC_MONO_ARRAY2 where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray2
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/elem-is-LargeWord.word", fn () => eq (A2E.sub (A2E.array (1, 1, x 7), 0, 0) : LargeWord.word, x 7))
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/vector-is-LargeWordVector.vector", fn () => LargeWordVector.length (A2E.row (A2E.array (2, 3, x 0), 1)) = 3)
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/array-is-LargeWordArray2.array",
                    fn () => LargeWordArray2.nRows (A2.array (2, 3, x 0) : LargeWordArray2.array) = 2
                             andalso A2.nCols (LargeWordArray2.array (2, 3, x 0) : A2.array) = 3)
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/region-is-LargeWordArray2.region",
                    fn () => let val a = LargeWordArray2.array (2, 3, x 0)
                             in A2.foldi A2.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : LargeWordArray2.region) = 3 end)
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (A2.RowMajor : Array2.traversal) = Array2.RowMajor andalso LargeWordArray2.ColMajor = (Array2.ColMajor : A2.traversal))
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/eqtype", fn () => let val a = A2.array (1, 1, x 0) in a = a end)
  val () = T.check ("LargeWordArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = A2O.tabulate A2O.ColMajor (2, 2, fn (i, j) => x (2 * i + j)) in eq (A2O.sub (a, 1, 0), x 2) andalso a = a end)
  (*>> array2 *)
end
