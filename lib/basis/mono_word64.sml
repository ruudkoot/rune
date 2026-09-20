(* Word64 is Word, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Word.

   Implements: MONO_VECTOR where type elem = Word64.word

   Status: optional *)
structure Word64Vector = WordVector
(* Implements: MONO_VECTOR_SLICE where type vector = Word64Vector.vector where
   type elem = Word64.word

   Status: optional *)
structure Word64VectorSlice = WordVectorSlice
(* Implements: MONO_ARRAY where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array = WordArray
(* Implements: MONO_ARRAY_SLICE where type vector = Word64Vector.vector where
   type vector_slice = Word64VectorSlice.slice where type array =
   Word64Array.array where type elem = Word64.word

   Status: optional *)
structure Word64ArraySlice = WordArraySlice
(* Implements: MONO_ARRAY2 where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array2 = WordArray2
