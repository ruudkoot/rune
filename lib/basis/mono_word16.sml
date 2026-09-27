(* Word16Vector: immutable vectors of 16-bit words.

   The monomorphic vectors and arrays of Word16.word, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Word16.word

   Status: optional *)
structure Word16Vector :> MONO_VECTOR where type elem = Word16.word = RuneMonoVectorFn (type elem = Word16.word)
(* Word16VectorSlice: stretches of `Word16Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Word16Vector.vector where
   type elem = Word16.word

   Status: optional *)
structure Word16VectorSlice :> MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoVectorSliceFn (structure V = Word16Vector)
(* Word16Array: mutable arrays of 16-bit words, a type of their own with
   identity equality, whose vectors are those of `Word16Vector`.

   Implements: MONO_ARRAY where type vector = Word16Vector.vector where type
   elem = Word16.word

   Status: optional *)
structure Word16Array :> MONO_ARRAY where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoArrayFn (structure V = Word16Vector)
(* Word16ArraySlice: stretches of `Word16Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Word16Vector.vector where
   type vector_slice = Word16VectorSlice.slice where type array =
   Word16Array.array where type elem = Word16.word

   Status: optional *)
structure Word16ArraySlice :> MONO_ARRAY_SLICE where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word = RuneMonoArraySliceFn (structure V = Word16Vector structure A = Word16Array structure VS = Word16VectorSlice)
(* Word16Array2: two-dimensional arrays of 16-bit words, whose rows and
   columns are `Word16Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Word16Vector.vector where type
   elem = Word16.word

   Status: optional *)
structure Word16Array2 :> MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word = RuneMonoArray2Fn (structure V = Word16Vector)
