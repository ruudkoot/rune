(* The monomorphic vectors and arrays of word, their slices and the
   two-dimensional arrays (optional in the specification). LargeWordVector,
   Word64Vector and the rest of those families are these (mono_largeword.sml,
   mono_word64.sml).

   Implements: MONO_VECTOR where type elem = word

   Status: optional *)
structure WordVector : MONO_VECTOR = RuneMonoVectorFn (type elem = word)
(* Implements: MONO_VECTOR_SLICE where type vector = WordVector.vector where
   type elem = word

   Status: optional *)
structure WordVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = WordVector)
(* Implements: MONO_ARRAY where type vector = WordVector.vector where type
   elem = word

   Status: optional *)
structure WordArray : MONO_ARRAY = RuneMonoArrayFn (structure V = WordVector)
(* Implements: MONO_ARRAY_SLICE where type vector = WordVector.vector where
   type vector_slice = WordVectorSlice.slice where type array =
   WordArray.array where type elem = word

   Status: optional *)
structure WordArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = WordVector structure A = WordArray structure VS = WordVectorSlice)
(* Implements: MONO_ARRAY2 where type vector = WordVector.vector where type
   elem = word

   Status: optional *)
structure WordArray2 = RuneMonoArray2Fn (structure V = WordVector)
