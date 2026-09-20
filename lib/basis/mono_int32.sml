(* The monomorphic vectors and arrays of Int32.int, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Int32.int

   Status: optional *)
structure Int32Vector : MONO_VECTOR = RuneMonoVectorFn (type elem = Int32.int)
(* Implements: MONO_VECTOR_SLICE where type vector = Int32Vector.vector where
   type elem = Int32.int

   Status: optional *)
structure Int32VectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = Int32Vector)
(* Implements: MONO_ARRAY where type vector = Int32Vector.vector where type
   elem = Int32.int

   Status: optional *)
structure Int32Array : MONO_ARRAY = RuneMonoArrayFn (structure V = Int32Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Int32Vector.vector where
   type vector_slice = Int32VectorSlice.slice where type array =
   Int32Array.array where type elem = Int32.int

   Status: optional *)
structure Int32ArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = Int32Vector structure A = Int32Array structure VS = Int32VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Int32Vector.vector where type
   elem = Int32.int

   Status: optional *)
structure Int32Array2 = RuneMonoArray2Fn (structure V = Int32Vector)
