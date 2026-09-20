(* Real64 is Real, so its vectors, arrays, slices and two-dimensional arrays
   (optional in the specification) are those of Real.

   Implements: MONO_VECTOR where type elem = Real64.real

   Status: optional *)
structure Real64Vector = RealVector
(* Implements: MONO_VECTOR_SLICE where type vector = Real64Vector.vector where
   type elem = Real64.real

   Status: optional *)
structure Real64VectorSlice = RealVectorSlice
(* Implements: MONO_ARRAY where type vector = Real64Vector.vector where type
   elem = Real64.real

   Status: optional *)
structure Real64Array = RealArray
(* Implements: MONO_ARRAY_SLICE where type vector = Real64Vector.vector where
   type vector_slice = Real64VectorSlice.slice where type array =
   Real64Array.array where type elem = Real64.real

   Status: optional *)
structure Real64ArraySlice = RealArraySlice
(* Implements: MONO_ARRAY2 where type vector = Real64Vector.vector where type
   elem = Real64.real

   Status: optional *)
structure Real64Array2 = RealArray2
