(* Int8Vector: immutable vectors of 8-bit integers.

   The monomorphic vectors and arrays of Int8.int, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Int8.int

   Status: optional *)
structure Int8Vector :> MONO_VECTOR where type elem = Int8.int = RuneMonoVectorFn (type elem = Int8.int)
(* Int8VectorSlice: stretches of `Int8Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Int8Vector.vector where
   type elem = Int8.int

   Status: optional *)
structure Int8VectorSlice :> MONO_VECTOR_SLICE where type vector = Int8Vector.vector where type elem = Int8.int = RuneMonoVectorSliceFn (structure V = Int8Vector)
(* Int8Array: mutable arrays of 8-bit integers, a type of their own with
   identity equality, whose vectors are those of `Int8Vector`.

   Implements: MONO_ARRAY where type vector = Int8Vector.vector where type
   elem = Int8.int

   Status: optional *)
structure Int8Array :> MONO_ARRAY where type vector = Int8Vector.vector where type elem = Int8.int = RuneMonoArrayFn (structure V = Int8Vector)
(* Int8ArraySlice: stretches of `Int8Array` arrays, without a copy: an update
   through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Int8Vector.vector where
   type vector_slice = Int8VectorSlice.slice where type array =
   Int8Array.array where type elem = Int8.int

   Status: optional *)
structure Int8ArraySlice :> MONO_ARRAY_SLICE where type vector = Int8Vector.vector where type vector_slice = Int8VectorSlice.slice where type array = Int8Array.array where type elem = Int8.int = RuneMonoArraySliceFn (structure V = Int8Vector structure A = Int8Array structure VS = Int8VectorSlice)
(* Int8Array2: two-dimensional arrays of 8-bit integers, whose rows and
   columns are `Int8Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Int8Vector.vector where type
   elem = Int8.int

   Status: optional *)
structure Int8Array2 :> MONO_ARRAY2 where type vector = Int8Vector.vector where type elem = Int8.int = RuneMonoArray2Fn (structure V = Int8Vector)
