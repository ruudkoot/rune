(* RealVector: immutable vectors of reals.

   The monomorphic vectors and arrays of real, their slices and the
   two-dimensional arrays (optional in the specification). The elements do not
   admit equality, which MONO_VECTOR and MONO_ARRAY do not ask of them, and so
   neither does a vector. LargeRealVector, Real64Vector and the rest of those
   families are these (mono_largereal.sml, mono_real64.sml).

   Implements: MONO_VECTOR where type elem = real

   Status: optional *)
structure RealVector :> MONO_VECTOR where type elem = real = RuneMonoVectorFn (type elem = real)
(* RealVectorSlice: stretches of `RealVector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = RealVector.vector where
   type elem = real

   Status: optional *)
structure RealVectorSlice :> MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real = RuneMonoVectorSliceFn (structure V = RealVector)
(* RealArray: mutable arrays of reals, a type of their own with identity
   equality, whose vectors are those of `RealVector`.

   Implements: MONO_ARRAY where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray :> MONO_ARRAY where type vector = RealVector.vector where type elem = real = RuneMonoArrayFn (structure V = RealVector)
(* RealArraySlice: stretches of `RealArray` arrays, without a copy: an update
   through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = RealVector.vector where
   type vector_slice = RealVectorSlice.slice where type array =
   RealArray.array where type elem = real

   Status: optional *)
structure RealArraySlice :> MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real = RuneMonoArraySliceFn (structure V = RealVector structure A = RealArray structure VS = RealVectorSlice)
(* RealArray2: two-dimensional arrays of reals, whose rows and columns are
   `RealVector` vectors.

   Implements: MONO_ARRAY2 where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray2 :> MONO_ARRAY2 where type vector = RealVector.vector where type elem = real = RuneMonoArray2Fn (structure V = RealVector)
