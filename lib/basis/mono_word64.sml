(* The vectors, arrays, slices and two-dimensional arrays of Word64 (optional
   in the specification). Word64.word is a type of its own, so these are their own
   structures and not those of Word.

   Implements: MONO_VECTOR where type elem = Word64.word

   Status: optional *)
structure Word64Vector :> MONO_VECTOR where type elem = Word64.word = RuneMonoVectorFn (type elem = Word64.word)
(* Implements: MONO_VECTOR_SLICE where type vector = Word64Vector.vector where
   type elem = Word64.word

   Status: optional *)
structure Word64VectorSlice :> MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoVectorSliceFn (structure V = Word64Vector)
(* Implements: MONO_ARRAY where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array :> MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoArrayFn (structure V = Word64Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Word64Vector.vector where
   type vector_slice = Word64VectorSlice.slice where type array =
   Word64Array.array where type elem = Word64.word

   Status: optional *)
structure Word64ArraySlice :> MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word =
  RuneMonoArraySliceFn (structure V = Word64Vector structure A = Word64Array structure VS = Word64VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array2 :> MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoArray2Fn (structure V = Word64Vector)
