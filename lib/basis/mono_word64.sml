(* Word64Vector: immutable vectors of 64-bit words.

   The vectors, arrays, slices and two-dimensional arrays of Word64 (optional
   in the specification). Word64.word is a type of its own, so these are their own
   structures and not those of Word.

   Implements: MONO_VECTOR where type elem = Word64.word

   Status: optional *)
structure Word64Vector :> MONO_VECTOR where type elem = Word64.word = RuneMonoVectorFn (type elem = Word64.word)
(* Word64VectorSlice: stretches of `Word64Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Word64Vector.vector where
   type elem = Word64.word

   Status: optional *)
structure Word64VectorSlice :> MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoVectorSliceFn (structure V = Word64Vector)
(* Word64Array: mutable arrays of 64-bit words, a type of their own with
   identity equality, whose vectors are those of `Word64Vector`.

   Implements: MONO_ARRAY where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array :> MONO_ARRAY where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoArrayFn (structure V = Word64Vector)
(* Word64ArraySlice: stretches of `Word64Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Word64Vector.vector where
   type vector_slice = Word64VectorSlice.slice where type array =
   Word64Array.array where type elem = Word64.word

   Status: optional *)
structure Word64ArraySlice :> MONO_ARRAY_SLICE where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word =
  RuneMonoArraySliceFn (structure V = Word64Vector structure A = Word64Array structure VS = Word64VectorSlice)
(* Word64Array2: two-dimensional arrays of 64-bit words, whose rows and
   columns are `Word64Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Word64Vector.vector where type
   elem = Word64.word

   Status: optional *)
structure Word64Array2 :> MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word = RuneMonoArray2Fn (structure V = Word64Vector)
