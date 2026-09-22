(* The monomorphic vectors and arrays of int, their slices and the
   two-dimensional arrays (optional in the specification). Int64Vector and the
   rest of that family are these (mono_int64.sml).

   Implements: MONO_VECTOR where type elem = int

   Status: optional *)
structure IntVector :> MONO_VECTOR where type elem = int = RuneMonoVectorFn (type elem = int)
(* Implements: MONO_VECTOR_SLICE where type vector = IntVector.vector where
   type elem = int

   Status: optional *)
structure IntVectorSlice :> MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int = RuneMonoVectorSliceFn (structure V = IntVector)
(* Implements: MONO_ARRAY where type vector = IntVector.vector where type elem
   = int

   Status: optional *)
structure IntArray :> MONO_ARRAY where type vector = IntVector.vector where type elem = int = RuneMonoArrayFn (structure V = IntVector)
(* Implements: MONO_ARRAY_SLICE where type vector = IntVector.vector where
   type vector_slice = IntVectorSlice.slice where type array = IntArray.array
   where type elem = int

   Status: optional *)
structure IntArraySlice :> MONO_ARRAY_SLICE where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int = RuneMonoArraySliceFn (structure V = IntVector structure A = IntArray structure VS = IntVectorSlice)
(* Implements: MONO_ARRAY2 where type vector = IntVector.vector where type
   elem = int

   Status: optional *)
structure IntArray2 :> MONO_ARRAY2 where type vector = IntVector.vector where type elem = int = RuneMonoArray2Fn (structure V = IntVector)
