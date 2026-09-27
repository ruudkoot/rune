(* Word32Vector: immutable vectors of 32-bit words.

   The monomorphic vectors and arrays of Word32.word, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Word32.word

   Status: optional *)
structure Word32Vector :> MONO_VECTOR where type elem = Word32.word = RuneMonoVectorFn (type elem = Word32.word)
(* Word32VectorSlice: stretches of `Word32Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Word32Vector.vector where
   type elem = Word32.word

   Status: optional *)
structure Word32VectorSlice :> MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word = RuneMonoVectorSliceFn (structure V = Word32Vector)
(* Word32Array: mutable arrays of 32-bit words, a type of their own with
   identity equality, whose vectors are those of `Word32Vector`.

   Implements: MONO_ARRAY where type vector = Word32Vector.vector where type
   elem = Word32.word

   Status: optional *)
structure Word32Array :> MONO_ARRAY where type vector = Word32Vector.vector where type elem = Word32.word = RuneMonoArrayFn (structure V = Word32Vector)
(* Word32ArraySlice: stretches of `Word32Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Word32Vector.vector where
   type vector_slice = Word32VectorSlice.slice where type array =
   Word32Array.array where type elem = Word32.word

   Status: optional *)
structure Word32ArraySlice :> MONO_ARRAY_SLICE where type vector = Word32Vector.vector where type vector_slice = Word32VectorSlice.slice where type array = Word32Array.array where type elem = Word32.word = RuneMonoArraySliceFn (structure V = Word32Vector structure A = Word32Array structure VS = Word32VectorSlice)
(* Word32Array2: two-dimensional arrays of 32-bit words, whose rows and
   columns are `Word32Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Word32Vector.vector where type
   elem = Word32.word

   Status: optional *)
structure Word32Array2 :> MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word = RuneMonoArray2Fn (structure V = Word32Vector)
