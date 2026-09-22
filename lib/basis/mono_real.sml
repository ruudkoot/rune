(* The monomorphic vectors and arrays of real, their slices and the
   two-dimensional arrays (optional in the specification). The elements do not
   admit equality, which MONO_VECTOR and MONO_ARRAY do not ask of them.
   LargeRealVector, Real64Vector and the rest of those families are these
   (mono_largereal.sml, mono_real64.sml).

   Implements: MONO_VECTOR where type elem = real

   Status: optional *)
structure RealVector :> MONO_VECTOR where type elem = real = RuneMonoVectorFn (type elem = real)
(* Implements: MONO_VECTOR_SLICE where type vector = RealVector.vector where
   type elem = real

   Status: optional *)
structure RealVectorSlice :> MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real = RuneMonoVectorSliceFn (structure V = RealVector)
(* Implements: MONO_ARRAY where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray :> MONO_ARRAY where type vector = RealVector.vector where type elem = real = RuneMonoArrayFn (structure V = RealVector)
(* Implements: MONO_ARRAY_SLICE where type vector = RealVector.vector where
   type vector_slice = RealVectorSlice.slice where type array =
   RealArray.array where type elem = real

   Status: optional *)
structure RealArraySlice :> MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real = RuneMonoArraySliceFn (structure V = RealVector structure A = RealArray structure VS = RealVectorSlice)
(* Implements: MONO_ARRAY2 where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray2 :> MONO_ARRAY2 where type vector = RealVector.vector where type elem = real = RuneMonoArray2Fn (structure V = RealVector)
