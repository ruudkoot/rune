(* Int32Vector: immutable vectors of 32-bit integers.

   The monomorphic vectors and arrays of Int32.int, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Int32.int

   Status: optional *)
structure Int32Vector :> MONO_VECTOR where type elem = Int32.int = RuneMonoVectorFn (type elem = Int32.int)
(* Int32VectorSlice: stretches of `Int32Vector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = Int32Vector.vector where
   type elem = Int32.int

   Status: optional *)
structure Int32VectorSlice :> MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int = RuneMonoVectorSliceFn (structure V = Int32Vector)
(* Int32Array: mutable arrays of 32-bit integers, a type of their own with
   identity equality, whose vectors are those of `Int32Vector`.

   Implements: MONO_ARRAY where type vector = Int32Vector.vector where type
   elem = Int32.int

   Status: optional *)
structure Int32Array :> MONO_ARRAY where type vector = Int32Vector.vector where type elem = Int32.int = RuneMonoArrayFn (structure V = Int32Vector)
(* Int32ArraySlice: stretches of `Int32Array` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = Int32Vector.vector where
   type vector_slice = Int32VectorSlice.slice where type array =
   Int32Array.array where type elem = Int32.int

   Status: optional *)
structure Int32ArraySlice :> MONO_ARRAY_SLICE where type vector = Int32Vector.vector where type vector_slice = Int32VectorSlice.slice where type array = Int32Array.array where type elem = Int32.int = RuneMonoArraySliceFn (structure V = Int32Vector structure A = Int32Array structure VS = Int32VectorSlice)
(* Int32Array2: two-dimensional arrays of 32-bit integers, whose rows and
   columns are `Int32Vector` vectors.

   Implements: MONO_ARRAY2 where type vector = Int32Vector.vector where type
   elem = Int32.int

   Status: optional *)
structure Int32Array2 :> MONO_ARRAY2 where type vector = Int32Vector.vector where type elem = Int32.int = RuneMonoArray2Fn (structure V = Int32Vector)
