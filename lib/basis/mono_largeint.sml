(* The monomorphic vectors and arrays of LargeInt.int (IntInf.int), their
   slices and the two-dimensional arrays (optional in the specification).

   Implements: MONO_VECTOR where type elem = LargeInt.int

   Status: optional *)
structure LargeIntVector :> MONO_VECTOR where type elem = LargeInt.int = RuneMonoVectorFn (type elem = LargeInt.int)
(* Implements: MONO_VECTOR_SLICE where type vector = LargeIntVector.vector
   where type elem = LargeInt.int

   Status: optional *)
structure LargeIntVectorSlice :> MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoVectorSliceFn (structure V = LargeIntVector)
(* Implements: MONO_ARRAY where type vector = LargeIntVector.vector where type
   elem = LargeInt.int

   Status: optional *)
structure LargeIntArray :> MONO_ARRAY where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoArrayFn (structure V = LargeIntVector)
(* Implements: MONO_ARRAY_SLICE where type vector = LargeIntVector.vector
   where type vector_slice = LargeIntVectorSlice.slice where type array =
   LargeIntArray.array where type elem = LargeInt.int

   Status: optional *)
structure LargeIntArraySlice :> MONO_ARRAY_SLICE where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int = RuneMonoArraySliceFn (structure V = LargeIntVector structure A = LargeIntArray structure VS = LargeIntVectorSlice)
(* Implements: MONO_ARRAY2 where type vector = LargeIntVector.vector where
   type elem = LargeInt.int

   Status: optional *)
structure LargeIntArray2 :> MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoArray2Fn (structure V = LargeIntVector)
