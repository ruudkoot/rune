(* LargeWord is Word, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Word.

   Implements: MONO_VECTOR where type elem = LargeWord.word

   Status: optional *)
structure LargeWordVector = WordVector
(* Implements: MONO_VECTOR_SLICE where type vector = LargeWordVector.vector
   where type elem = LargeWord.word

   Status: optional *)
structure LargeWordVectorSlice = WordVectorSlice
(* Implements: MONO_ARRAY where type vector = LargeWordVector.vector where
   type elem = LargeWord.word

   Status: optional *)
structure LargeWordArray = WordArray
(* Implements: MONO_ARRAY_SLICE where type vector = LargeWordVector.vector
   where type vector_slice = LargeWordVectorSlice.slice where type array =
   LargeWordArray.array where type elem = LargeWord.word

   Status: optional *)
structure LargeWordArraySlice = WordArraySlice
(* Implements: MONO_ARRAY2 where type vector = LargeWordVector.vector where
   type elem = LargeWord.word

   Status: optional *)
structure LargeWordArray2 = WordArray2
