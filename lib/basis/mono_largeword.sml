(* LargeWord is Word64, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Word64.

   Implements: MONO_VECTOR where type elem = LargeWord.word

   Status: optional *)
structure LargeWordVector = Word64Vector
(* Implements: MONO_VECTOR_SLICE where type vector = LargeWordVector.vector
   where type elem = LargeWord.word

   Status: optional *)
structure LargeWordVectorSlice = Word64VectorSlice
(* Implements: MONO_ARRAY where type vector = LargeWordVector.vector where
   type elem = LargeWord.word

   Status: optional *)
structure LargeWordArray = Word64Array
(* Implements: MONO_ARRAY_SLICE where type vector = LargeWordVector.vector
   where type vector_slice = LargeWordVectorSlice.slice where type array =
   LargeWordArray.array where type elem = LargeWord.word

   Status: optional *)
structure LargeWordArraySlice = Word64ArraySlice
(* Implements: MONO_ARRAY2 where type vector = LargeWordVector.vector where
   type elem = LargeWord.word

   Status: optional *)
structure LargeWordArray2 = Word64Array2
