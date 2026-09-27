(* LargeIntVector: immutable vectors of integers of any size.

   The vectors, arrays, slices and two-dimensional arrays of LargeInt.int, which
   is IntInf.int (optional in the specification). An element is an integer
   without bounds, so these hold what no vector of a fixed-width integer can.

   Implements: MONO_VECTOR where type elem = LargeInt.int

   Status: optional *)
structure LargeIntVector :> MONO_VECTOR where type elem = LargeInt.int = RuneMonoVectorFn (type elem = LargeInt.int)
(* LargeIntVectorSlice: stretches of `LargeIntVector` vectors, without a
   copy.

   Implements: MONO_VECTOR_SLICE where type vector = LargeIntVector.vector
   where type elem = LargeInt.int

   Status: optional *)
structure LargeIntVectorSlice :> MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoVectorSliceFn (structure V = LargeIntVector)
(* LargeIntArray: mutable arrays of integers of any size, a type of their own
   with identity equality, whose vectors are those of `LargeIntVector`.

   Implements: MONO_ARRAY where type vector = LargeIntVector.vector where type
   elem = LargeInt.int

   Status: optional *)
structure LargeIntArray :> MONO_ARRAY where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoArrayFn (structure V = LargeIntVector)
(* LargeIntArraySlice: stretches of `LargeIntArray` arrays, without a copy: an
   update through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = LargeIntVector.vector
   where type vector_slice = LargeIntVectorSlice.slice where type array =
   LargeIntArray.array where type elem = LargeInt.int

   Status: optional *)
structure LargeIntArraySlice :> MONO_ARRAY_SLICE where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int = RuneMonoArraySliceFn (structure V = LargeIntVector structure A = LargeIntArray structure VS = LargeIntVectorSlice)
(* LargeIntArray2: two-dimensional arrays of integers of any size, whose rows
   and columns are `LargeIntVector` vectors.

   Implements: MONO_ARRAY2 where type vector = LargeIntVector.vector where
   type elem = LargeInt.int

   Status: optional *)
structure LargeIntArray2 :> MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int = RuneMonoArray2Fn (structure V = LargeIntVector)
