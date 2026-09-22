(* The monomorphic vectors and arrays of Word16.word, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Word16.word

   Status: optional *)
structure Word16Vector :> MONO_VECTOR where type elem = Word16.word = RuneMonoVectorFn (type elem = Word16.word)
(* Implements: MONO_VECTOR_SLICE where type vector = Word16Vector.vector where
   type elem = Word16.word

   Status: optional *)
structure Word16VectorSlice :> MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoVectorSliceFn (structure V = Word16Vector)
(* Implements: MONO_ARRAY where type vector = Word16Vector.vector where type
   elem = Word16.word

   Status: optional *)
structure Word16Array :> MONO_ARRAY where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoArrayFn (structure V = Word16Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Word16Vector.vector where
   type vector_slice = Word16VectorSlice.slice where type array =
   Word16Array.array where type elem = Word16.word

   Status: optional *)
structure Word16ArraySlice :> MONO_ARRAY_SLICE where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word = RuneMonoArraySliceFn (structure V = Word16Vector structure A = Word16Array structure VS = Word16VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Word16Vector.vector where type
   elem = Word16.word

   Status: optional *)
structure Word16Array2 :> MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoArray2Fn (structure V = Word16Vector)
