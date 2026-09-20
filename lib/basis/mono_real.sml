(* The monomorphic vectors and arrays of real, their slices and the
   two-dimensional arrays (optional in the specification). The elements do not
   admit equality, which MONO_VECTOR and MONO_ARRAY do not ask of them.
   LargeRealVector, Real64Vector and the rest of those families are these
   (mono_largereal.sml, mono_real64.sml). *)
structure RealVector : MONO_VECTOR = RuneMonoVectorFn (type elem = real)
structure RealVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = RealVector)
structure RealArray : MONO_ARRAY = RuneMonoArrayFn (structure V = RealVector)
structure RealArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = RealVector structure A = RealArray structure VS = RealVectorSlice)
structure RealArray2 = RuneMonoArray2Fn (structure V = RealVector)
