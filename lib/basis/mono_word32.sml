(* The monomorphic vectors and arrays of Word32.word, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Word32.word

   Status: optional *)
structure Word32Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Word32.word)
(* Implements: MONO_VECTOR_SLICE where type vector = Word32Vector.vector where
   type elem = Word32.word

   Status: optional *)
structure Word32VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Word32Vector)
(* Implements: MONO_ARRAY where type vector = Word32Vector.vector where type
   elem = Word32.word

   Status: optional *)
structure Word32Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Word32Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Word32Vector.vector where
   type vector_slice = Word32VectorSlice.slice where type array =
   Word32Array.array where type elem = Word32.word

   Status: optional *)
structure Word32ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Word32Vector structure A = Word32Array structure VS = Word32VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Word32Vector.vector where type
   elem = Word32.word

   Status: optional *)
structure Word32Array2 = RuneMonoArray2Fn (structure V = Word32Vector)
