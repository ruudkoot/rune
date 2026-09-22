(* The monomorphic vectors and arrays of Int16.int, their slices and the
   two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = Int16.int

   Status: optional *)
structure Int16Vector :> MONO_VECTOR where type elem = Int16.int = RuneMonoVectorFn (type elem = Int16.int)
(* Implements: MONO_VECTOR_SLICE where type vector = Int16Vector.vector where
   type elem = Int16.int

   Status: optional *)
structure Int16VectorSlice :> MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int = RuneMonoVectorSliceFn (structure V = Int16Vector)
(* Implements: MONO_ARRAY where type vector = Int16Vector.vector where type
   elem = Int16.int

   Status: optional *)
structure Int16Array :> MONO_ARRAY where type vector = Int16Vector.vector where type elem = Int16.int = RuneMonoArrayFn (structure V = Int16Vector)
(* Implements: MONO_ARRAY_SLICE where type vector = Int16Vector.vector where
   type vector_slice = Int16VectorSlice.slice where type array =
   Int16Array.array where type elem = Int16.int

   Status: optional *)
structure Int16ArraySlice :> MONO_ARRAY_SLICE where type vector = Int16Vector.vector where type vector_slice = Int16VectorSlice.slice where type array = Int16Array.array where type elem = Int16.int = RuneMonoArraySliceFn (structure V = Int16Vector structure A = Int16Array structure VS = Int16VectorSlice)
(* Implements: MONO_ARRAY2 where type vector = Int16Vector.vector where type
   elem = Int16.int

   Status: optional *)
structure Int16Array2 :> MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int = RuneMonoArray2Fn (structure V = Int16Vector)
