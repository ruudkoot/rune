(* The monomorphic vectors and arrays of Int8.int, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Int8.int

   Status: optional *)
structure Int8Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Int8.int)
(* Implements: MONO_VECTOR_SLICE where type vector = Int8Vector.vector where
   type elem = Int8.int

   Status: optional *)
structure Int8VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Int8Vector)
(* Implements: MONO_ARRAY where type vector = Int8Vector.vector where type
   elem = Int8.int

   Status: optional *)
structure Int8Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Int8Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Int8Vector.vector where
   type vector_slice = Int8VectorSlice.slice where type array =
   Int8Array.array where type elem = Int8.int

   Status: optional *)
structure Int8ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Int8Vector structure A = Int8Array structure VS = Int8VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Int8Vector.vector where type
   elem = Int8.int

   Status: optional *)
structure Int8Array2 = RuneMonoArray2Fn (structure V = Int8Vector)
