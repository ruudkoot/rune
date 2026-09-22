(* The monomorphic vectors and arrays of Real32.real, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Real32.real

   Status: optional *)
structure Real32Vector :> MONO_VECTOR where type elem = Real32.real = RuneMonoVectorFn (type elem = Real32.real)
(* Implements: MONO_VECTOR_SLICE where type vector = Real32Vector.vector where
   type elem = Real32.real

   Status: optional *)
structure Real32VectorSlice :> MONO_VECTOR_SLICE where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoVectorSliceFn (structure V = Real32Vector)
(* Implements: MONO_ARRAY where type vector = Real32Vector.vector where type
   elem = Real32.real

   Status: optional *)
structure Real32Array :> MONO_ARRAY where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoArrayFn (structure V = Real32Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Real32Vector.vector where
   type vector_slice = Real32VectorSlice.slice where type array =
   Real32Array.array where type elem = Real32.real

   Status: optional *)
structure Real32ArraySlice :> MONO_ARRAY_SLICE where type vector = Real32Vector.vector where type vector_slice = Real32VectorSlice.slice where type array = Real32Array.array where type elem = Real32.real = RuneMonoArraySliceFn (structure V = Real32Vector structure A = Real32Array structure VS = Real32VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Real32Vector.vector where type
   elem = Real32.real

   Status: optional *)
structure Real32Array2 :> MONO_ARRAY2 where type vector = Real32Vector.vector where type elem = Real32.real = RuneMonoArray2Fn (structure V = Real32Vector)
