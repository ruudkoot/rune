(* The monomorphic vectors and arrays of LargeInt.int (IntInf.int), their
   slices and the two-dimensional arrays (optional in the specification). *)
structure LargeIntVector : MONO_VECTOR = RuneMonoVectorFn (type elem = LargeInt.int)
structure LargeIntVectorSlice : MONO_VECTOR_SLICE = RuneMonoVectorSliceFn (structure V = LargeIntVector)
structure LargeIntArray : MONO_ARRAY = RuneMonoArrayFn (structure V = LargeIntVector)
structure LargeIntArraySlice : MONO_ARRAY_SLICE =
  RuneMonoArraySliceFn (structure V = LargeIntVector structure A = LargeIntArray structure VS = LargeIntVectorSlice)
structure LargeIntArray2 = RuneMonoArray2Fn (structure V = LargeIntVector)
