(* LargeReal is Real, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Real.

   Implements: MONO_VECTOR where type elem = LargeReal.real

   Status: optional *)
structure LargeRealVector = RealVector
(* Implements: MONO_VECTOR_SLICE where type vector = LargeRealVector.vector
   where type elem = LargeReal.real

   Status: optional *)
structure LargeRealVectorSlice = RealVectorSlice
(* Implements: MONO_ARRAY where type vector = LargeRealVector.vector where
   type elem = LargeReal.real

   Status: optional *)
structure LargeRealArray = RealArray
(* Implements: MONO_ARRAY_SLICE where type vector = LargeRealVector.vector
   where type vector_slice = LargeRealVectorSlice.slice where type array =
   LargeRealArray.array where type elem = LargeReal.real

   Status: optional *)
structure LargeRealArraySlice = RealArraySlice
(* Implements: MONO_ARRAY2 where type vector = LargeRealVector.vector where
   type elem = LargeReal.real

   Status: optional *)
structure LargeRealArray2 = RealArray2
