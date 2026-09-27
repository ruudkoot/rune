(* Real32Vector: immutable vectors of binary32 reals.

   The monomorphic vectors and arrays of Real32.real, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Real32.real

   Status: optional *)
structure Real32Vector :> MONO_VECTOR where type elem = Real32.real = RuneMonoVectorFn (type elem = Real32.real)
(* Real32VectorSlice: stretches of `Real32Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Real32Vector.vector where
   type elem = Real32.real

   Status: optional *)
structure Real32VectorSlice :> MONO_VECTOR_SLICE where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoVectorSliceFn (structure V = Real32Vector)
(* Real32Array: mutable arrays of binary32 reals, a type of their own with
   identity equality, whose vectors are those of `Real32Vector`.

   Implements: MONO_ARRAY where type vector = Real32Vector.vector where type
   elem = Real32.real

   Status: optional *)
structure Real32Array :> MONO_ARRAY where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoArrayFn (structure V = Real32Vector)
(* Real32ArraySlice: stretches of `Real32Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Real32Vector.vector where
   type vector_slice = Real32VectorSlice.slice where type array =
   Real32Array.array where type elem = Real32.real

   Status: optional *)
structure Real32ArraySlice :> MONO_ARRAY_SLICE where type vector = Real32Vector.vector where type vector_slice = Real32VectorSlice.slice where type array = Real32Array.array where type elem = Real32.real = RuneMonoArraySliceFn (structure V = Real32Vector structure A = Real32Array structure VS = Real32VectorSlice)
(* Real32Array2: two-dimensional arrays of binary32 reals, whose rows and
   columns are `Real32Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Real32Vector.vector where type
   elem = Real32.real

   Status: optional *)
structure Real32Array2 :> MONO_ARRAY2 where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoArray2Fn (structure V = Real32Vector)
