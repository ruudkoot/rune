(* IntVector: immutable vectors of integers of the default `int`.

   The monomorphic vectors and arrays of int, their slices and the
   two-dimensional arrays (optional in the specification). They are not those
   of `Int64`: `Int64.int` is a type of its own, and so are the structures of
   its family (mono_int64.sml).

   Implements: MONO_VECTOR where type elem = int

   Status: optional *)
structure IntVector :> MONO_VECTOR where type elem = int = RuneMonoVectorFn (type elem = int)
(* IntVectorSlice: stretches of `IntVector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = IntVector.vector where
   type elem = int

   Status: optional *)
structure IntVectorSlice :> MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int = RuneMonoVectorSliceFn (structure V = IntVector)
(* IntArray: mutable arrays of integers of the default `int`, a type of their
   own with identity equality, whose vectors are those of `IntVector`.

   Implements: MONO_ARRAY where type vector = IntVector.vector where type elem
   = int

   Status: optional *)
structure IntArray :> MONO_ARRAY where type vector = IntVector.vector where type elem = int = RuneMonoArrayFn (structure V = IntVector)
(* IntArraySlice: stretches of `IntArray` arrays, without a copy: an update
   through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = IntVector.vector where
   type vector_slice = IntVectorSlice.slice where type array = IntArray.array
   where type elem = int

   Status: optional *)
structure IntArraySlice :> MONO_ARRAY_SLICE where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int = RuneMonoArraySliceFn (structure V = IntVector structure A = IntArray structure VS = IntVectorSlice)
(* IntArray2: two-dimensional arrays of integers of the default `int`, whose
   rows and columns are `IntVector` vectors.

   Implements: MONO_ARRAY2 where type vector = IntVector.vector where type
   elem = int

   Status: optional *)
structure IntArray2 :> MONO_ARRAY2 where type vector = IntVector.vector where type elem = int = RuneMonoArray2Fn (structure V = IntVector)
